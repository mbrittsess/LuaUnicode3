# This file is the beginning stage of a pipeline. It processes UnicodeData.txt and generates the character objects.

Import-Module .\CompileCS.psm1
Import-Module .\Normalize.psm1
Import-Module .\Progress.psm1
Import-Module .\FileUtilities.psm1
Import-Module .\CharacterObject.psm1

$LuaTrue = New-Object LuaBoolean $True

### HANGUL NAME STUFF ###
# Mostly copied from the previous version's GenerateCharacters.ps1

$HangulShortNames = @{}
    Get-Content UCD\Jamo.txt |
    Strip-Comment |
    Where-Object {
        $_.Length -gt 0
    } |
    ForEach-Object {
        $CP, $Name, $Others = $_ -split ';' | %{ $_.Trim() }
        $CP = [UInt32]::Parse( $CP, 'AllowHexSpecifier' )
        $HangulShortNames[ $CP ] = $Name
    }

# Algorithm taken from section "Hangul Syllable Name Generation" of section 13.2 of Unicode 7.0 Core Specification
[UInt32]$SBase = 0xAC00
[UInt32]$LBase = 0x1100
[UInt32]$VBase = 0x1161
[UInt32]$TBase = 0x11A7

[UInt32]$LCount = 19
[UInt32]$VCount = 21
[UInt32]$TCount = 28
[UInt32]$NCount =           $VCount * $TCount
[UInt32]$SCount = $LCount * $VCount * $TCount

Function Get-HangulSyllableName
{
    [CmdletBinding()]
    [OutputType([String])]
    
    Param
    (
        [Parameter(
            Mandatory=$True)]
        [UInt32]
        $CodePoint
    )
    
    $CP = $CodePoint
    $SIndex = $CP - $SBase
    $LPart = $HangulShortNames[ [UInt32][Math]::Floor( $LBase + ( $SIndex / $NCount ) ) ]
    $VPart = $HangulShortNames[ [UInt32][Math]::Floor( $VBase + ( ($SIndex % $NCount ) / $TCount ) ) ]
    $TPart = ""
    If ( $SIndex % $TCount -gt 0 )
    {
        $TPart = $HangulShortNames[ [UInt32][Math]::Floor( $TBase + ( $SIndex % $TCount ) ) ]
    }
    
    "HANGUL SYLLABLE " + $LPart + $VPart + $TPart | Write-Output
}

### END HANGUL NAME STUFF ###

$FullPropertyNames = "Name", "General_Category", "Canonical_Combining_Class", "Bidi_Class", "Decomposition_Type", "Decomposition_Mapping", "Numeric_Type", "Numeric_Value", "Bidi_Mirrored", "Unicode_1_Name", "ISO_Comment", "Simple_Uppercase_Mapping", "Simple_Lowercase_Mapping", "Simple_Titlecase_Mapping"
$PropertyNames = @{}; $FullPropertyNames | %{ $PropertyNames[ $_ ] = Normalize-PropertyName $_ }
    #Non-standard properties
    "Original_Name", "Numeric_Canonical_Combining_Class", "Rational_Numeric_Value" | %{ $PropertyNames[ $_ ] = [Normalize]::PropertyName( $_ ) }

$TotalAssignedCharacters = 0
$CharCountProg = New-RootProgress "Counting total characters"
$DASR = Get-StreamReader UCD\DerivedAge.txt
& {
    While ( $Line = $DASR.ReadNonCommentLine() )
    {
        $Line
    }
} | Where-Object { $_ -ne [String]::Empty -and $_[0] -ne '#' } | Where-Object {
    $Content, $Comment = $_ -split '#'
    -not ( $Comment -like '*<*>*' -and $Comment -notlike '*<control*>*' )
} | ForEach-Object {
    $CodePoints = ($_ -split ' ')[0]
    If ( $CodePoints.Contains( ".." ) )
    {
        # It's a range
        [Void]( $CodePoints -match '^([0-9A-F]+)\.\.([0-9A-F]+)$' )
        $Start = [Int32]::Parse( $Matches[1], 'AllowHexSpecifier' )
        $End = [Int32]::Parse( $Matches[2], 'AllowHexSpecifier' )
        $RangeSize = ($End - $Start) + 1
        $TotalAssignedCharacters += $RangeSize
    }
    Else
    {
        $TotalAssignedCharacters += 1
    }
    $CharCountProg.OverallStatus = "Tallying, {0} characters" -f $TotalAssignedCharacters
    $CharCountProg.Update( $DASR.PositionPercent )
}
$CharCountProg.OverallStatus = "Done, {0} characters" -f $TotalAssignedCharacters
$CharCountProg.Update( 1.0 )

$OverallProg = New-RootProgress "Generating characters"
$OverallProg.OverallStatus = "Generating characters"
$Script:NumGenCharacters = 0

#$UniDataProg = New-RootProgress "Processing UCD\UnicodeData.txt"
$UniDataProg = $OverallProg.NewChild( "Processing UCD\UnicodeData.txt" )
$UniDataProg.OverallStatus = "Generating characters"
$SR = Get-StreamReader UCD\UnicodeData.txt
While ( $Line = $SR.ReadNonCommentLine() )
{
    $CP, $Name, $GenCat, $CanCombClass, $BidiClass, $Decomp, $Num1, $Num2, $Num3, $BidiMirrored, $Uni1Name, $IsoComment, $SimpleUpperMap, $SimpleLowerMap, $SimpleTitleMap = ($Line | Strip-Comment) -split ';' | ForEach-Object { $_.Trim() }
    
    $CP = [UInt32]::Parse( $CP, 'AllowHexSpecifier' )
    
    & {
        If ( -not $Name.EndsWith( "First>" ) ) # Path for single character
        {
            If ( -not $Name.StartsWith( "<" ) )
            {
                $Label = $Name
            }
            ElseIf ( $GenCat -eq 'Cc' )
            {
                $Label = "<control-{0:X4}>" -f $CP
            }
            Else
            {
                Throw New-Object Exception "Can't happen" #TODO
            }
            $UniDataProg.CurrentOperation = "Generating U+{0:X4} {1}" -f $CP, $Label
            $UniDataProg.Update( $SR.PositionPercent )
            $CP | Write-Output
        }
        Else # Path for character range
        {
            $Line2 = $SR.ReadNonCommentLine()
            
            If ( 'Co', 'Cs' -ccontains $GenCat ) { Continue } # Skip private-use areas and surrogates
            
            $StartCP = $CP; $EndCP = [UInt32]::Parse( ($Line2 -split ';')[0], 'AllowHexSpecifier' )
            
            $Label = $Name.Substring( 1, $Name.Length - 9 ) #Trims the opening "<" and trailing ", First>"
            $UniDataProg.CurrentOperation = "Expanding range {0}" -f $Label
            $UniDataProg.Update( $SR.PositionPercent )
            
            $RangeProg = $UniDataProg.NewChild( "Processing {0} range" -f $Label )
            $RangeProg.OverallStatus = "Expanding"
            
            $RangeLen = ($EndCP - $StartCP) + 1
            
            $StartCP .. $EndCP | ForEach-Object {
                $CP = $_
                $Percent = (($CP - $StartCP)+1) / $RangeLen
                $RangeProg.CurrentOperation = "Generating U+{0:X4}" -f $CP
                $RangeProg.Update( $Percent )
                
                $_
            } | Write-Output
            $RangeProg.OverallStatus = "Finished"
            $RangeProg.CurrentOperation = ""
            $RangeProg.Update( 1.0 )
        }
    } | ForEach-Object {
        $OverallProg.OverallStatus = "Generating Characters ({0:F1}%)" -f ( 100.0 * ( ++$Script:NumGenCharacters / $TotalAssignedCharacters ) )
        $OverallProg.Update( $Script:NumGenCharacters / $TotalAssignedCharacters )
        
        $CP = $_
        $Character = New-Character $CP
        
        If ( $Name.StartsWith( '<CJK' ) )
        {
            $WrName = "CJK UNIFIED IDEOGRAPH-{0:X4}" -f $CP
        }
        ElseIf ( $Name.StartsWith( '<Hangul' ) )
        {
            $WrName = Get-HangulSyllableName -CodePoint $CP
        }
        ElseIf ( $Name.StartsWith( '<' ) )
        {
            $WrName = $Null
        }
        Else
        {
            $WrName = $Name
        }
        
        <# Attach 'Name'
            Characters with a null or empty name, such as the C0 and C1 control codes, have nil as their value.
            Code point labels are given in a different property. TODO: Figure out which one and document it here.
        #>
        If ( $WrName -ne $Null )
        {
            $ProperNameVal = [Normalize]::CharacterName( $WrName )
            $Val = New-Object LuaString $ProperNameVal, DoubleQuote
            $KV = New-Object LuaKV $PropertyNames.Name, $Val
            Add-CharacterProperty $Character $KV
        }
        
        <# Attach non-standard property 'Original_Name'
            As above, but the character name itself is not normalized in any way.
        #>
        If ( $WrName -ne $Null )
        {
            $Val = New-Object LuaString $WrName, DoubleQuote
            $KV = New-Object LuaKV $PropertyNames.Original_Name, $Val
            Add-CharacterProperty $Character $KV
        }
        
        <# Attach 'General_Category'
            No notes for this.
        #>
        & {
            $ProperGenCatVal = Normalize-PropertyValueName $PropertyNames.General_Category $GenCat
            $Val = New-Object LuaString $ProperGenCatVal, Long
            $KV = New-Object LuaKV $PropertyNames.General_Category, $Val
            Add-CharacterProperty $Character $KV
        }
        
        <# Attach 'Canonical_Combining_Class'
            Although given as a numeric value in the data files, the values are canonically enumerated values, which is how they're currently encoded in the master table.
           
           Attach non-standard property 'Numeric_Canonical_Combining_Class'
            The numeric value is given in a non-standard property.
        #>
        & {
            $ProperCccVal = Normalize-PropertyValueName $PropertyNames.Canonical_Combining_Class $CanCombClass
            $Val = New-Object LuaString $ProperCccVal, Long
            $NVal = New-Object LuaInteger $CanCombClass
            $KV = New-Object LuaKV $PropertyNames.Canonical_Combining_Class, $Val
            $NKV = New-Object LuaKV $PropertyNames.Numeric_Canonical_Combining_Class, $NVal
            If ( $CanCombClass -ne '0' )
            {
                Add-CharacterProperty $Character $KV
            }
            Add-CharacterProperty $Character $NKV
        }
        
        <# Attach 'Bidi_Class'
            TODO: This is a complicated property.
        #>
        
        <# Attach 'Decomposition_Type' and 'Decomposition_Mapping'
            Decomposition_Type uses nil to represent the value 'Canonical'.
            Decomposition_Mapping uses nil to represent a decomposition mapping of a character to itself.
        #>
        & {
            If ( -not [String]::IsNullOrEmpty( $Decomp ) )
            {
                [String[]]$DecompFields = $Decomp -split ' '
                $StartIdx = 0
                
                # Attach Decomposition_Type
                If ( $DecompFields[0].StartsWith( '<' ) )
                {
                    $StartIdx = 1
                    $DecompType = Normalize-PropertyValueName -PropertyName $PropertyNames.Decomposition_Type -Value $DecompFields[0].Substring( 1, $DecompFields[0].Length-2 )
                    $Val = New-Object LuaString $DecompType, Long
                    $KV = New-Object LuaKV $PropertyNames.Decomposition_Type, $Val
                    Add-CharacterProperty $Character $KV
                }
                
                # Attach Decomposition_Mapping
                [String[]]$CharFields = $DecompFields[ $StartIdx .. ($DecompFields.Count-1) ]
                $StringBuilder = New-Object System.Text.StringBuilder $CharFields.Count, ($CharFields.Count*2)
                ForEach ( $Char in $CharFields )
                {
                    $CP = [Int32]::Parse( $Char, 'AllowHexSpecifier' )
                    [Void]$StringBuilder.Append( [Char]::ConvertFromUtf32( $CP ) )
                }
                $Val = New-Object LuaUString $StringBuilder.ToString()
                $KV = New-Object LuaKV $PropertyNames.Decomposition_Mapping, $Val
                Add-CharacterProperty $Character $KV
            }
        }
        
        <# Attach 'Numeric_Type' and 'Numeric_Value'
            'Numeric_Value' is represented as an integer or float, as appropriate.
            If the numeric value is a rational value, then it *also* is present as 'Rational_Numeric_Value', a table with 'den' and 'num' keys and integer values.
            Note that this is not the only place where Numeric_Type and Numeric_Value are attached, some are read from Unihan files in another stage of the pipeline
        #>
        & {
            If ( $Num3 -ne "" ) # Has a numeric type
            {
                If ( $Num2 -eq "" -and $Num1 -eq "" ) # Numeric_Type=Numeric
                {
                    $TypeValName = Normalize-PropertyValueName $PropertyNames.Numeric_Type "Numeric"
                    $TypeVal = New-Object LuaString $TypeValName, Long
                    $TypeKV = New-Object LuaKV $PropertyNames.Numeric_Type, $TypeVal
                    Add-CharacterProperty $Character $TypeKV
                    If ( -not $Num3.Contains( "/" ) ) # Integer
                    {
                        $ValueVal = New-Object LuaInteger ([Int64]::Parse( $Num3 ))
                        $ValueKV = New-Object LuaKV $PropertyNames.Numeric_Value, $ValueVal
                        Add-CharacterProperty $Character $ValueKV
                    }
                    Else
                    {
                        $Num, $Denom = @($Num3 -split '/') | ForEach-Object { [Int64]::Parse( $_ ) }
                        $ValueVal = New-Object LuaRational $Num, $Denom
                        $LuaNumVal = New-Object LuaKV 'num', (New-Object LuaInteger $Num)
                        $LuaDenVal = New-Object LuaKV 'den', (New-Object LuaInteger $Denom)
                        $RatValueVal = New-Object LuaMixedTable 
                            $RatValueVal.Add( $LuaNumVal )
                            $RatValueVal.Add( $LuaDenVal )
                        $NumValueKV = New-Object LuaKV $PropertyNames.Numeric_Value, $ValueVal
                        $RatValueKV = New-Object LuaKV $PropertyNames.Rational_Numeric_Value, $RatValueVal
                        Add-CharacterProperty $Character $NumValueKV
                        Add-CharacterProperty $Character $RatValueKV
                    }
                }
                ElseIf ( $Num2 -ne "" ) # Numeric_Type=Digit
                {
                    $TypeValName = Normalize-PropertyValueName $PropertyNames.Numeric_Type "Digit"
                    $TypeVal = New-Object LuaString $TypeValName, Long
                    $ValueVal = New-Object LuaInteger ([Int64]::Parse( $Num3 ))
                    $TypeKV = New-Object LuaKV $PropertyNames.Numeric_Type, $TypeVal
                    $ValueKV = New-Object LuaKV $PropertyNames.Numeric_Value, $ValueVal
                    Add-CharacterProperty $Character $TypeKV
                    Add-CharacterProperty $Character $ValueKV
                }
                Else # Numeric_Type=Decimal
                {
                    $TypeValName = Normalize-PropertyValueName $PropertyNames.Numeric_Type "Decimal"
                    $TypeVal = New-Object LuaString $TypeValName, Long
                    $ValueVal = New-Object LuaInteger ([Int64]::Parse( $Num3 ))
                    $TypeKV = New-Object LuaKV $PropertyNames.Numeric_Type, $TypeVal
                    $ValueKV = New-Object LuaKV $PropertyNames.Numeric_Value, $ValueVal
                    Add-CharacterProperty $Character $TypeKV
                    Add-CharacterProperty $Character $ValueKV
                }
            }
        }
        
        <# Attach 'Bidi_Mirrored'
            'Yes' is represented by 'true' and 'No' is represented by nil.
        #>
        & {
            If ( $BidiMirrored -eq 'Y' )
            {
                $KV = New-Object LuaKV $PropertyNames.Bidi_Mirrored, $LuaTrue
                Add-CharacterProperty $Character $KV
            }
        }
        
        <# Attach 'Unicode_1_Name'
            TODO: Might skip this one, actually.
        #>
        
        <# Attach 'ISO_Comment'
            Not doing this one, it is long-obsolete and no character has a non-null value for it yet.
        #>
        
        <# Attach 'Simple_Uppercase_Mapping'
        #>
        & {
            If ( -not [String]::IsNullOrEmpty( $SimpleUpperMap ) )
            {
                [Int32]$SUM_CP = [Int32]::Parse( $SimpleUpperMap, 'AllowHexSpecifier' )
                $Val = New-Object LuaUString ([Char]::ConvertFromUtf32( $SUM_CP ))
                $KV = New-Object LuaKV $PropertyNames.Simple_Uppercase_Mapping, $Val
                Add-CharacterProperty $Character $KV
            }
        }
        
        <# Attach 'Simple_Lowercase_Mapping'
        #>
        & {
            If ( -not [String]::IsNullOrEmpty( $SimpleLowerMap ) )
            {
                [Int32]$SLM_CP = [Int32]::Parse( $SimpleLowerMap, 'AllowHexSpecifier' )
                $Val = New-Object LuaUString ([Char]::ConvertFromUtf32( $SLM_CP ))
                $KV = New-Object LuAKV $PropertyNames.Simple_Lowercase_Mapping, $Val
                Add-CharacterProperty $Character $KV
            }
        }
        
        <# Attach 'Simple_Titlecase_Mapping'
        #>
        & {
            If ( -not [String]::IsNullOrEmpty( $SimpleTitleMap ) )
            {
                [Int32]$STM_CP = [Int32]::Parse( $SimpleTitleMap, 'AllowHexSpecifier' )
                $Val = New-Object LuaUString ([Char]::ConvertFromUtf32( $STM_CP ))
                $KV = New-Object LuaKV $PropertyNames.Simple_Titlecase_Mapping, $Val
                Add-CharacterProperty $Character $KV
            }
        }
        
        $Character | Write-Output
    }
}
<# Proceses PropList.txt
    This filter adds the following properties:
        ASCII_Hex_Digit
        Bidi_Control
        Dash
        Deprecated
        Diacritic
        Extender
        Hex_Digit
        Hyphen
        Ideographic
        IDS_Binary_Operator
        IDS_Trinary_Operator
        Join_Control
        Logical_Order_Exception
        Noncharacter_Code_Point
        Pattern_Syntax
        Pattern_White_Space
        Prepended_Concatenation_Mark
        Quotation_Mark
        Radical
        Regional_Indicator
        Sentence_Terminal
        Soft_Dotted
        Terminal_Punctuation
        Unified_Ideograph
        Variation_Selector
        White_Space
#>

Param
(
    [Parameter(
        Mandatory=$True,
        ValueFromPipeline=$True)]
    [PSObject[]]
    $InputCharacter
)

Begin
{
    Import-Module .\Normalize.psm1
    Import-Module .\Progress.psm1
    Import-Module .\FileUtilities.psm1
    Import-Module .\CharacterObject.psm1
    
    $ExpectedCategories = "ASCII_Hex_Digit", "Bidi_Control", "Dash", "Deprecated", "Diacritic", "Extender", "Hex_Digit", "Hyphen",
        "Ideographic", "IDS_Binary_Operator", "IDS_Trinary_Operator", "Join_Control", "Logical_Order_Exception", "Noncharacter_Code_Point",
        "Pattern_Syntax", "Pattern_White_Space", "Prepended_Concatenation_Mark", "Quotation_Mark", "Radical", "Regional_Indicator",
        "Sentence_Terminal", "Soft_Dotted", "Terminal_Punctuation", "Unified_Ideograph", "Variation_Selector", "White_Space"

    $ContributoryProperties = "Other_Alphabetic", "Other_Default_Ignorable_Code_Point", "Other_Grapheme_Extend", "Other_ID_Continue",
        "Other_ID_Start", "Other_Lowercase", "Other_Math", "Other_Uppercase"
    
    $RangeDict = New-Object ([System.Collections.Generic.Dictionary[String,System.Collections.Generic.List[PSObject]]]).ToString()
    $RangeIdxDict = New-Object ([System.Collections.Generic.Dictionary[String,Int32]]).ToString()
    
    $CategoryUsed = @{}
    $ExpectedCategories | ForEach-Object { $CategoryUsed[ $_ ] = $True }
    $ContributoryProperties | ForEach-Object { $CategoryUsed[ $_ ] = $False }
    
    $NormalizedCategoryNames = @{}
    ForEach ( $Category in $ExpectedCategories )
    {
        $NormCatName = Normalize-PropertyName $Category
        $RangeDict.Add( $NormCatName, (New-Object ([System.Collections.Generic.List[PSObject]]).ToString()) )
        $RangeIdxDict.Add( $NormCatName, 0 )
        $NormalizedCategoryNames.Add( $Category, $NormCatName )
    }
    
    $CharacterKVs = @{}
    $NormalizedCategoryNames.Values | ForEach-Object {
        $TrueValue = New-Object LuaBoolean $True
        $CharacterKVs[ $_ ] = New-Object LuaKV $_, $TrueValue
    }
    
    Get-Content UCD\PropList.txt | Where-Object {
        $_ -ne "" -and $_ -notmatch '^\s*#'
    } | ForEach-Object {
        [Void]($_ -match '^([^#]*)#?')
        $LineContent = $Matches[1]
        $RangeContent, $Category = @($LineContent -split ';') | ForEach-Object { $_.Trim() }
        If ( $CategoryUsed[ $Category ] )
        {
            If ( $RangeContent.Contains( "." ) )
            {
                [UInt32]$Lo, [UInt32]$Hi = @($RangeContent -split '\.\.') | ForEach-Object { [UInt32]::Parse( $_, 'AllowHexSpecifier' ) }
            }
            Else
            {
                [UInt32]$Lo = [UInt32]::Parse( $RangeContent, 'AllowHexSpecifier' )
                [UInt32]$Hi = $Lo
            }
            $NormCategory = $NormalizedCategoryNames[ $Category ]
            $RangeDict[ $NormCategory ].Add( @{ Lo = $Lo; Hi = $Hi } )
        }
    }
}

Process
{
    ForEach ( $Character in $InputCharacter )
    {
        $CharCP = $Character.cp
        
        :Category ForEach ( $Category in $ExpectedCategories )
        {
            $NormCategory = $NormalizedCategoryNames[ $Category ]
            
            $CategoryRangeList = $RangeDict[ $NormCategory ]
            
            While ( $CharCP -gt $CategoryRangeList[ $RangeIdxDict[ $NormCategory ] ].Hi )
            {
                $RangeIdxDict[ $NormCategory ] += 1
                If ( $RangeIdxDict[ $NormCategory ] -ge $CategoryRangeList.Count )
                {
                    Continue Category
                }
            }
            
            $Range = $CategoryRangeList[ $RangeIdxDict[ $NormCategory ] ]
            If ( $Range.Lo -le $CharCP -and $CharCP -le $Range.Hi )
            {
                Add-CharacterProperty $Character $CharacterKVs[ $NormCategory ]
            }
        }
        
        $Character | Write-Output
    }
}
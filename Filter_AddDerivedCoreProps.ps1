<# Proceses DerivedCoreProperties.txt
    This filter adds the following properties:
        Lowercase
        Uppercase
        Cased
        Case_Ignorable
        Changes_When_Lowercased
        Changes_When_Uppercased
        Changes_When_Titlecased
        Changes_When_Casefolded
        Changes_When_Casemapped
        Alphabetic
        Default_Ignorable_Code_Point
        Grapheme_Base
        Grapheme_Extend
        Grapheme_Link
        Math
        ID_Start
        ID_Continue
        XID_Start
        XID_Continue
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
    
    $ExpectedCategories = "Lowercase", "Uppercase", "Cased", "Case_Ignorable", "Changes_When_Lowercased", "Changes_When_Uppercased", 
        "Changes_When_Titlecased", "Changes_When_Casefolded", "Changes_When_Casemapped", "Alphabetic", "Default_Ignorable_Code_Point", 
        "Grapheme_Base", "Grapheme_Extend", "Grapheme_Link", "Math", "ID_Start", "ID_Continue", "XID_Start", "XID_Continue"
    
    $RangeDict = New-Object ([System.Collections.Generic.Dictionary[String,System.Collections.Generic.List[PSObject]]]).ToString()
    $RangeIdxDict = New-Object ([System.Collections.Generic.Dictionary[String,Int32]]).ToString()
    
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
    
    Get-Content UCD\DerivedCoreProperties.txt | Where-Object {
        $_ -ne "" -and $_ -notmatch '^\s*#'
    } | ForEach-Object {
        [Void]($_ -match '^([^#]*)#?')
        $LineContent = $Matches[1]
        $RangeContent, $Category = @($LineContent -split ';') | ForEach-Object { $_.Trim() }
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
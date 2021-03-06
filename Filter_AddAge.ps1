<# Proceses DerivedAge.txt
    This filter adds the Age property.
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
    Import-Module .\CharacterObject.psm1
    
    $CategoryKey = New-Object LuaString (Normalize-PropertyName Age), Identifier
    $NumericCategoryKey = New-Object LuaString ([Normalize]::PropertyName( "Numeric_Age" )), Identifier
    
    [PSObject[]]$AgeRanges = Get-Content UCD\DerivedAge.txt |
        Where-Object { $_ -ne "" -and -not $_.StartsWith( "#") } |
        ForEach-Object {
            $Ranges, $Content = $_ -split ';' | ForEach-Object { $_.Trim() }
            $Content = ($Content -split ' ')[0]
            If ( -not $Ranges.Contains( "." ) )
            {
                # Singular range
                [UInt32]$FirstCP = [UInt32]::Parse( $Ranges, 'AllowHexSpecifier' )
                [UInt32]$LastCP = $FirstCP
            }
            Else
            {
                # Actual range
                [UInt32]$FirstCP, [UInt32]$LastCP = ($Ranges -split '\.\.') | ForEach-Object { [UInt32]::Parse( $_, 'AllowHexSpecifier' ) }
            }
            $ContentValue = New-Object LuaString (Normalize-PropertyValueName Age $Content), Long
            $NumericContentValue = New-Object LuaReal ([Double]::Parse( $Content ))
            
            $AgeKV = New-Object LuaKV $CategoryKey, $ContentValue
            $NumericAgeKV = New-Object LuaKV $NumericCategoryKey, $NumericContentValue
            
            New-Object PSObject -Property @{
                Low = $FirstCP;
                High = $LastCP;
                AgeKV = $AgeKV;
                NumericAgeKV = $NumericAgeKV;
            } | Write-Output
        } |
        Sort-Object -Property Low
    $AgeRangesIdx = 0
}

Process
{
    ForEach ( $Character in $InputCharacter )
    {
        $CharCP = $Character.cp
        
        While ( ($AgeRangesIdx+1 -lt $AgeRanges.Count) -and ($AgeRanges[ $AgeRangesIdx ].High -lt $CharCP) )
        {
            $AgeRangesIdx += 1
        }
        
        $CurCat = $AgeRanges[ $AgeRangesIdx ]
        If ( $CurCat.Low -le $CharCP -and $CharCP -le $CurCat.High )
        {
            Add-CharacterProperty $Character $CurCat.AgeKV
            Add-CharacterProperty $Character $CurCat.NumericAgeKV
        }
        
        $Character | Write-Output
    }
}
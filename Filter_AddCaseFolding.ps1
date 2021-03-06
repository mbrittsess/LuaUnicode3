<# Processes CaseFolding.txt
    This filter adds the Case_Folding and Simple_Case_Folding properties.
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
    Import-Module .\FileUtilities.psm1
    
    $CFR = Get-StreamReader UCD\CaseFolding.txt
    $Properties = & { While ( ($Line = $CFR.ReadNonCommentLine()) -ne $Null )
    {
        $In_Char, $MapType, $Mapping = [Text.RegularExpressions.Regex]::Matches( ($Line | Strip-Comment), '[^;]+' ) | ForEach-Object { $_.Captures[0].Value.Trim() } | Where-Object { -not [String]::IsNullOrEmpty( $_ ) }
        [UInt32]$InCP = [UInt32]::Parse( $In_Char, 'AllowHexSpecifier' )
        $MappingCPs = -join [String[]](($Mapping -split ' ') | ForEach-Object { [String]([Char]::ConvertFromUtf32( [Int32]::Parse( $_, 'AllowHexSpecifier' ) )) })
        $MappingUStr = New-Object LuaUString $MappingCPs
        New-Object PSObject -Property @{
            CP = $InCP;
            MapType = $MapType;
            OutString = $MappingUStr;
        }
    } }
    
    $SimpleProperties = $Properties | Where-Object { "C", "S" -contains $_.MapType } | Sort-Object -Property CP
    $FullProperties = $Properties | Where-Object { $_.MapType -eq "F" } | Sort-Object -Property CP
    
    $SimpleIdx = 0
    $FullIdx = 0
}

Process
{
    ForEach ( $Character in $InputCharacter )
    {
        $CharCP = $Character.cp
        
        If ( $SimpleIdx -lt $SimpleProperties.Count -and $CharCP -eq $SimpleProperties[ $SimpleIdx ].CP )
        {
            $Prop = New-Object LuaKV (Normalize-PropertyName Simple_Case_Folding), $SimpleProperties[ $SimpleIdx ].OutString
            Add-CharacterProperty $Character $Prop
            $SimpleIdx += 1
        }
        
        If ( $FullIdx -lt $FullProperties.Count -and $CharCP -eq $FullProperties[ $FullIdx ].CP )
        {
            $Prop = New-Object LuaKV (Normalize-PropertyName Case_Folding), $FullProperties[ $FullIdx ].OutString
            Add-CharacterProperty $Character $Prop
            $FullIdx += 1
        }
        
        $Character | Write-Output
    }
}
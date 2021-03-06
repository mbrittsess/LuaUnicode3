<# Proceses SpecialCasing.txt
    This filter adds the Lowercase_Mapping, Uppercase_Mapping, and Titlecase_Mapping properties, as well as our additional properties
Lowercase_Mapping_Condition, Uppercase_Mapping_Condition, and Titlecase_Mapping_Condition.
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
    
    $CasingContextNames = "Final_Sigma", "After_Soft_Dotted", "More_Above", "Before_Dot", "After_I" | ForEach-Object { $_; "Not_" + $_ }
    
    $SpecialCasingProperties_Unsorted = New-Object ([System.Collections.Generic.List[PSObject]]).ToString()
    
    Get-Content UCD\SpecialCasing.txt | Where-Object {
        $_ -ne "" -and -not $_.StartsWith( "#" )
    } | ForEach-Object {
        $Line = $_
        $CP_str, $Lower_str, $Title_str, $Upper_str, $CondList, $Others = $Line -split ';' | ForEach-Object { $_.Trim() }
        [Void]( $CondList -match '^([^#]*)#?' )
        $CondList = $Matches[1].Trim()
        
        $LangSpecific = $False
        If ( $CondList -ne "" )
        {
            $Result = $CondList -split ' ' | ForEach-Object { If ( $CasingContextNames -notcontains $_ ) { $LangSpecific = $True } }
            If ( $Result -ne $Null )
            {
                $LangSpecific = $True
            }
        }
        
        If ( -not $LangSpecific )
        {
            [LuaKV[]]$KVs = & {
                If ( $CP_str -ne $Lower_str )
                {
                    $Lower = -join [String[]](($Lower_str -split ' ') | ForEach-Object { [String]([Char]::ConvertFromUtf32( [Int32]::Parse( $_, 'AllowHexSpecifier' ) )) })
                    $LowerUstr = New-Object LuaUString $Lower
                    New-Object LuaKV (Normalize-PropertyName Lowercase_Mapping), $LowerUstr | Write-Output
                    If ( $CondList -ne "" )
                    {
                        New-Object LuaKV lowercasemappingcondition, (New-Object LuaString $CondList, Long) | Write-Output
                    }
                }
                
                If ( $CP_str -ne $Title_str )
                {
                    $Title = -join [String[]](($Title_str -split ' ') | ForEach-Object { [String]([Char]::ConvertFromUtf32( [Int32]::Parse( $_, 'AllowHexSpecifier' ) )) })
                    $TitleUstr = New-Object LuaUString $Title
                    New-Object LuaKV (Normalize-PropertyName Titlecase_Mapping), $TitleUstr | Write-Output
                    If ( $CondList -ne "" )
                    {
                        New-Object LuaKV titlecasemappingcondition, (New-Object LuaString $CondList, Long) | Write-Output
                    }
                }
                
                If ( $CP_str -ne $Upper_str )
                {
                    $Upper = -join [String[]](($Upper_str -split ' ') | ForEach-Object { [String]([Char]::ConvertFromUtf32( [Int32]::Parse( $_, 'AllowHexSpecifier' ) )) })
                    $UpperUstr = New-Object LuaUString $Upper
                    New-Object LuaKV (Normalize-PropertyName Uppercase_Mapping), $UpperUstr | Write-Output
                    If ( $CondList -ne "" )
                    {
                        New-Object LuaKV uppercasemappingcondition, (New-Object LuaString $CondList, Long) | Write-Output
                    }
                }
            }
            
            $CasingsObject = New-Object PSObject -Property @{
                CP = [UInt32]::Parse( $CP_str, 'AllowHexSpecifier' );
                KeyValues = $KVs;
            }
            
            $SpecialCasingProperties_Unsorted.Add( $CasingsObject )
        }
    }
    
    [PSObject[]]$SpecialCasingProperties = $SpecialCasingProperties_Unsorted | Sort-Object -Property CP
    $PropertiesIndex = 0
    $CurCP = $SpecialCasingProperties[0].CP
}

Process
{
    ForEach ( $Character in $InputCharacter )
    {
        $CharCP = $Character.cp
        
        If ( $CharCP -eq $CurCP )
        {
            ForEach ( $KV in $SpecialCasingProperties[ $PropertiesIndex ].KeyValues )
            {
                Add-CharacterProperty $Character $KV
            }
            $PropertiesIndex += 1
            If ( $PropertiesIndex -lt $SpecialCasingProperties.Count )
            {
                $CurCP = $SpecialCasingProperties[ $PropertiesIndex ].CP
            }
            Else
            {
                $CurCP = 0x110000
            }
        }
        
        $Character | Write-Output
    }
}
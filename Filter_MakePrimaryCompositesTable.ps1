<# Creates our master table of Primary Composites, used for NFC and NFKC normalization.
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
    
    $FullExclusionRanges = Get-Content UCD\DerivedNormalizationProps.txt | Where-Object {
        -not ($_.StartsWith( "#" ) -or $_.StartsWith( "@" ))
    } | ForEach-Object {
        $Ranges, $Type = $_ -split ';' | ForEach-Object { $_.Trim() }
        If ( $Ranges -is [String] -and $Type -is [String] -and $Type.StartsWith( "Full_Composition_Exclusion" ) )
        {
            $Start, $End = $Ranges -split '\.\.'
            If ( $End -eq $Null ) { $End = $Start }
            @{ Lo = [UInt32]::Parse( $Start, 'AllowHexSpecifier' ); Hi = [UInt32]::Parse( $End, 'AllowHexSpecifier' ) } | Write-Output
        }
    }
    $FullExclusionLookupIdx = 0
    
    $DecompTypeName = Normalize-PropertyName 'Decomposition_Type'
    $DecompMapName = Normalize-PropertyName 'Decomposition_Mapping'
    
    $PrimaryCompositeList = New-Object ([System.Collections.Generic.List[PSObject]].ToString())
}

Process
{
    ForEach ( $Character in $InputCharacter )
    {
        $R = $FullExclusionRanges[ $FullExclusionLookupIdx ]
        $CP = $Character.cp
        If ( -not ( $R.Lo -le $CP -and $CP -le $R.Hi ) )
        {
            If ( $Character.properties.ContainsKey( $DecompMapName ) -and -not $Character.properties.ContainsKey( $DecompTypeName ) )
            {
                $PrimaryCompositeList.Add( $Character )
                ("Added character U+{0:X4} to Primary Composite List" -f $CP) | Write-Verbose
            }
        }
        
        If ( $CP -eq $R.Hi )
        {
            $FullExclusionLookupIdx += 1
        }
        
        $Character | Write-Output
    }
}

End
{
    $PrimaryCompositesRoot = @{}
    ForEach ( $Char in $PrimaryCompositeList )
    {
        [LuaUString]$Mapping = $Char.properties[ $DecompMapName ].Value
        If ( $Mapping.Values.Count -ne 2 )
        {
            Throw New-Object Exception "Decomposition_Mapping of primary composites must be 2 characters long"
        }
        [Int64]$L = $Mapping.Values[0].Value
        [Int64]$C = $Mapping.Values[1].Value
        [UInt32]$P = $Char.cp
        
        If ( -not $PrimaryCompositesRoot.ContainsKey( $C ) )
        {
            $PrimaryCompositesRoot.Add( $C, @{} )
        }
        $C_Tbl = $PrimaryCompositesRoot[ $C ]
        $C_Tbl[ $L ] = $P
    }
    
    & {
@'
return {
'@
    
        $RootKeys = $PrimaryCompositesRoot.Keys | Sort-Object
        ForEach ( $RootKey in $RootKeys )
        {
            $C_Tbl = $PrimaryCompositesRoot[ $RootKey ]
            $C_Tbl_Keys = $C_Tbl.Keys | Sort-Object
            $C_Tbl_Content = ($C_Tbl_Keys | ForEach-Object { '[ 0x{0:X4} ] = 0x{1:X4}' -f $_, $C_Tbl[ $_ ] }) -join ', '
            '    [ 0x{0:X4} ] = {{ {1} }};' -f $RootKey, $C_Tbl_Content
        }
    
    '}'
    } | Out-File -FilePath lua\us4l\internals\PrimaryCompositesTable.lua -Encoding ASCII
}
<# Adds the Name_Alias property.
    We've gone with a somewhat ad-hoc approach to how this property's value is represented, which we may change
at some point.
    If the character has any aliases, then Name_Alias is a table. All of the aliases (in their normalized forms)
are keys in the table, and the corresponding values are the names of the type of alias they are.
    Furthermore, if the character does not have a name at all, then the first alias listed in NameAliases.txt,
in its original form, is assigned as a value in the table, with the key being integer-1. TODO: See about changing
that to something better.
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
    
    $NASR = Get-StreamReader UCD\NameAliases.txt
    
    $EOF_Reached = $False
    $FileCurCP_str, $CurAlias, $CurAliasType = ($NASR.ReadNonCommentLine() | Strip-Comment) -split ';'
    [UInt32]$FileCurCP = [UInt32]::Parse( $FileCurCP_str, 'AllowHexSpecifier' )
    $AliasTypeStrings = @{}
    "control", "correction", "figment", "alternate", "abbreviation" | ForEach-Object {
        $AliasTypeStrings.Add( $_, (New-Object "LuaString" $_, "Long") )
    }
}

Process
{
    ForEach ( $Character in $InputCharacter )
    {
        $CharCP = $Character.cp
        
        If ( -not $EOF_Reached -and $FileCurCP -eq $CharCP )
        {
            $FirstAlias = $CurAlias
            [LuaKV[]]$Aliases = Do {
                $AliasVal = New-Object LuaString ([Normalize]::CharacterName( $CurAlias )), DoubleQuote
                $AliasType = $AliasTypeStrings[ $CurAliasType ]
                New-Object LuaKV $AliasVal, $AliasType | Write-Output
                
                $Line = $NASR.ReadNonCommentLine() | Strip-Comment
                If ( $Line -eq $Null )
                {
                    $EOF_Reached = $True
                    Break
                }
                $FileCurCP_str, $CurAlias, $CurAliasType = $Line -split ';'
                $FileCurCP = [UInt32]::Parse( $FileCurCP_str, 'AllowHexSpecifier' )
            } While ( $FileCurCP -eq $CharCP )
            
            $Tbl = New-Object LuaMixedTable
            
            If ( -not $Character.properties.ContainsKey( "name" ) )
            {
                $Tbl.Add( (New-Object LuaString $FirstAlias, DoubleQuote) )
            }
            
            $Aliases | ForEach-Object { $Tbl.Add( $_ ) }
            $AliasesProp = New-Object LuaKV "namealias", $Tbl
            Add-CharacterProperty $Character $AliasesProp
        }
        
        $Character | Write-Output
    }
}
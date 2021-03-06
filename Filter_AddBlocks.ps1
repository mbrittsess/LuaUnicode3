<# Proceses Blocks.txt
    This filter adds the Block property.
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
    
    $CategoryKey = New-Object LuaString (Normalize-PropertyName Block), Identifier
    
    $BR = Get-StreamReader UCD\Blocks.txt
    $CurLine = $BR.ReadNonCommentLine()
    
    $Range, $Category = ($CurLine -split ';') | ForEach-Object { $_.Trim() }
    [UInt32]$Low, [UInt32]$High = ($Range -split '\.\.') | ForEach-Object { [UInt32]::Parse( $_, 'AllowHexSpecifier' ) }
    $CategoryValue = New-Object LuaString (Normalize-PropertyValueName Block $Category), Long
    $CategoryKV = New-Object LuaKV $CategoryKey, $CategoryValue
}

Process
{
    ForEach ( $Character in $InputCharacter )
    {
        $CharCP = $Character.cp
        
        If ( $Low -le $CharCP -and $CharCP -le $High )
        {
            Add-CharacterProperty $Character $CategoryKV
        }
        
        If ( $CharCp -eq $High )
        {
            $CurLine = $BR.ReadNonCommentLine()
            
            If ( $CurLine -eq $Null )
            {
                $Low = 0x110000
                $High = 0x110001
            }
            Else
            {
                $Range, $Category = ($CurLine -split ';') | ForEach-Object { $_.Trim() }
                $Low, $High = ($Range -split '\.\.') | ForEach-Object { [UInt32]::Parse( $_, 'AllowHexSpecifier' ) }
                $CategoryValue = New-Object LuaString (Normalize-PropertyValueName Block $Category), Long
                $CategoryKV = New-Object LuaKV $CategoryKey, $CategoryValue
            }
        }
        
        $Character | Write-Output
    }
}
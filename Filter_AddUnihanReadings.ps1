<# Proceses Unihan_Readings.txt
    Adds properties:
        kCantonese
        kDefinition
        kHangul
        kHanyuPinlu
        kHanyuPinyin
        kJapaneseKun
        kJapaneseOn
        kKorean
        kMandarin
        kTang
        kVietnamese
        kXHC1983
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
    
    $URSR = Get-StreamReader Unihan\Unihan_Readings.txt
    
    $PrevLine = $URSR.ReadNonCommentLine()
    [UInt32]$PrevLineCP = [UInt32]::Parse( @($PrevLine -split "`t")[0].Substring(2), 'AllowHexSpecifier' )
    $ENC = [System.Text.Encoding]::UTF8
}

Process
{
    ForEach ( $Character in $InputCharacter )
    {
        $CharCP = $Character.cp
        
        If ( $CharCP -eq $PrevLineCP )
        {
            Do
            {
                $CP, $PropertyName, $PropertyContent = $PrevLine -split "`t"
                
                $NormPropertyName = Normalize-PropertyName $PropertyName
                $Value = New-Object LuaString $PropertyContent, DoubleQuote
                $KV = New-Object LuaKV $NormPropertyName, $Value
                Add-CharacterProperty $Character $KV
                
                $PrevLine = $URSR.ReadNonCommentLine()
                $PrevLineCP = If ( $PrevLine -ne $Null ) { [UInt32]::Parse( @($PrevLine -split "`t")[0].Substring(2), 'AllowHexSpecifier' ) } Else { 0x110000 }
            } While ( $PrevLineCP -eq $CharCP )
        }
        
        $Character | Write-Output
    }
}
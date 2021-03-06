Function Get-StreamReader ( [String]$Path )
{
    Return New-Object System.IO.StreamReader $Path, ([Text.Encoding]::UTF8) |
        Add-Member ScriptMethod ReadNonBlankLine {
            While ( ($Line = $This.ReadLine()) -ne $Null -and ($Line -match '^\s*$') ) { }
            Return $Line
        } -PassThru |
        Add-Member ScriptMethod ReadNonCommentLine {
            While ( ($Line = $This.ReadLine()) -ne $Null -and ($Line -match '^\s*(#.*)?$') ) { }
            Return $Line
        } -PassThru |
        Add-Member ScriptProperty PositionPercent {
            Return [Double]($This.BaseStream.Position / $This.BaseStream.Length)
        } -PassThru
}

Filter Strip-Comment { $_ -replace '#.*$', '' }

Export-ModuleMember -Function Get-StreamReader, Strip-Comment
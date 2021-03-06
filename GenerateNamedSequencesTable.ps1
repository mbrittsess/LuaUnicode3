Import-Module .\CompileCS.psm1
#Import-Module .\Progress.psm1 # TODO: Add progress stuff later
Import-Module .\FileUtilities.psm1

$NSSR = Get-StreamReader UCD\NamedSequences.txt
& {
@'
local MakeUString = require "us4l.internals.MakeUString"

local ret_tbl = {
'@

    While ( ($Line = $NSSR.ReadNonCommentLine()) -ne $Null )
    {
        $Name, $Seq_str = $Line -split ';'
        $NormName = [Normalize]::CharacterName( $Name )
        $OutCPs = (-split $Seq_str) | ForEach-Object { "0x" + $_.TrimStart( '0' ) }
        '    [ "{0}" ] = MakeUString{{ {1} }};' -f $NormName, ($OutCPs -join ', ')
    }
@'
}

return ret_tbl
'@
} | Out-File -FilePath lua\us4l\internals\NamedSequencesTable.lua -Encoding ASCII
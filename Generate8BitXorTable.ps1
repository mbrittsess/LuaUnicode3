& {
    "return {"
    ForEach ( $L in 0 .. 255 )
    {
        $Open = If ( $L -eq 0 ) { "[0] = {" } Else { "{" }
        [String[]]$Entries = & {
            ForEach ( $R in 0 .. 255 )
            {
                $Start = If ( $R -eq 0 ) { "[0] = " } Else { "" }
                $Result = $L -bXOR $R
                "{0}0x{1:X2}" -f $Start, $Result
            }
        }
        $Content = $Entries -join ", "
        $Close = "};"
        "    $Open $Content $Close"
    }
    "}"
} | Out-File -FilePath "lua\us4l\internals\8BitXorTable.lua" -Encoding ASCII

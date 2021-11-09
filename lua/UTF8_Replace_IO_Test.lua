require "us4l"
local uio = require "us4l.io"
local hf = uio.openread( [[..\HashTest\jp_words.txt]], { Encoding = "UTF8", DecodingMethod = "replace" } )
for i = 1, 10 do
    local l = hf:read("*l")
    print( string.format( "Line #%i:", i ) )
    print( l:PrettyPrint() .. "\n" )
end
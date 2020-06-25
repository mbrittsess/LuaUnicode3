local ToString = require("us4l.Encodings").UTF8.FromUString
local ToUString = require("us4l.Encodings").UTF8.ToUString
local MakeUString = require "us4l.internals.MakeUString"

orig_ustr = MakeUString{ 0x0024, 0x00A2, 0x0939, 0x20AC, 0x10348 }

local out_str = ToString( orig_ustr )
local print_str
do
    local prefix_str = ""
    print_str = out_str:gsub(".", function ( char )
        local ret = string.format( "%s0x%02X", prefix_str, char:byte() )
        prefix_str = ","
        return ret
    end )
end
print( print_str )

orig_str = "\036\194\162\224\164\185\226\130\172\240\144\141\136"
local out_ustr = ToUString( orig_str )
for _,char in ipairs( out_ustr ) do
    print( string.format( "U+%04X %s", char.codepoint, char.originalname ) )
end

round_ustr = ToUString( ToString( orig_ustr ) )

print( string.format( "Round-trip successful UStr->Str->UStr: %s", tostring( orig_ustr == round_ustr ) ) )
print( string.format( "Round-trip successful Str->UStr->Str:  %s", tostring( orig_str == ToString( ToUString( orig_str ) ) ) ) )
print( "Round-trip UString:" )
for _, char in ipairs( round_ustr ) do
    print( string.format( "  U+%04X %s", char.codepoint, char.originalname ) )
end
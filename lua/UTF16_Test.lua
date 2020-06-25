local ToU8String = require("us4l.Encodings").UTF8.FromUString
local U16BEToUString = require("us4l.Encodings").UTF16BE.ToUString
local MakeUString = require "us4l.internals.MakeUString"

local fhandle = io.open( [[..\CharacterObject.psm1]], "rb" )
fhandle:read( 2 ) --Dispose of BOM
local utf16_line = fhandle:read( 30*2 )
local ustr_line = U16BEToUString( utf16_line )
local cvt_line = ToU8String( ustr_line )
print( "Expected in file:\n Import-Module .\\CompileCS.psm1" )
print( "Found in file:\n " .. cvt_line )
print( "Matched: " .. tostring( cvt_line == "Import-Module .\\CompileCS.psm1" ) )

local Encodings = require "us4l.Encodings"
local UTF16LE = Encodings.UTF16LE
local UTF16BE = Encodings.UTF16BE

local orig_str_le = string.char( 0x24, 0x00, 0xAC, 0x20, 0x01, 0xD8, 0x37, 0xDC, 0x52, 0xD8, 0x62, 0xDF )
local orig_str_be = string.char( 0x00, 0x24, 0x20, 0xAC, 0xD8, 0x01, 0xDC, 0x37, 0xD8, 0x52, 0xDF, 0x62 )
local orig_ustr = MakeUString{ 0x0024, 0x20AC, 0x10437, 0x24B62 }

local strle2ustr = UTF16LE.ToUString( orig_str_le )
print( tostring( orig_ustr == strle2ustr ) )

local round_str_le = UTF16LE.FromUString( UTF16LE.ToUString( orig_str_le ) )
print( string.format( "Round-trip successful StrLE->UStr->StrLE: %s", tostring( orig_str_le == round_str_le ) ) )
print( string.format( "Round-trip successful UStr->StrBE->UStr:  %s", tostring( orig_ustr == UTF16BE.ToUString( UTF16BE.FromUString( orig_ustr ) ) ) ) )
print( string.format( "Cross-code successful StrBE->Ustr->StrLE: %s", tostring( orig_str_le == UTF16LE.FromUString( UTF16BE.ToUString( orig_str_be ) ) ) ) )
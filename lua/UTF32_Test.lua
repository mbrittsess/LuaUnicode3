local Encodings = require "us4l.Encodings"
local MakeUString = require "us4l.internals.MakeUString"

local UTF32LE = Encodings.UTF32LE
local UTF32BE = Encodings.UTF32BE

local orig_ustr = Encodings.UTF8.ToUString( "Import-Module" )
local utf32le_out = UTF32LE.FromUString( orig_ustr )
local utf32be_out = UTF32BE.FromUString( orig_ustr )

print( "Conversion Successful StrU8->UStr->StrU32LE->UStr: " .. tostring( orig_ustr == UTF32LE.ToUString( UTF32LE.FromUString( orig_ustr ) ) ) )
print( "Conversion Successful StrU8->Ustr->StrU32BE->UStr: " .. tostring( orig_ustr == UTF32BE.ToUString( UTF32BE.FromUString( orig_ustr ) ) ) )
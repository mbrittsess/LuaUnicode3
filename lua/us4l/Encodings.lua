--TODO: Need to delete and remake this
--None of the functions in this module can use UString methods because many of these functions are used to *implement* UString methods

require "us4l.internals.MasterTable.InitAllChunks"
local MakeUString = require "us4l.internals.MakeUString"
local LuaVersion = require "us4l.internals.LuaVersion"
local unpack = table.unpack or unpack
local floor = math.floor

local tointeger
if LuaVersion == "Lua53" then
    tointeger = math.tointeger
else
    tointeger = function ( x ) return x end
end

local MaxArgsPassed = 128 --[[Certain functions take a series of distinct arguments instead of a list. There's a limit to how many
    arguments can be passed or values returned at once (somewhere below 2^8 or so), so this number controls how many are used at once.]]

local export = {
    UTF8 = {};
    UTF16LE = {};
    UTF16BE = {};
    UTF32LE = {};
    UTF32BE = {};
}

--Shortcut for making integers with binary literals
local bin
if LuaVersion == "Lua53" then
    function bin ( in_str )
        return math.tointeger( tonumber( in_str:gsub("_", ""), 2 ) )
    end
else
    function bin ( in_str )
        return tonumber( in_str:gsub("_", ""), 2 )
    end
end

local function CpListFromUString ( ustr )
    local cp_list = {}
    for i = 1, #ustr do
        cp_list[ i ] = ustr[ i ].codepoint
    end
    return cp_list
end

--[[=============
    UTF-8 SECTION
    =============]]
local UTF8_CpListFromString, UTF8_StringFromCpList
if LuaVersion == "Lua53" then
    function UTF8_CpListFromString ( str )
        local cp_list = {}
        for _, cp in utf8.codes( str ) do
            cp_list[ #cp_list + 1 ] = cp
        end
        return cp_list
    end
    
    function UTF8_StringFromCpList ( cp_list )
        local buf = {}
        local start_idx = 1
        while start_idx <= #cp_list do
            local end_idx = math.min( start_idx + MaxArgsPassed - 1, #cp_list  )
            buf[ #buf + 1 ] = utf8.char( unpack( cp_list, start_idx, end_idx ) )
            start_idx = end_idx + 1
        end
        return table.concat( buf )
    end
else
    --TODO: Need to validate correctness of string
    --TODO: Validate that each character is in shortest-form
    do
        local limits = {
            { lo = 0,              hi = bin"0111_1111", following = 0 },
            { lo = bin"1100_0000", hi = bin"1101_1111", following = 1 },
            { lo = bin"1110_0000", hi = bin"1110_1111", following = 2 },
            { lo = bin"1111_0000", hi = bin"1111_0111", following = 3 }
        }
        local following_sub = bin"1000_0000"
    function UTF8_CpListFromString ( str )
        local cp_list = {}
        
        local start = 1
        while start <= #str do
            local byte1 = str:byte( start )
            local found = false
            local cp = 0
            for _, vals in ipairs( limits ) do
                if vals.lo <= byte1 and byte1 <= vals.hi then
                    found = true
                    cp = byte1 - vals.lo
                    for ofs = 1, vals.following do
                        cp = (cp * 2^6) + (str:byte(start+ofs) - following_sub)
                    end
                    cp_list[ #cp_list + 1 ] = cp
                    start = start + 1 + vals.following
                    break
                end
            end
            if not found then error( string.format( "Malformed UTF-8 sequence: illegal start byte 0x%02X found at offset %i", byte1, start-1 ) ) end
        end
        
        return cp_list
    end end
    
    do
        local lead2, lead3, lead4, follow = bin"1100_0000", bin"1110_0000", bin"1111_0000", bin"1000_0000"
    function UTF8_StringFromCpList ( cp_list )
        local buf = {}
        
        for cp_i, cp in ipairs( cp_list ) do
            local char_seq
            
            if     cp <= 0x007F then
                char_seq = string.char( cp )
            elseif cp <= 0x07FF then
                char_seq = string.char( lead2 + floor(cp / 2^6), follow + (cp % 2^6) )
            elseif cp <= 0xFFFF then
                char_seq = string.char( lead3 + floor(cp / 2^12), follow + (floor(cp/2^6) % 2^6), follow + (cp % 2^6) )
            elseif cp <= 0x10FFFF then
                char_seq = string.char( lead4 + floor(cp / 2^18), follow + (floor(cp/2^12) % 2^6), follow + (floor(cp/2^6) % 2^6), follow + (cp % 2^6) )
            else
                error "Bad CP"
            end
            
            buf[ #buf + 1 ] = char_seq
        end
        
        return table.concat( buf )
    end end
end

function export.UTF8.ToUString ( str )
    return MakeUString( UTF8_CpListFromString( str ) )
end

function export.UTF8.FromUString ( ustr )
    return UTF8_StringFromCpList( CpListFromUString( ustr ) )
end

--[[==============
    UTF-16 SECTION
    ==============]]
local LE2_ReadConverter, BE2_ReadConverter, LE2_WriteConverter, BE2_WriteConverter
if LuaVersion == "Lua53" then
    --[[
    function LE2_ReadConverter ( str )
        assert( #str == 2, "needs 2-byte string" )
        local byte1, byte2 = str:byte(1,2)
        return byte1 + (byte2 << 8)
    end
    function BE2_ReadConverter ( str )
        assert( #str == 2, "needs 2-byte string" )
        local byte1, byte2 = str:byte(1,2)
        return (byte1 << 8) + byte2
    end
    
    function LE2_WriteConverter ( cu )
        return string.char( cu & 0xFF, cu >> 8 )
    end
    function BE2_WriteConverter ( cu )
        return string.char( cu >> 8, cu & 0xFF )
    end
    --]]
    function LE2_ReadConverter ( str )
        assert( #str == 2, "needs 2-byte string" )
        return (string.unpack( "<I2", str ))
    end
    function BE2_ReadConverter ( str )
        assert( #str == 2, "needs 2-byte string" )
        return (string.unpack( ">I2", str ))
    end
    
    function LE2_WriteConverter ( cu )
        return string.pack( "<I2", cu )
    end
    function BE2_WriteConverter ( cu )
        return string.pack( ">I2", cu )
    end
else
    function LE2_ReadConverter ( str )
        assert( #str == 2, "needs 2-byte string" )
        local byte1, byte2 = str:byte(1,2)
        return byte1 + (byte2 * 2^8)
    end
    function BE2_ReadConverter ( str )
        assert( #str == 2, "needs 2-byte string" )
        local byte1, byte2 = str:byte(1,2)
        return (byte1 * 2^8) + byte2
    end

    function LE2_WriteConverter ( cu )
        return string.char( cu % 2^8, floor( cu / 2^8 ) )
    end
    function BE2_WriteConverter ( cu )
        return string.char( floor( cu / 2^8 ), cu % 2^8 )
    end
end

local function UTF16_CpListFromString ( str, converter )
    local cp_list = {}
    
    if #str % 2 ~= 0 then
        error( string.format( "Malformed UTF-16 sequence: byte length %i, not a multiple of 2", #str ) )
    end
    
    local start_idx = 1
    while start_idx <= #str-1 do
        local code1 = converter( str:sub( start_idx, start_idx+1 ) )
        if     0xDC00 <= code1 and code1 <= 0xDFFF then
            --Low surrogate, illegal sequence
            error( string.format( "Malformed UTF-16 sequence: low surrogate found at code unit offset %i (byte offset %i)", (start_idx-1)/2, start_idx-1 ) )
        elseif 0xD800 <= code1 and code1 <= 0xDBFF then
            --High surrogate, start of  a surrogate pair
            if #str < start_idx+2 then
                error "Malformed UTF-16 sequence: final code unit is high surrogate, no code unit follows (needs low surrogate)"
            end
            local code2 = converter( str:sub( start_idx+2, start_idx+3 ) )
            if not ( 0xDC00 <= code2 and code2 <= 0xDFFF ) then
                error( string.format( "UTF-16 sequence: high surrogate at code unit offset %i (byte offset %i) is not followed by a low surrogate", (start_idx-1)/2, start_idx-1 ) )
            end
            cp_list[ #cp_list+1 ] = tointeger( (code1-0xD800)*2^10 + (code2-0xDC00) + 2^16 )
            start_idx = start_idx + 4
        else
            --Non-surrogate, interpret literally
            cp_list[ #cp_list+1 ] = tointeger( code1 )
            start_idx = start_idx + 2
        end
    end
    
    return cp_list
end

local function UTF16_StringFromCpList ( cp_list, converter )
    local buf = {}
    
    for i,cp in ipairs( cp_list ) do
        if 0xD800 <= cp and cp <= 0xDFFF then
            error( string.format( "Illegal code point #%i (U+%04X) in string", i, cp ) )
        elseif cp <= 0x10000 then
            --BMP character, output verbatim
            buf[ i ] = converter( cp )
        else
            --Astral-Planes character, use surrogates
            local ofs_cp = cp - 0x10000
            buf[ i ] = converter( floor(ofs_cp / 2^10) + 0xD800 ) .. converter( (ofs_cp % 2^10) + 0xDC00 )
        end
    end
    
    return table.concat( buf )
end

function export.UTF16LE.ToUString ( str )
    return MakeUString( UTF16_CpListFromString( str, LE2_ReadConverter ) )
end
function export.UTF16BE.ToUString ( str )
    return MakeUString( UTF16_CpListFromString( str, BE2_ReadConverter ) )
end

function export.UTF16LE.FromUString ( ustr )
    return UTF16_StringFromCpList( CpListFromUString( ustr ), LE2_WriteConverter )
end
function export.UTF16BE.FromUString ( ustr )
    return UTF16_StringFromCpList( CpListFromUString( ustr ), BE2_WriteConverter )
end

--[[==============
    UTF-32 SECTION
    ==============]]
local LE4_ReadConverter, BE4_ReadConverter, LE4_WriteConverter, BE4_WriteConverter
if LuaVersion == "Lua53" then
    function LE4_ReadConverter ( str )
        assert( #str == 4, "needs 4-byte string" )
        return (string.unpack( "<I4", str ))
    end
    function BE4_ReadConverter ( str )
        assert( #str == 4, "needs 4-byte string" )
        return (string.unpack( ">I4", str ))
    end

    function LE4_WriteConverter ( cu )
        return string.pack( "<I4", cu )
    end
    function BE4_WriteConverter ( cu )
        return string.pack( ">I4", cu )
    end
else
    function LE4_ReadConverter ( str )
        assert( #str == 4, "needs 4-byte string" )
        local byte1, byte2, byte3, byte4 = str:byte(1,4)
        return byte1 + (byte2 * 2^8) + (byte3 * 2^16) + (byte4 * 2^24)
    end
    function BE4_ReadConverter ( str )
        assert( #str == 4, "needs 4-byte string" )
        local byte1, byte2, byte3, byte4 = str:byte(1,4)
        return (byte1 * 2^24) + (byte2 * 2^16) + (byte3 * 2^8) + byte4
    end

    function LE4_WriteConverter ( cu )
        return string.char( cu % 2^8, floor( cu / 2^8 ) % 2^8, floor( cu / 2^16 ) % 2^8, floor( cu / 2^24 ) % 2^8 )
    end
    function BE4_WriteConverter ( cu )
        return string.char( floor( cu / 2^24 ) % 2^8, floor( cu / 2^16 ) % 2^8, floor( cu / 2^8 ) % 2^8, cu % 2^8 )
    end
end

local function UTF32_CpListFromString ( str, converter )
    if #str % 4 ~= 0 then
        error( string.format( "Malformed UTF-32 sequence: byte length %i, not a multiple of 4", #str ) )
    end
    
    local cp_list = {}
    for cp_idx = 1, #str/4 do
        local start_idx = ((cp_idx-1)*4)+1
        cp_list[ cp_idx ] = converter( str:sub( start_idx, start_idx+3 ) )
    end
    
    return cp_list
end

local function UTF32_StringFromCpList ( cp_list, converter )
    local buf = {}
    
    for i, cp in ipairs( cp_list ) do
        buf[ i ] = converter( cp )
    end
    
    return table.concat( buf )
end

function export.UTF32LE.ToUString ( str )
    return MakeUString( UTF32_CpListFromString( str, LE4_ReadConverter ) )
end
function export.UTF32BE.ToUString ( str )
    return MakeUString( UTF32_CpListFromString( str, BE4_ReadConverter ) )
end

function export.UTF32LE.FromUString ( ustr )
    return UTF32_StringFromCpList( CpListFromUString( ustr ), LE4_WriteConverter )
end
function export.UTF32BE.FromUString ( ustr )
    return UTF32_StringFromCpList( CpListFromUString( ustr ), BE4_WriteConverter )
end

return export
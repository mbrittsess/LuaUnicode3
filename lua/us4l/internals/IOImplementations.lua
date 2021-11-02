--[[TODO: All layers of the read functions should check if lower layers have returned nil to them (signaling EOF) and just return EOF (in an
appropriate manner) from then on instead of calling into lower layers.]]

require "us4l"
local MakeUString = require "us4l.internals.MakeUString"
local LuaVersion = require "us4l.internals.LuaVersion"

local export = {}

local REPLACEMENT_CHARACTER = 0xFFFD
local FIRST_HIGH_SURROGATE, LAST_HIGH_SURROGATE = 0xD800, 0xDBFF
local FIRST_LOW_SURROGATE, LAST_LOW_SURROGATE = 0xDC00, 0xDFFF
local FIRST_SURROGATE, LAST_SURROGATE = FIRST_HIGH_SURROGATE, LAST_LOW_SURROGATE
local LAST_UNICODE_CHARACTER = 0x10FFFF

local GetEmptyUString
do
    local empty_ustr
function GetEmptyUString ( )
    if not empty_ustr then
        empty_ustr = MakeUString{}
    end
    return empty_ustr
end end

local function MakeTrueSet ( list )
    local ret = {}
    for _, key in ipairs( list ) do
        ret[ key ] = true
    end
    return ret
end

--UReadFile functions
do
    local byte = string.byte
--Returned function returns code unit, nil plus false on EOF, or nil plus true on reading partial code unit.
function export.NewGetCodeUnitFromFile ( UFile, file, Encoding )
    --TODO: Needs more implementations for different versions of Lua
    local compose16_function = LuaVersion == [[Lua53]] and require("us4l.internals.Uint16Compose53_temp") or function ( b1, b2 )
        return b1 + ( b2 * 2^8 )
    end
    
    if     Encoding == "UTF8" then
        return function ( )
            local ret = file:read(1)
            if ret ~= nil then
                ret = byte(ret)
            else
                return nil
            end
        end
    elseif Encoding == "UTF16LE" then
        return function ( )
            local s = file:read(2)
            local is_string = s ~= nil
            if is_string and #s == 2 then
                local b1, b2 = byte( s, 1, 2 )
                --return b1 + ( b2 * 2^8 )
                return compose16_function( b1, b2 )
            else
                return nil, is_string
            end
        end
    elseif Encoding == "UTF16BE" then
        return function ( )
            local s = file:read(2)
            local is_string = s ~= nil
            if is_string and #s == 2 then
                local b1, b2 = byte( s, 1, 2 )
                --return ( b2 * 2^8 ) + b1
                return compose16_function( b2, b1 )
            else
                return nil, is_string
            end
        end
    elseif Encoding == "UTF32LE" then
        return function ( )
            local s = file:read(4)
            local is_string = s ~= nil
            if is_string and #s == 4 then
                local b1, b2, b3, b4 = byte( s, 1, 4 )
                return b1 + ( b2 * 2^8 ) + ( b3 * 2^16 ) + ( b4 * 2^24 )
            else
                return nil, is_string
            end
        end
    elseif Encoding == "UTF32BE" then
        return function ( )
            local s = file:read(4)
            local is_string = s ~= nil
            if is_string and #s == 4 then
                local b1, b2, b3, b4 = byte( s, 1, 4 )
                return ( b1 * 2^24 ) + ( b2 * 2^16 ) + ( b3 * 2^8 ) + b4
            else
                return nil, is_string
            end
        end
    end
    
    error "can't happen"
end end

--Returned function returns code unit, nil plus false on EOF, or nil plus true on reading partial code unit.
function export.NewGetCodeUnit ( UFile, GetCodeUnitFromFile )
    local cu_buf = {}
    UFile.cu_buf = cu_buf
    
    local function GetCodeUnit ( )
        local n = #cu_buf
        if n ~= 0 then
            local ret = cu_buf[ n ]
            cu_buf[ n ] = nil
            return ret
        else
            return GetCodeUnitFromFile() --Could return two values
        end
    end
    
    local function UngetCodeUnit ( cu )
        cu_buf[ #cu_buf + 1 ] = cu
    end
    
    return GetCodeUnit, UngetCodeUnit
end

--Returnd function returns a code point, or nil on EOF. Malformed encodings might return U+FFFD REPLACEMENT CHARACTER or throw an exception,
--depending on openread() parameters.
do
    local Utf16DecodeFunction = LuaVersion == [[Lua53]] and require( "us4l.internals.Utf16Decode53_temp" ) or function ( cu1, cu2 )
        return    ( cu1 - FIRST_HIGH_SURROGATE )*2^10
                + ( cu2 - FIRST_LOW_SURROGATE )
                + 0x10000
    end
function export.NewGetCharacterFromFile ( UFile, Encoding, DecodingMethod, GetCodeUnit, UngetCodeUnit )
    --TODO
    
    if     Encoding == "UTF8" then
        error( "not implemented" )
    elseif Encoding == "UTF16LE" or Encoding == "UTF16BE" then
        if DecodingMethod == "normal" then
            return function ( )
                local cu1, partial = GetCodeUnit()
                if cu1 == nil then --EOF or partial code unit
                    if not partial then
                        return nil
                    else
                        error "UTF-16 read error: partial code unit"
                    end
                elseif FIRST_HIGH_SURROGATE <= cu1 and cu1 <= LAST_HIGH_SURROGATE then --Start of a surrogate pair
                    local cu2, partial = GetCodeUnit()
                    if cu2 == nil then --EOF or partial code unit
                        if not partial then
                            error "UTF-16 read error: partial code unit"
                        else
                            error "UTF-16 read error: high (aka leading) surrogate followed by EOF"
                        end
                    elseif FIRST_LOW_SURROGATE <= cu2 and cu2 <= LAST_LOW_SURROGATE then
                        --TODO: Experiment with varied implementations per version of Lua to increase speed
                        return Utf16DecodeFunction( cu1, cu2 )
                    else --High (leading) surrogate not followed by low (trailing) surrogate
                        if FIRST_HIGH_SURROGATE <= cu2 and cu2 <= LAST_HIGH_SURROGATE then
                            error "UTF-16 read error: high (aka leading) surrogate followed by high surrogate"
                        else
                            error "UTF-16 read error: high (aka leadinG) surrogate followed by non-surrogate"
                        end
                    end
                elseif FIRST_LOW_SURROGATE <= cu1 and cu1 <= LAST_LOW_SURROGATE then --Isolated low (trailing) surrogate
                    error "UTF-16 read error: isolated low (aka trailing) surrogate"
                else
                    return cu1
                end
            end
        elseif DecodingMethod == "replace" then
            return function ( )
                local cu1, partial = GetCodeUnit()
                if cu1 == nil then --EOF or partial code unit
                    if not partial then
                        return nil
                    else
                        return REPLACEMENT_CHARACTER
                    end
                elseif FIRST_HIGH_SURROGATE <= cu1 and cu1 <= LAST_HIGH_SURROGATE then --Start of a surrogate pair
                    local cu2, partial = GetCodeUnit()
                    if cu2 == nil then --EOF or partial code unit
                        if partial then --Exactly how this interacts with recommended best practices from section 3.7 of the standard is unclear
                            UngetCodeUnit( REPLACEMENT_CHARACTER )
                        end
                        return REPLACEMENT_CHARACTER
                    elseif FIRST_LOW_SURROGATE <= cu2 and cu2 <= LAST_LOW_SURROGATE then
                        --TODO: Experiment with varied implementations per version of Lua to increase speed
                        return Utf16DecodeFunction( cu1, cu2 )
                    else --High (leading) surrogate not followed by low (trailing) surrogate
                        UngetCodeUnit( cu2 )
                        return REPLACEMENT_CHARACTER
                    end
                elseif FIRST_LOW_SURROGATE <= cu1 and cu1 <= LAST_LOW_SURROGATE then --Isolated low (trailing) surrogate
                    return REPLACEMENT_CHARACTER
                else
                    return cu1
                end
            end
        end
    elseif Encoding == "UTF32LE" or Encoding == "UTF32BE" then
        if DecodingMethod == "normal" then
            return function ( )
                local cu, partial = GetCodeUnit()
                if cu == nil then --EOF or partial code unit
                    if not partial then
                        return nil
                    else
                        error "UTF-32 read error: partial code unit"
                    end
                elseif FIRST_SURROGATE <= cu and cu <= LAST_SURROGATE then --Surrogates encoded in UTF-32
                    error "UTF-32 read error: surrogate character"
                elseif cu <= LAST_UNICODE_CHARACTER then --Normal Unicode character
                    return cu
                else --Outside of Unicode repertoire
                    error "UTF-32 read error: code point not in Unicode repertoire"
                end
            end
        elseif DecodingMethod == "replace" then
            return function ( )
                local cu, partial = GetCodeUnit()
                if cu == nil then --EOF or partial code unit
                    if not partial then
                        return nil
                    else
                        return REPLACEMENT_CHARACTER
                    end
                elseif FIRST_SURROGATE <= cu and cu <= LAST_SURROGATE then --Surrogates encoded in UTF-32
                    return REPLACEMENT_CHARACTER
                elseif cu <= LAST_UNICODE_CHARACTER then --Normal Unicode character
                    return cu
                else --Outside of Unicode repertoire
                    return REPLACEMENT_CHARACTER
                end
            end
        end
    end
    
    error "can't happen"
end end

function export.NewSkipBomHandler ( GetCharacterFromFile )
    --TODO: Give explanation of function to beginner Lua people
    local function ret_func ( )
        local ret_char = GetCharacterFromFile()
        ret_func = function ( ) return GetCharacterFromFile() end
        if ret_char == 0xFEFF then
            return ret_func()
        else
            return ret_char
        end
    end
    return function ( ) return ret_func() end
end

--Returnd function returns a code point, or nil on EOF. Malformed encodings might return U+FFFD REPLACEMENT CHARACTER or throw an exception,
--depending on openread() parameters.
function export.NewGetCharacter ( UFile, GetCharacterFromFile )
    local ch_buf = {}
    UFile.ch_buf = ch_buf
    
    local function GetCharacter ( )
        local n = #ch_buf
        if n ~= 0 then
            local ret = ch_buf[ n ]
            ch_buf[ n ] = nil
            return ret
        else
            return GetCharacterFromFile()
        end
    end
    
    local function UngetCharacter ( ch )
        ch_buf[ #ch_buf + 1 ] = ch
    end
    
    return GetCharacter, UngetCharacter
end

do
    local CR, LF, NEL = 0x000D, 0x000A, 0x0085
--Converts any occurrence of CR+LF, CR, or NEL to LF
function export.NewReadLineNormalizationHandler ( GetCharacter, UngetCharacter )
    return function ( )
        local ch = GetCharacter()
        if ch == CR then
            local ch2 = GetCharacter()
            if ch2 ~= LF then
                UngetCharacter( ch2 )
            end
            return LF
        elseif ch == NEL then
            return LF
        else
            return ch
        end
    end
end end

do
    local CR, LF, NEL, FF, LS, PS = 0x000D, 0x000A, 0x0085, 0x000C, 0x2028, 0x2029
    local IsNewline = MakeTrueSet{ CR, LF, NEL, FF, LS, PS }
function export.NewBaseReadSubfunctions( UFile, GetCharacter, UngetCharacter ) --Must return readall(), readcharacters(n:integer), readline(include_newline:boolean), readnumber()
    --All functions assume that file is not yet closed, although it might be EOF
    --All functions return a boolean (indicating success or failure) and their actual result
    local function readall ( )
        local ret_cp_list = {}
        
        local cp = GetCharacter()
        while cp ~= nil do
            ret_cp_list[ #ret_cp_list+1 ] = cp
            cp = GetCharacter()
        end
        
        return true, MakeUString( ret_cp_list )
    end
    
    local function readcharacters ( n )
        if n == 0 then
            local cp = GetCharacter()
            if cp == nil then
                return false, nil
            else
                UngetCharacter( cp )
                return true, GetEmptyUString()
            end
        else
            local ret_cp_list = {}
            for i = 1, n do
                local cp = GetCharacter()
                if cp ~= nil then
                    ret_cp_list[i] = cp
                else
                    break
                end
            end
            return true, MakeUString( ret_cp_list )
        end
    end
    
    local function readline ( include_newline )
        local ret_cp_list = {}
        local something_read = false
        
        local cp = GetCharacter()
        while cp ~= nil do
            something_read = true
            if IsNewline[cp] then
                break
            else
                ret_cp_list[ #ret_cp_list+1 ] = cp
                cp = GetCharacter()
            end
        end
        
        if cp ~= nil then
            if include_newline then
                local i = #ret_cp_list+1
                ret_cp_list[i] = cp
                if cp == CR then
                    local cp2 = GetCharacter()
                    if cp2 == LF then
                        ret_cp_list[i+1] = cp2
                    elseif cp2 ~= nil then
                        UngetCharacter( cp2 )
                    end
                end
            else
                if cp == CR then
                    local cp2 = GetCharacter()
                    if cp2 ~= nil and cp2 ~= LF then
                        UngetCharacter( cp2 )
                    end
                end
            end
        end
        
        if something_read then
            return true, MakeUString( ret_cp_list )
        else
            return false, nil
        end
    end
    
    local function readnumber ( )
        --TODO
        error "not implemented"
    end
    
    return readall, readcharacters, readline, readnumber
end end

do
    local unpack = table.unpack or unpack
function export.NewBaseReadFunction( UFile, file, readall, readcharacters, readline, readnumber )
    --Arguments will have already been verified, but file might be closed. It's our responsibility to check it.
    return function ( args )
        if UFile.Closed then
            --TODO: Need more unified way of checking for interactions with closed files
            error "attempt to use a closed file"
        end
        
        local results = {}
        
        for i, v in ipairs( args ) do
            local success, result = false, nil
            if type(v) == "number" then
                success, result = readcharacters( v )
            elseif v == "*a" or v == "a" then
                success, result = readall()
            elseif v == "*l" or v == "l" then
                success, result = readline( false )
            elseif v == "*L" or v == "L" then
                success, result = readline( true )
            elseif v == "*n" or v == "n" then
                success, result = readnumber()
            else
                error "can't happen"
            end
            
            if success then
                results[ i ] = result
            else
                break
            end
        end
        
        return unpack( results )
    end
end end

return export
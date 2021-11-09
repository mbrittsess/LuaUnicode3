--Performs non-trivial conversion of code units into code points

local LuaVersion = require "us4l.internals.LuaVersion"

if LuaVersion == [[LuaJIT]] then
    return require "us4l.internals.CodeUnits.DecodeJIT"
elseif LuaVersion == [[Lua53]] then
    return require "us4l.internals.CodeUnits.Decode53"
end

local export = {}

local function bin( s )
    return tonumber( s:gsub("_",""), 2 )
end

--Converts a surrogate pair into a code point
do
    local HIGH_CONSTANT, LOW_CONSTANT = bin"1101_1000_0000_0000", bin"1101_1100_0000_0000"
function export.Utf16SurrogatePair ( cu1, cu2 )
    return ((cu1 - HIGH_CONSTANT)*2^10) + (cu2 - LOW_CONSTANT) + 0x10000
end end

--Used for UTF-8 "normal" decoding
do
    local LEAD2, LEAD3, LEAD4, LEADTRAIL = bin"1100_0000", bin"1110_0000", bin"1111_0000", bin"1000_0000"
    
    function export.Utf8_2 ( cu1, cu2 )
        return ((cu1-LEAD2)*2^6) + (cu2-LEADTRAIL)
    end

    function export.Utf8_3 ( cu1, cu2, cu3 )
        return ((cu1-LEAD3)*2^12) + ((cu2-LEADTRAIL)*2^6) + (cu3-LEADTRAIL)
    end

    function export.Utf8_4 ( cu1, cu2, cu3, cu4 )
        return ((cu1-LEAD4)*2^18) + ((cu2-LEADTRAIL)*2^12) + ((cu3-LEADTRAIL)*2^6) + (cu4-LEADTRAIL)
    end
end

--Used for UTF-8 "replace" decoding
do
    local function make_sub( mask_or_sub )
        return tonumber( mask_or_sub:gsub(".", { ['s'] = '1'; ['0'] = '0'; ['m'] = '0' } ), 2 )
    end
    local trailing_sub = make_sub "s0mmmmmm"
    
    function export.Utf8_NewFunc_Leading ( mask_or_sub, shift_amt, follower_func )
        local sub = make_sub( mask_or_sub )
        local shift_mul = 2^shift_amt
        return function ( GetCodeUnit, UngetCodeUnit, cu1 )
            return follower_func( GetCodeUnit, UngetCodeUnit, (cu1-sub)*shift_mul )
        end
    end
    
    function export.Utf8_NewFunc_NonFinalTrailing ( shift_amt, follower_func, lo_lim, hi_lim )
        local shift_mul = 2^shift_amt
        lo_lim = lo_lim or 0x80
        hi_lim = hi_lim or 0xBF
        return function ( GetCodeUnit, UngetCodeUnit, accum )
            local cu = GetCodeUnit()
            if cu == nil then
                return REPLACEMENT_CHARACTER
            elseif lo_lim <= cu and cu <= hi_lim then
                return follower_func( GetCodeUnit, UngetCodeUnit, accum + ((cu - trailing_sub) * shift_mul) )
            else
                UngetCodeUnit( cu )
                return REPLACEMENT_CHARACTER
            end
        end
    end
    
    function export.Utf8_FinalTrailing ( GetCodeUnit, UngetCodeUnit, accum )
        local cu = GetCodeUnit()
        if cu == nil then
            return REPLACEMENT_CHARACTER
        elseif 0x80 <= cu and cu <= 0xBF then
            return accum + (cu - trailing_sub)
        else
            UngetCodeUnit( cu )
            return REPLACEMENT_CHARACTER
        end
    end
end

return export
local export = {}

local function ones ( n )
    return tonumber( ("1"):rep(n), 2 )
end

--Converts a surrogate pair into a code point
do
    local TEN_1S = ones(10)
function export.Utf16SurrogatePair ( cu1, cu2 )
    return (((cu1 & TEN_1S) << 10) | (cu2 & TEN_1S)) + 0x10000
end end

--Used for UTF-8 "normal" decoding
do
    local THREE_1S, FOUR_1S, FIVE_1S, SIX_1S = ones(3), ones(4), ones(5), ones(6)
    
    function export.Utf8_2 ( cu1, cu2 )
        return ((cu1 & FIVE_1S) << 6) | (cu2 & SIX_1S)
    end
    
    function export.Utf8_3 ( cu1, cu2, cu3 )
        return ((cu1 & FOUR_1S) << 12) | ((cu2 & SIX_1S) << 6) | (cu3 & SIX_1S)
    end
    
    function export.Utf8_4 ( cu1, cu2, cu3, cu4 )
        return ((cu1 & THREE_1S) << 18) | ((cu2 & SIX_1S) << 12) | ((cu3 & SIX_1S) << 6) | (cu4 & SIX_1S)
    end
end

--Used for UTF-8 "replace" decoding
do
    local function make_mask( mask_or_sub )
        return tonumber( mask_or_sub:gsub(".", { ['s'] = '0'; ['0'] = '0'; ['m'] = '1' } ), 2 )
    end
    local trailing_mask = make_mask "s0mmmmmm"
    
    function export.Utf8_NewFunc_Leading ( mask_or_sub, shift_amt, follower_func )
        local mask = make_mask( mask_or_sub )
        return function ( GetCodeUnit, UngetCodeUnit, cu1 )
            return follower_func( GetCodeUnit, UngetCodeUnit, (cu1 & mask) << shift_amt )
        end
    end
    
    function export.Utf8_NewFunc_NonFinalTrailing ( shift_amt, follower_func, lo_lim, hi_lim )
        lo_lim = lo_lim or 0x80
        hi_lim = hi_lim or 0xBF
        return function ( GetCodeUnit, UngetCodeUnit, accum )
            local cu = GetCodeUnit()
            if cu == nil then
                return REPLACEMENT_CHARACTER
            elseif lo_lim <= cu and cu <= hi_lim then
                return follower_func( GetCodeUnit, UngetCodeUnit, accum | ((cu & trailing_mask) << shift_amt) )
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
            return accum | (cu & trailing_mask)
        else
            UngetCodeUnit( cu )
            return REPLACEMENT_CHARACTER
        end
    end
end

return export
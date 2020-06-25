local export = {}

local function GetTableAndAppender ( )
    local ret = {}
    local ret_f = function ( x )
        ret[ #ret+1 ] = x
    end
    return ret, ret_f
end

local nccc = [[numericcanonicalcombiningclass]]
local in_place_sort = require "us4l.internals.InsertionSort" --TODO
local function apply_canonical_ordering ( ch_list )
    local s_idx = 1
    while s_idx < #ch_list do
        if ch_list[s_idx][nccc] ~= 0 then
            local e_idx = s_idx
            while ch_list[e_idx+1] and ch_list[e_idx+1][nccc] ~= 0 do
                e_idx = e_idx+1
            end
            if e_idx ~= s_idx then
                in_place_sort( ch_list, function ( a, b ) return a[nccc] <= b[nccc] end, s_idx, e_idx )
            end
            s_idx = e_idx+1
        else
            s_idx = s_idx + 1
        end
    end
end

--TODO: Could be optimized to not create a new table if unnecessary
local canonical_composition
do
    local MCT, PCT
    local function init ()
        MCT = require "us4l.internals.MasterTable.ActualMasterTable"
        PCT = require "us4l.internals.PrimaryCompositesTable"
        init = function () end
    end
    
    --Returns the precomposed version of the two characters, or nil
    local function check_precompose_pair ( ch_l, ch_c )
        local a = PCT[ ch_c.codepoint ]
        if a then
            local b = a[ ch_l.codepoint ]
            if b then
                return MCT[ b ]
            end
        end
        return nil
    end
    
    --Since it's expected to operate on a string already in canonical order, only immediately-previous character needs to be checked
    --It's assumed there's at least one character between ch_idx and the thing being checked for blocking
    local function is_blocked ( ch_list, ch_idx )
        local ch_c = ch_list[ ch_idx ]
        local ch_b
        for i = ch_idx-1, 1, -1 do
            ch_b = ch_list[i]
            if ch_b ~= nil then
                break
            end
        end
        return ch_b[nccc] == 0 or ch_b[nccc] >= ch_c[nccc]
    end
    
    local MakeUString = require "us4l.internals.MakeUString"
function canonical_composition ( ustr )
    if ustr._isnfc or ustr._isnfkc then
        return ustr
    end
    
    init()
    
    local ch_list = {}
    for i, ch in ipairs( ustr ) do
        ch_list[ i ] = ch
    end
    local ch_list_len = #ch_list
    
    local first_starter_idx = nil
    for idx = 1, ch_list_len do
        if ch_list[ idx ][ nccc ] == 0 then
            first_starter_idx = idx
            break
        end
    end
    if not first_starter_idx then --A string full of combining diacritics.
        return ustr
    end
    
    local prev_starter_idx = first_starter_idx
    local prev_starter_ch = ch_list[ prev_starter_idx ]
    local any_intervening_combiners = false
    for idx = first_starter_idx+1, ch_list_len do
        local ch = ch_list[ idx ]
        if ch[nccc] == 0 then
            if not any_intervening_combiners then
                local new_ch = check_precompose_pair( prev_starter_ch, ch )
                if new_ch then
                    --print( string.format( "CP %04X, new CP %04X, line %i", ch.codepoint, new_ch.codepoint, 101 ) )
                    prev_starter_ch = new_ch
                    ch_list[ prev_starter_idx ] = new_ch
                    ch_list[ idx ] = nil
                else
                    --print( string.format( "CP %04X, line %i", ch.codepoint, 106 ) )
                    prev_starter_ch = ch
                    prev_starter_idx = idx
                end
            else
                --print( string.format( "CP %04X, line %i", ch.codepoint, 111 ) )
                prev_starter_ch = ch
                prev_starter_idx = idx
                any_intervening_combiners = false
            end
        else
            local blocked = any_intervening_combiners and is_blocked( ch_list, idx )
            if not any_intervening_combiners then
                local new_ch = check_precompose_pair( prev_starter_ch, ch )
                if new_ch then
                    --print( string.format( "CP %04X, new CP %04X, line %i", ch.codepoint, new_ch.codepoint, 121 ) )
                    prev_starter_ch = new_ch
                    ch_list[ prev_starter_idx ] = new_ch
                    ch_list[ idx ] = nil
                else
                    --print( string.format( "CP %04X, line %i", ch.codepoint, 126 ) )
                    any_intervening_combiners = true
                end
            else
                if not is_blocked( ch_list, idx ) then
                    local new_ch = check_precompose_pair( prev_starter_ch, ch )
                    if new_ch then
                        --print( string.format( "CP %04X, new CP %04X, line %i", ch.codepoint, new_ch.codepoint, 133 ) )
                        prev_starter_ch = new_ch
                        ch_list[ prev_starter_idx ] = new_ch
                        ch_list[ idx ] = nil
                    else
                        --print( string.format( "CP %04X, line %i", ch.codepoint, 138 ) )
                        --Do nothing
                    end
                else
                    --print( string.format( "CP %04X, line %i", ch.codepoint, 142 ) )
                    --Do nothing
                end
            end
        end
    end
    
    local cp_list, add_cp = GetTableAndAppender()
    for i = 1, ch_list_len do
        local ch = ch_list[ i ]
        if ch ~= nil then
            add_cp( ch.codepoint )
        end
    end
    
    return MakeUString( cp_list )
end end

--TODO: Should be simple to set up optimization to determine if it would actually change in To:NFD() at all, and return itself if it won't.
do
    local MakeUString = require "us4l.internals.MakeUString"
function export.ToNFD ( ustr )
    if ustr._isnfd then
        return ustr
    end
    
    local out_ch_list, add_ch = GetTableAndAppender()
    
    --Perform canonical decomposition
    local function decompose ( ustr )
        for _, ch in ipairs( ustr ) do
            if (not ch.decompositionmapping) or (ch.decompositiontype ~= nil) then --Decomposes to itself
                add_ch( ch )
            else
                decompose( ch.decompositionmapping )
            end
        end
    end
    
    decompose( ustr )
    apply_canonical_ordering( out_ch_list )
    
    --Convert the ch_list into a cp_list
    for i = 1, #out_ch_list do
        out_ch_list[ i ] = out_ch_list[ i ].codepoint
    end
    
    local ret = MakeUString( out_ch_list )
    rawset( ret, "_isnfd", true )
    return ret
end end

--TODO: Should be simple to set up optimization to determine if it would actually change in To:NFKD() at all, and return itself if it won't.
do
    local MakeUString = require "us4l.internals.MakeUString"
function export.ToNFKD ( ustr )
    if ustr._isnfkd then
        return ustr
    end
    
    local out_ch_list, add_ch = GetTableAndAppender()
    
    --Perform compatibility decomposition
    local function decompose ( ustr )
        for _, ch in ipairs( ustr ) do
            if ch.decompositionmapping ~= nil then --Has a compatibility decomposition, or else just a non-trivial canonical decomposition
                decompose( ch.decompositionmapping )
            else
                add_ch( ch )
            end
        end
    end
    
    decompose( ustr )
    apply_canonical_ordering( out_ch_list )
    
    --Convert the ch_list into a cp_list
    for i = 1, #out_ch_list do
        out_ch_list[ i ] = out_ch_list[ i ].codepoint
    end
    
    local ret = MakeUString( out_ch_list )
    rawset( ret, "_isnfkd", true )
    return ret
end end

--TODO: Should be simple to set up optimization to determine if it would actually change in To:NFC() at all, and return itself if it won't.
function export.ToNFC ( ustr )
    if ustr._isnfc then
        return ustr
    end
    
    local ret = canonical_composition( ustr:ToNFD() )
    rawset( ret, "_isnfc", true )
    return ret
end

--TODO: Should be simple to set up optimization to determine if it would actually change in To:NFKC() at all, and return itself if it won't.
function export.ToNFKC ( ustr )
    if ustr._isnfkc then
        return ustr
    end
    
    local ret = canonical_composition( ustr:ToNFKD() )
    rawset( ret, "_isnfkc", true )
    return ret
end

return export
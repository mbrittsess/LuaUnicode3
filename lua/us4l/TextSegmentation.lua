--TODO: Verify all other modules are loaded in correct order

local Normalize = require "us4l.Normalize"
local U = require("us4l").U

local gcb = Normalize.PropertyName( "Grapheme_Cluster_Break" )

local export = {}

--TODO: Needs improvement, this is initial version
do
    local CRLF = U[[\r\n]]
    local function CheckCrLf ( ustr, sidx )
        return ustr[sidx]==CRLF[1] and ustr[sidx+1]==CRLF[2]
    end
    
    local Prepend = Normalize.PropertyValue( gcb, "Prepend" )
    --Returns first index of a non-Prepend character
    local function CheckOptPrepend ( ustr, sidx )
        while ustr[sidx][gcb] == Prepend do
            sidx = sidx + 1
        end
        return sidx
    end
    
    --Returns a boolean indicating if ustr[sidx] is start of an RI-Sequence, and the index of the final character
    local Regional_Indicator = Normalize.PropertyValue( gcb, "Regional_Indicator" )
    local function CheckRI_Seq ( ustr, sidx )
        if ustr[sidx][gcb] == Regional_Indicator then
            local eidx = sidx
            while ustr[eidx+1] and ustr[eidx+1][gcb] == Regional_Indicator do
                eidx = eidx+1
            end
            return true, eidx
        else
            return false
        end
    end
    
    
    --Returns a boolean indicating if ustr[sidx] is the start of a Hangul-Syllable sequence, and the index of the final character
    local L, V, T, LV, LVT = (function( arg ) local ret = {}; for i,v in ipairs(arg) do ret[i] = Normalize.PropertyValue( gcb, v ); end; return (table.unpack or unpack)( ret ); end){ "L", "V", "T", "LV", "LVT" }
    local function CheckHangul_Syllable ( ustr, sidx )
        assert( ustr[sidx] ~= nil, "can't happen" )
        local main_sidx = sidx
        
        --Is it a T+ sequence?
        if ustr[sidx][gcb] == T then
            local eidx = sidx
            while ustr[eidx+1] and ustr[eidx+1][gcb] == T do
                eidx = eidx+1
            end
            return true, eidx
        end
        
        --Look for a prefix of L
        while ustr[main_sidx] and ustr[main_sidx][gcb] == L do
            main_sidx = main_sidx + 1
        end
        
        if ustr[main_sidx] ~= nil then
            --Is it an L* V+ T* sequence?
            if ustr[main_sidx][gcb] == V then
                local main_eidx = main_sidx
                while ustr[main_eidx+1] and ustr[main_eidx+1][gcb] == V do
                    main_eidx = main_eidx + 1
                end
                
                --Does it have a tail sequence?
                if ustr[main_eidx+1] and ustr[main_eidx+1][gcb] == T then
                    local tail_eidx = main_eidx+1
                    while ustr[tail_eidx+1] and ustr[tail_eidx+1][gcb] == T do
                        tail_eidx = tail_eidx + 1
                    end
                    return true, tail_eidx
                else
                    return true, main_eidx
                end
            
            --Is it an L* LV V* T* sequence?
            elseif ustr[main_sidx][gcb] == LV then
                --Check for a tail sequence
                local eidx = main_sidx
                
                while ustr[eidx+1] and ustr[eidx+1][gcb] == V do
                    eidx = eidx+1
                end
                
                while ustr[eidx+1] and ustr[eidx+1][gcb] == T do
                    eidx = eidx+1
                end
                
                return true, eidx
            
            --Is it an L* LVT T* sequence?
            elseif ustr[main_sidx][gcb] == LVT then
                --Check for a tail sequence
                local eidx = main_sidx
                while ustr[eidx+1] and ustr[eidx+1][gcb] == T do
                    eidx = eidx+1
                end
                return true, eidx
            
            --Is it an L+ sequence?
            elseif sidx ~= main_sidx then
                return true, main_sidx-1
            
            else --No leading L-sequence, doesn't match anything else
                return false
            end
        
        else --ustr[main_sidx] == nil --Reaches end of string, but matched an L+ sequence
            return true, main_sidx-1
        end
        
        error "can't happen"
    end
    
    local Extend, SpacingMark = Normalize.PropertyValue( gcb, "Extend" ), Normalize.PropertyValue( gcb, "SpacingMark" )
    local Control, CR, LF = Normalize.PropertyValue( gcb, "Control" ), Normalize.PropertyValue( gcb, "CR" ), Normalize.PropertyValue( gcb, "LF" )
    local function IsControl( gcb_val )
        return gcb_val == Control or gcb_val == CR or gcb_val == LF
    end
--TODO: Needs some basic optimization
function export.GetGraphemeCluster ( ustr, sidx )
    --TODO: Verify inputs
    sidx = sidx or 1
    
    --Is this part of the string valid?
    if not ustr[sidx] then
        return nil
    end
    
    --Is it CRLF?
    if CheckCrLf( ustr, sidx ) then
        return CRLF, sidx+2
    end
    
    --Is it an extended grapheme cluster?
    local body_found, body_end_idx = false, nil
    repeat
        local prep_follow_idx = CheckOptPrepend( ustr, sidx )
        if ustr[prep_follow_idx] == nil then
            break
        end
        
        local IsRI_Seq, RI_Seq_end_idx = CheckRI_Seq( ustr, prep_follow_idx )
        if IsRI_Seq then
            body_found = true
            body_end_idx = RI_Seq_end_idx;
            break
        end
        
        local IsHangul_Syllable, HS_end_idx = CheckHangul_Syllable( ustr, prep_follow_idx )
        if IsHangul_Syllable then
            body_found = true
            body_end_idx = HS_end_idx
            break
        end
        
        if not IsControl(ustr[ prep_follow_idx ][gcb]) then
            body_found = true
            body_end_idx = prep_follow_idx
            break
        end
    until true
    if body_found then
        --Check for tail sequence
        local tail_eidx = body_end_idx
        local tail_p1 = ustr[ tail_eidx+1 ]
        while tail_p1 and ( tail_p1[gcb] == Extend or tail_p1[gcb] == SpacingMark ) do
            tail_eidx = tail_eidx+1
            tail_p1 = ustr[ tail_eidx+1 ]
        end
        
        return ustr:sub( sidx, tail_eidx ), tail_eidx+1
    end
    
    --It's a simple grapheme cluster: one single character
    return ustr:sub(sidx,sidx), sidx+1
end end

function export.GraphemeClusters ( ustr )
    local nidx = 1
    return function ( )
        local ret_str, fidx = export.GetGraphemeCluster( ustr, nidx )
        nidx = fidx
        return ret_str
    end
end

return export
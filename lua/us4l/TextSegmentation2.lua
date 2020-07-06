--TODO: Verify all other modules are loaded in correct order

local Normalize = require "us4l.Normalize"
local U = require("us4l").U

local gcb = Normalize.PropertyName( "Grapheme_Cluster_Break" )

local function MakeTrueSet ( arg )
    local ret = {}
    for _, val in ipairs( arg ) do
        ret[ val ] = true
    end
    return ret
end

local export = {}

--do
    local Control, CR, Extend, L, LF, LV, LVT, Prepend, Regional_Indicator, SpacingMark, T, V =
    (function( arg )
        for i,v in ipairs(arg) do
            arg[i] = Normalize.PropertyValue( gcb, v )
        end
        return (table.unpack or unpack)( arg )
    end){ "Control", "CR", "Extend", "L", "LF", "LV", "LVT", "Prepend", "Regional_Indicator", "SpacingMark", "T", "V" }
    
    local GB45Set = MakeTrueSet{ Control, CR, LF }
    local GB6PostSet = MakeTrueSet{ L, V, LV, LVT }
    local GB7PreSet = MakeTrueSet{ LV, V }
    local GB7PostSet = MakeTrueSet{ V, T }
    local GB8PreSet = MakeTrueSet{ LVT, T }
--Returns the grapheme cluster and the index of the first character after it
function export.GetGraphemeCluster ( ustr, sidx )
    sidx = sidx or 1
    
    if not ustr[sidx] then
        return nil
    end
    
    local eidx = sidx
    while true do
        local break_status = nil
        repeat
            local cur_char, next_char = ustr[eidx], ustr[eidx+1]
            --No application of rule GB1
            
            --Rule GB2
            if next_char == nil then
                break_status = "break"; break
            end
            
            local cur_char_gcb, next_char_gcb = cur_char[ gcb ], next_char[ gcb ]
            
            --Rule GB3
            if cur_char_gcb == CR and next_char_gcb == LF then
                break_status = "continue"; break
            end
            
            --Rule GB4
            if GB45Set[ cur_char_gcb ] then
                break_status = "break"; break
            end
            
            --Rule GB5
            if GB45Set[ next_char_gcb ] then
                break_status = "break"; break
            end
            
            --Rule GB6
            if cur_char_gcb == L and GB6PostSet[ next_char_gcb ] then
                break_status = "continue"; break
            end
            
            --Rule GB7
            if GB7PreSet[ cur_char_gcb ] and GB7PostSet[ next_char_gcb ] then
                break_status = "continue"; break
            end
            
            --Rule GB8
            if GB8PreSet[ cur_char_gcb ] and next_char_gcb == T then
                break_status = "continue"; break
            end
            
            --Rule GB8a
            if cur_char_gcb == Regional_Indicator and next_char_gcb == Regional_Indicator then
                break_status = "continue"; break
            end
            
            --Rule GB9
            if next_char_gcb == Extend then
                break_status = "continue"; break
            end
            
            --Rule GB9a
            if next_char_gcb == SpacingMark then
                break_status = "continue"; break
            end
            
            --Rule GB9b
            if cur_char_gcb == Prepend then
                break_status = "continue"; break
            end
            
            --Rule GB10
            do
                break_status = "break"; break
            end
            
            error "can't happen"
        until true
        assert( break_status ~= nil, "can't happen" )
        
        if break_status == "continue" then
            eidx = eidx+1
        elseif break_status == "break" then
            return ustr:sub( sidx, eidx ), eidx+1
        else
            error "can't happen"
        end
    end
end --end

--Iterator function
function export.GraphemeClusters ( ustr )
    local nidx = 1
    return function ( )
        local ret_str, fidx = export.GetGraphemeCluster( ustr, nidx )
        nidx = fidx
        return ret_str
    end
end

return export
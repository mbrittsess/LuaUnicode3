--TODO: Verify all other modules are loaded in correct order

local Normalize = require "us4l.Normalize"
local U = require("us4l").U

local gcb = Normalize.PropertyName( "Grapheme_Cluster_Break" )
local wb = Normalize.PropertyName( "Word_Break" )

local function MakeTrueSet ( arg )
    local ret = {}
    for _, val in ipairs( arg ) do
        ret[ val ] = true
    end
    return ret
end

local export = {}

do
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
end end

--Iterator function
function export.GraphemeClusters ( ustr )
    local nidx = 1
    return function ( )
        local ret_str, fidx = export.GetGraphemeCluster( ustr, nidx )
        nidx = fidx
        return ret_str
    end
end

--Assumes sidx specifies start of a word, returns word and index of the first character after it
do
    local CR, LF, Newline, Extend, Format, ALetter, Hebrew_Letter, MidLetter, MidNumLet, Single_Quote, Double_Quote,
        Numeric, Katakana, ExtendNumLet, Regional_Indicator, MidNum =
    (function( arg )
        for i,v in ipairs(arg) do
            arg[i] = Normalize.PropertyValue( gcb, v )
        end
        return (table.unpack or unpack)( arg )
    end){ "CR", "LF", "Newline", "Extend", "Format", "ALetter", "Hebrew_Letter", "MidLetter", "MidNumLet", "Single_Quote", "Double_Quote",
        "Numeric", "Katakana", "ExtendNumLet", "Regional_Indicator", "MidNum" }
    
    local WB3abSet = MakeTrueSet{ Newline, CR, LF }
    local WB4Set = MakeTrueSet{ Extend, Format }
    local WB5Set = MakeTrueSet{ ALetter, Hebrew_Letter }
    local WB6_1Set = WB5Set
    local WB6_2Set = MakeTrueSet{ MidLetter, MidNumLet, Single_Quote }
    local WB6_3Set = WB5Set
    local WB9Set = WB5Set
    local WB10Set = WB5Set
    local WB11Set = MakeTrueSet{ MidNum, MidNumLet, Single_Quote }
    local WB13aSet = MakeTrueSet{ ALetter, Hebrew_Letter, Numeric, Katakana, ExtendNumLet }
    local WB13bSet = MakeTrueSet{ ALetter, Hebrew_Letter, Numeric, Katakana }
function export.GetWord ( ustr, sidx )
    local function GetNextChar ( idx ) --Returns index and Word_Break of next character after 'idx' which is non-Ignorable
        local nidx = idx+1
        while true do
            local next_char = ustr[ nidx ]
            if next_char == nil then
                return nil, nil
            else
                local next_wb = next_char[ wb ]
                if not WB4Set[ next_wb ] then
                    return nidx, next_wb
                end
            end
            nidx = nidx+1
        end
    end
    sidx = sidx or 1
    
    if not ustr[sidx] then
        return nil
    end
    
    local cidx = sidx
    local nidx = cidx+1
    
    --Rule WB2
    if not ustr[nidx] then
        return ustr:sub(sidx,sidx), nidx
    end
    
    local cur_wb = ustr[cidx][ wb ]
    local next_wb = ustr[nidx][ wb ]
    
    --Rule WB3
    if cur_wb == CR and next_wb == LF then
        return ustr:sub( cidx, nidx ), nidx+1
    --Rule WB3a
    elseif WB3abSet[ cur_wb ] then
        return ustr:sub( cidx, cidx ), cidx+1
    --Rule WB4
    elseif WB4Set[ cur_wb ] then
        repeat
            cidx = cidx + 1
            local cur_char = ustr[ cidx ]
            if cur_char == nil then return ustr:sub( sidx, cidx-1 ), cidx end
            cur_wb = cur_char[ wb ]
            if WB3abSet[ cur_wb ] then return ustr:sub( sidx, cidx-1 ), cidx end
        until not WB4Set[ cur_wb ]
        --Quick fix, should re-write function better
        return ustr:sub( sidx, cidx-1 ), cidx
    end
    
    --Now sitting on a non-ignorable, non-CR, non-LF, non-Newline character
    while true do
        nidx, next_wb = GetNextChar( cidx )
        
        --Rule WB2 again
        if not nidx then
            return ustr:sub( sidx, -1 ), #ustr+1
        end
        
        --Rule WB3b
        if WB3abSet[ next_wb ] then
            return ustr:sub( sidx, nidx-1 ), nidx
        end
        
        --From here on, every test checks if we keep going, otherwise we return
        repeat
            --Rule WB5
            if WB5Set[ cur_wb ] and WB5Set[ next_wb ] then
                cidx = nidx
                break
            end
            
            --Rule WB6 and WB7
            local nnidx, next_next_wb = GetNextChar( nidx )
            if nnidx ~= nil and WB6_1Set[ cur_wb ] and WB6_2Set[ next_wb ] and WB6_3Set[ next_next_wb ] then
                cidx = nnidx
                break
            end
            
            --Rule WB7a
            if cur_wb == Hebrew_Letter and next_wb == Single_Quote then
                cidx = nidx
                break
            end
            
            --Rule WB7b and WB7c
            if nnidx ~= nil and cur_wb == Hebrew_Letter and next_wb == Double_Quote and next_next_wb == Hebrew_Letter then
                cidx = nnidx
                break
            end
            
            --Rule WB8
            if cur_wb == Numeric and next_wb == Numeric then
                cidx = nidx
                break
            end
            
            --Rule WB9
            if WB9Set[ cur_wb ] and next_wb == Numeric then
                cidx = nidx
                break
            end
            
            --Rule WB10
            if cur_wb == Numeric and WB10Set[ next_wb ] then
                cidx = nidx
                break
            end
            
            --Rule WB11 and WB12
            if nnidx ~= nil and cur_wb == Numeric and WB11Set[ next_wb ] and next_next_wb == Numeric then
                cidx = nnidx
                break
            end
            
            --Rule WB13
            if cur_wb == Katakana and next_wb == Katakana then
                cidx = nidx
                break
            end
            
            --Rule WB13a
            if WB13aSet[ cur_wb ] and next_wb == ExtendNumLet then
                cidx = nidx
                break
            end
            
            --Rule WB13b
            if cur_wb == ExtendNumLet and WB13bSet[ next_wb ] then
                cidx = nidx
                break
            end
            
            --Rule WB13c
            if cur_wb == Regional_Indicator and next_wb == Regional_Indicator then
                cidx = nidx
                break
            end
            
            --Rule WB14
            return ustr:sub( sidx, nidx-1 ), nidx
        until false
        if not ustr[cidx] then
            return ustr:sub( sidx, -1 ), #ustr+1
        else
            cur_wb = ustr[cidx][ wb ]
        end
    end
end end

--Iterator function
function export.Words ( ustr )
    local sidx = 1
    return function ( )
        local ret_str, nidx = export.GetWord( ustr, sidx )
        sidx = nidx
        return ret_str
    end
end

return export
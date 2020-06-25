--TODO: Delete this. The functionality has been moved into us4l.internals.Encodings
--TEMP: This is establishing the basic algorithms, but the module and its API need to be better-defined
--[[This package handles decoding strings which contain malformed encodings, such that the malformed sequences are replaced instead of
    throwing exceptions]]

local MakeUString = require "us4l.internals.MakeUString"

local export = {}

--Makes binary literals
local function B ( str )
    return tonumber( str:gsub("_",""), 2 )
end

--[[IMPORTANT: Table 3-7, "Well-Formed UTF-8 Sequences", was the driving data for this algorithm. It is duplicated here for convenience:
    Code Points          First Byte   Second Byte   Third Byte   Fourth Byte
    ===========          ==========   ===========   ==========   ===========
    U+0000..U+007F     | 00..7F     |             |            |
    U+0080..U+07FF     | C2..DF     | 80..BF      |            |
    U+0800..U+0FFF     | E0         | A0..BF      | 80..BF     |
    U+1000..U+CFFF     | E1..EC     | 80..BF      | 80..BF     |
    U+D000..U+D7FF     | ED         | 80..9F      | 80..BF     |
    U+E000..U+FFFF     | EE..EF     | 80..BF      | 80..BF     |
    U+10000..U+3FFFF   | F0         | 90..BF      | 80..BF     | 80..BF
    U+40000..U+FFFFF   | F1..F3     | 80..BF      | 80..BF     | 80..BF
    U+100000..U+10FFFF | F4         | 80..8F      | 80..BF     | 80..BF
]]
do
    local REPLACEMENT_CHARACTER = 0xFFFD
    
    local two_byte_starter_sub   = B"1100_0000"
    local three_byte_starter_sub = B"1110_0000"
    local four_byte_starter_sub  = B"1111_0000"
    local follower_byte_sub      = B"1000_0000"

--Decodes entire string, returns UString. TODO: Redesign to make this more file-read-friendly?
function export.UTF8 ( str )
    local cp_list, pos = {}, 1
    local function add_advance( cp, advance_length )
        cp_list[ #cp_list + 1 ] = cp
        pos = pos + advance_length
    end
    
    local function process2bytes( b1, b2 )
        if b2 and 0x80 <= b2 and b2 <= 0xBF then
            local cp = (b1-two_byte_start_sub)*2^6 + (b2-follower_byte_sub)
            add_advance( cp, 2 )
        else
            add_advance( REPLACEMENT_CHARACTER, 1 )
        end
    end
    
    local function common3byte3( b1, b2, b3 )
        if b3 and 0x80 <= b3 and b3 <= 0xBF then
            local cp = ((b1-three_byte_starter_sub)*2^12) + ((b2-follower_byte_sub)*2^6) + (b3-follower_byte_sub)
            add_advance( cp, 3 )
        else
            add_advance( REPLACEMENT_CHARACTER, 2 )
        end
    end
    local function process3bytes( b1, b2, b3 )
        if     b1 == 0xE0 then
            if b2 and 0xA0 <= b2 and b2 <= 0xBF then
                common3byte3( b1, b2, b3 )
            else
                add_advance( REPLACEMENT_CHARACTER, 1 )
            end
        elseif    ( 0xE1 <= b1 and b1 <= 0xEC )
               or ( 0xEE <= b1 and b1 <= 0xEF ) then
            if b2 and 0x80 <= b2 and b2 <= 0xBF then
                common3byte3( b1, b2, b3 )
            else
                add_advance( REPLACEMENT_CHARACTER, 1 )
            end
        elseif b1 == 0xED then
            if b2 and 0x80 <= b2 and b2 <= 0x9F then
                common3byte3( b1, b2, b3 )
            else
                add_advance( REPLACEMENT_CHARACTER, 1 )
            end
        else
            error "Can't happen"
        end
    end
    
    local function common4byte34 ( b1, b2, b3, b4 )
        if b3 and 0x80 <= b3 and b3 <= 0xBF then
            if b4 and 0x80 <= b4 and b4 <= 0xBF then
                local cp =   ((b1-four_byte_starter_sub)*2^18)
                           + ((b2-follower_sub)*2^12)
                           + ((b3-follower_sub)*2^6)
                           +  (b4-follower_sub)
                add_advance( cp, 4 )
            else
                add_advance( REPLACEMENT_CHARACTER, 3 )
            end
        else
            add_advance( REPLACEMENT_CHARACTER, 2 )
        end
    end
    local function process4bytes( b1, b2, b3, b4 )
        if b1 == 0xF0 then
            if b2 and 0x90 <= b2 and b2 <= 0xBF then
                common4byte34( b1, b2, b3, b4 )
            else
                add_advance( REPLACEMENT_CHARACTER, 1 )
            end
        elseif 0xF1 <= b1 and b1 <= 0xF3 then
            if b2 and 0x80 <= b2 and b2 <= 0xBF then
                common4byte34( b1, b2, b3, b4 )
            else
                add_advance( REPLACEMENT_CHARACTER, 1 )
            end
        elseif b1 == 0xF4 then
            if b2 and 0x80 <= b2 and b2 <= 0x8F then
                common4byte34( b1, b2, b3, b4 )
            else
                add_advance( REPLACEMENT_CHARACTER, 1 )
            end
        else
            error "Can't happen"
        end
    end
    
    while pos <= #str do
        local b1, b2, b3, b4 = str:byte( pos, pos+3 )
        
        if     0x00 <= b1 and b1 <= 0x7F then
            add_advance( b1, 1 )
        elseif 0xC2 <= b1 and b1 <= 0xDF then
            process2bytes( b1, b2 )
        elseif 0xE0 <= b1 and b1 <= 0xEF then
            process3bytes( b1, b2, b3 )
        elseif 0xF0 <= b1 and b1 <= 0xF4 then
            process4bytes( b1, b2, b3, b4 )
        else --Non-starter
            add_advance( REPLACEMENT_CHARACTER, 1 )
        end
    end
    
    return MakeUString( cp_list )
end end

return export
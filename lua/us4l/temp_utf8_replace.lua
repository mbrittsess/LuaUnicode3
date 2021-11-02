local ActualData = { 0x61, 0xF1, 0x80, 0x80, 0xE1, 0x80, 0xC2, 0x62, 0x80, 0x63, 0x80, 0xBF, 0x64 }
local ActualDataPos = 1
local function GetActualDataByte ( )
    if ActualDataPos > #ActualData then
        return nil
    else
        local b = ActualData[ ActualDataPos ]
        ActualDataPos = ActualDataPos + 1
        return b
    end
end

local ByteBuffer = {}
local function GetByte ( )
    local l = #ByteBuffer
    if l == 0 then
        return GetActualDataByte()
    else
        local b = ByteBuffer[ l ]
        ByteBuffer[ l ] = nil
        return b
    end
end
local function UngetByte ( b )
    ByteBuffer[ #ByteBuffer + 1 ] = b
end

local function b ( s )
    return tonumber(s:gsub("_",""),2)
end

--Decoding Table Generation begin
local Nothing = {}
function NewBaseTable()
    local ret = {}
    for i = 0x00, 0xFF do
        ret[i] = Nothing
    end
    return ret
end

local ActionConstants = {
    { { MaskSub = 0; ShiftMul = 1; } };
    { { MaskSub = b"1100_0000"; ShiftMul = 2^6;  }, { MaskSub = b"1000_0000"; ShiftMul = 1;   } };
    { { MaskSub = b"1110_0000"; ShiftMul = 2^12; }, { MaskSub = b"1000_0000"; ShiftMul = 2^6; }, { MaskSub = b"1000_0000"; ShiftMul = 1;   } };
    { { MaskSub = b"1111_0000"; ShiftMul = 2^18; }, { MaskSub = b"1000_0000"; ShiftMul = 2^12 }, { MaskSub = b"1000_0000"; ShiftMul = 2^6; }, { MaskSub = b"1000_0000"; ShiftMul = 1; } };
}
local Ranges = {
    { { 0x00, 0x7F } };
    { { 0xC2, 0xDF }, { 0x80, 0xBF } };
    { { 0xE0       }, { 0xA0, 0xBF }, { 0x80, 0xBF } };
    { { 0xE1, 0xEC }, { 0x80, 0xBF }, { 0x80, 0xBF } };
    { { 0xED       }, { 0x80, 0x9F }, { 0x80, 0xBF } };
    { { 0xEE, 0xEF }, { 0x80, 0xBF }, { 0x80, 0xBF } };
    { { 0xF0       }, { 0x90, 0xBF }, { 0x80, 0xBF }, { 0x80, 0xBF } };
    { { 0xF1, 0xF3 }, { 0x80, 0xBF }, { 0x80, 0xBF }, { 0x80, 0xBF } };
    { { 0xF4       }, { 0x80, 0x8F }, { 0x80, 0xBF }, { 0x80, 0xBF } };
}
local RootTable = NewBaseTable()
for _, Row in ipairs( Ranges ) do
    local NBytes = #Row
    local PreviousActionTable
    for Byte, Range in ipairs( Row ) do
        local RangeS, RangeE = Range[1], Range[2] or Range[1]
        local MaskSub = ActionConstants[ NBytes ][ Byte ].MaskSub
        local ShiftMul = ActionConstants[ NBytes ][ Byte ].ShiftMul
        local ActionTable = { MaskSub = MaskSub; ShiftMul = ShiftMul; ContinueTable = nil; }
        local ContinueTable = Byte == 1 and RootTable or NewBaseTable()
        for b = RangeS, RangeE do
            ContinueTable[ b ] = ActionTable
        end
        if Byte ~= 1 then
            PreviousActionTable.ContinueTable = ContinueTable
        end
        PreviousActionTable = ActionTable
    end
end
--Decoding Table Generation end

local function ProcessCu ( Accum, Byte, Table, UngetIfInvalid )
    assert( Byte ~= nil )
    
    local Action = Table[ Byte ]
    
    if Action == Nothing then --Invalid for this position
        if UngetIfInvalid then
            UngetByte( Byte )
        end
        return 0xFFFD
    end
    
    local ProcessedByte = (Byte - Action.MaskSub) * Action.ShiftMul
    local NewAccum = Accum + ProcessedByte
    local ContinueTable = Action.ContinueTable
    if ContinueTable == nil then
        return NewAccum
    else
        local NextByte = GetByte()
        if NextByte == nil then --Incomplete sequence
            return 0xFFFD
        else
            return ProcessCu( NewAccum, NextByte, ContinueTable, true )
        end
    end
end

local Byte = GetByte()
while Byte ~= nil do
    print( string.format( "U+%04X", ProcessCu( 0x000000, Byte, RootTable, false ) ) )
    Byte = GetByte()
end
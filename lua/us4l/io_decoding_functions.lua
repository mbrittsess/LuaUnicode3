do
    local ValidStarterByte = {}
    for i = 0x00, 0xFF do ValidStarterByte[i] = true end
    for i = 0x80, 0xC1 do ValidStarterByte[i] = false end
    for i = 0xF5, 0xFF do ValidStarterByte[i] = false end

    local NumFollowingTbl = {}
    for i = 0x00, 0xFF do NumFollowingTbl[i] = 0 end
    for i = tonumber("11000000",2), tonumber("11011111",2) do NumFollowingTbl[i] = 1 end
    for i = tonumber("11100000",2), tonumber("11101111",2) do NumFollowingTbl[i] = 2 end
    for i = tonumber("11110000",2), tonumber("11110111",2) do NumFollowingTbl[i] = 3 end
    
    local DecodeCp = require("us4l.internals.Encodings").UTF8.DecodeCp
function GetCharacterFromFileUTF8Normal ( self )
    assert( #self.Buffer == 0 )
    local File = self.InternalFile
    
    local s1 = File:read(1)
    if s1 == nil then
        self.AtEOF = true
        return nil
    end
    
    local b1 = s1:byte()
    if b1 <= 0x7F then --ASCII subset
        return b1
    elseif not ValidStarterByte[b1] then
        self.AtError = true
        return error( "invalid starter byte" )
    end
    
    local num_following = NumFollowingTbl[b1]
    local s2 = File:read( num_following )
    if #s2 ~= num_following then
        self.AtEOF = true
        self.AtError = true
        return error( "incomplete byte sequence" )
    end
    
    local ret_cp, err_msg = DecodeCp( s1 .. s2 )
    if ret_cp == nil then
        self.AtError = true
        return error( err_msg )
    end
    return ret_cp
end end

do
function GetCharacterFromFileUTF8Replace ( self )
    assert( #self.Buffer == 0 )
    assert( self.ByteBuffer ~= nil )
    
    local ByteBuffer = self.ByteBuffer
    
    local function GetByte ( )
        local i = #ByteBuffer
        if i == 0 then
            local s = self.InternalFile:read(1)
            if s ~= nil then
                return s:byte()
            else
                return nil
            end
        else
            local r = ByteBuffer[i]
            ByteBuffer[i] = nil
            return r
        end
    end
    
    local function UngetByte ( b )
        ByteBuffer[ #ByteBuffer + 1 ] = b
    end
    
    
end end
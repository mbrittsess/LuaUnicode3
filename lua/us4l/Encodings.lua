require "us4l.internals.MasterTable.InitAllChunks"
local MakeUString = require "us4l.internals.MakeUString"
local IntEncodings = require "us4l.internals.Encodings"
local LuaVersion = require "us4l.internals.LuaVersion"
local unpack = table.unpack or unpack
local floor = math.floor

local export = {
    UTF8 = {},
    UTF16LE = {},
    UTF16BE = {},
    UTF32LE = {},
    UTF32BE = {}
}

do
    local DecodeWholeString = IntEncodings.UTF8.DecodeWholeString
function export.UTF8.DecodeString ( str )
    local cp_list, err_msg = DecodeWholeString( str )
    if not cp_list then
        return error( err_msg, 2 )
    else
        return MakeUString( cp_list )
    end
end end

for _, EncName in ipairs{ "UTF8", "UTF16LE", "UTF16BE", "UTF32LE", "UTF32BE" } do
    local DecodeWholeString = IntEncodings[ EncName ].DecodeWholeString
    export[ EncName ].DecodeString = function ( str )
        local cp_list, err_msg = DecodeWholeString( str )
        if not cp_list then
            return error( err_msg, 2 )
        else
            return MakeUString( cp_list )
        end
    end
    
    local DecodeWholeStringWithReplacement = IntEncodings[ EncName ].DecodeWholeStringWithReplacement
    export[ EncName ].DecodeStringWithReplacement ( str )
        return MakeUString( str )
    end
    
    --Will be overwritten later for UTF8 specifically depending on version
    export[ EncName ].SystemDecodeString = export[ EncName ].DecodeString
end

if LuaVersion == "Lua53" then
    local codes = utf8.codes
    export.UTF8.SystemDecodeString = function ( str )
        local cp_list = {}
        for idx, cp in codes( str ) do
            cp_list[ #cp_list+1 ] = cp
        end
        return MakeUString( cp_list )
    end
end

return export
local export = {}

local MasterTable = require "us4l.internals.MasterTable.ActualMasterTable"
local NameLookupTable = require "us4l.internals.CharacterNameLookupTable"

local DeferredStringInits = {}

function export.UCharInit ( char )
    if char.name then
        NameLookupTable[ char.name ] = char
    end
    if char.namealias then
        for alias, category in pairs( char.namealias ) do
            if alias ~= 1 then --Eliminates the exceptional entry which gives the original form of the primary alias
                NameLookupTable[ alias ] = char
            end
        end
    end
    MasterTable[ char.codepoint ] = char
    
    if char[1] then
        DeferredStringInits[ char.codepoint ] = char[1]
        char[1] = nil
    end
end

function export.ProcessDeferredUStrings ( )
    local MakeUString = require "us4l.internals.MakeUString"
    
    for cp, stringtbl in pairs( DeferredStringInits ) do
        local char = MasterTable[ cp ]
        for prop, cp_list in pairs( stringtbl ) do
            char[ prop ] = MakeUString( cp_list )
        end
    end
    
    DeferredStringInits = nil
end

return export
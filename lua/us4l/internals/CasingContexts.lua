local export = {}

local ccc = [[canonicalcombiningclass]]
local nccc = [[numericcanonicalcombiningclass]]

function export.Final_Sigma ( ustr, idx )
    local before_condition = false
    for bidx = idx-1, 1, -1 do
        local C = ustr[ bidx ]
        if C.cased then
            before_condition = true
            break
        elseif not C.caseignorable then
            break
        end
    end
    
    if before_condition then
        for aidx = idx+1, #ustr do
            local C = ustr[ aidx ]
            if C.cased then
                return false
            elseif not C.caseignorable then
                return true
            end
        end
        return true
    else
        return false
    end
end

function export.After_Soft_Dotted ( ustr, idx )
    for bidx = idx-1, 1, -1 do
        local C = ustr[ bidx ]
        if C.softdotted then
            return true
        elseif C[ ccc ] == [[above]] or C[ ccc ] == nil then
            return false
        end
    end
    return false
end

function export.More_Above ( ustr, idx )
    for aidx = idx+1, #ustr do
        local C = ustr[ aidx ]
        if C[ ccc ] == [[above]] then
            return true
        elseif C[ ccc ] == nil then
            return false
        end
    end
    return false
end

do
    local CombiningDotAbove
    local function init ( )
        require "us4l.internals.MasterTable.InitAllChunks"
        CombiningDotAbove = require("us4l.internals.CharacterNameLookupTable")[ "combiningdotabove" ]
        init = function ( ) end
    end
function export.Before_Dot ( ustr, idx )
    init()
    
    for aidx = idx+1, #ustr do
        local C = ustr[ aidx ]
        if C == CombiningDotAbove then
            return true
        elseif C[ ccc ] == [[above]] or C[ ccc ] == nil then
            return false
        end
    end
    return false
end end

do
    local UpperCaseI
    local function init ( )
        require "us4l.internals.MasterTable.InitAllChunks"
        CombiningDotAbove = require("us4l.internals.CharacterNameLookupTable")[ "latincapitali" ]
        init = function ( ) end
    end
function export.After_I ( ustr, idx )
    init()
    
    for bidx = idx-1, 1, -1 do
        local C = ustr[ bidx ]
        if C == UpperCaseI then
            return true
        elseif C[ ccc ] == [[above]] or C[ ccc ] == nil then
            return false
        end
    end
    return false
end end

--Produce the complements of all these functions
for name, func in pairs( export ) do
    export[ "Not_" .. name ] = function ( ... ) return not export[ name ]( ... ) end
end

return export
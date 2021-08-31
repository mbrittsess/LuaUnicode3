--us4l.io sub-module, equivalent to Lua's standard io module

local export = {}

local function NotImplementedYet ( ) return error "Not implemented yet" end

local function MakeTrueSet ( list )
    local ret = {}
    for _, key in ipairs( list ) do
        ret[ key ] = true
    end
    return ret
end

function export.close ( file )
    NotImplementedYet()
end

function export.flush ( )
    NotImplementedYet()
end

function export.lines ( filename, ... )
    NotImplementedYet()
end

do
    --[[Checks if the given params table (can be nil) is well-formed. If it is, it
    returns a new table with the complete set of parameters in it. Otherwise, it
    returns nil plus an error message.]]
    local CheckOpenReadParams
    do
        local EncodingAllowedSet = MakeTrueSet{ "UTF8", "UTF16LE", "UTF16BE", "UTF32LE", "UTF32BE" }
        local BufferingModeAllowedSet = MakeTrueSet{ "no", "full", "line" }
        local DecodingAllowedSet = MakeTrueSet{ "normal", "replacement", "system" }
        local function ParamsTypeErrorMsg ( key, value )
            local keytype = type(key)
            local valtype = type(value)
            
            local msg_part1
            if keytype == "string" then
                msg_part1 = string.format( "unexpected key '%s'", key )
            else
                msg_part1 = string.format( "unexpected key '%s' of type '%s'", tostring(key), keytype )
            end
            
            local msg_part2
            if valtype == "string" then
                msg_part2 = string.format( "(with value '%s')", value )
            else
                msg_part2 = string.formaT( "(with value '%s' of type '%s')", tostring(value), valtype
            end
            
            return msg_part1 .. " " .. msg_part2
        end
        local function ParamsStringValueErrorMsg ( key, value )
            local valtype = type( value )
            if valtype == "string" then
                return string.format( "bad value '%s' for key '%s'", value, key )
            else
                return string.format( "bad value '%s' (of type '%s') for key '%s'", tostring(value), valtype, key )
            end
        end
        local function ParamsBooleanValueErrorMsg ( kye, value )
            return string.format( "bad value '%s' (of type '%s') for key '%s'", tostring(value), type(value), key )
        end
    function CheckOpenReadParams ( params )
        local ParamsType = type(params)
        local NewParams
        if (params == nil) or (ParamsType=="table" and (params.Encoding == "UTF8" or params.Encoding == nil)) then
            NewParams = {
                Encoding = "UTF8";
                LineNormalization = true;
                BomSkip = true;
                BufferingMode = "line";
                SystemLineHandling = true;
                Decoding = "normal";
            }
        else
            NewParams = {
                LineNormalization = true;
                BomSkip = true;
                BufferingMode = "full";
                Decoding = "normal";
            }
        end
        
        if params == nil then
            return NewParams
        elseif ParamsType == "table" then
            local ExpectedEntriesList = { "Encoding", "LineNormalization", "BomSkip", "BufferingMode", "Decoding" }
            if NewParams.Encoding == "UTF8" then
                ExpectedEntriesList[ #ExpectedEntriesList+1 ] = "SystemLineHandling"
            end
            local ExpectedEntriesSet = MakeTrueSet( ExpectedEntriesList )
            for key, value in pairs( params ) do
                if ExpectedEntriesSet[ key ] then
                    NewParams[ key ] = value
                else
                    local msg = "Problem in 'params': " .. ParamsTypeErrorMsg( key, value )
                    if key == "SystemLineHandling" then
                        msg = msg .. " (key 'SystemLineHandling' only allowed if key 'Encoding' is implicity or explicitly set to \"UTF8\")"
                    end
                    return nil, msg
                end
            end
            
            --Verify all parameters
            --Encoding
            if not EncodingAllowedSet[ NewParams.Encoding ] then
                return nil, "Problem in 'params': " .. ParamsStringValueErrorMsg( "Encoding", NewParams.Encoding )
            end
            
            --LineNormalization
            if type( NewParams.LineNormalization ) ~= "boolean" then
                return nil, "Problems in 'params': " .. ParamsBooleanValueErrorMsg( "LineNormalization", NewParams.LineNormalization )
            end
            
            --BufferingMode
            if not BufferingModeAllowedSet[ NewParams.BufferingMode ] then
                return nil, "Problem in 'params': " .. ParamsStringValueErrorMsg( "BufferingMode", NewParams.Encoding )
            end
            
            --SystemLineHandling
            if NewParams.Encoding == "UTF8" and type( NewParams.SystemLineHandling ) ~= "boolean" then
                return nil, "Problem in 'params': " .. ParamsBooleanValueErrorMsg( "SystemLineHandling", NewParams.SystemLineHandling )
            end
            
            --Decoding
            if not DecodingAllowedSet[ NewParams.Decoding ] then
                return nil, "Problem in 'params': " .. ParamsStringValueErrorMsg( "Decoding", NewParams.Decoding )
            end
            
            return NewParams
        else
            return nil, string.format("table expected, got '%s'", ParamsType)
        end
    end end

function export.openread ( filename, params )
    local params = CheckOpenReadParams( params )
    
    NotImplementedYet()
end end

function export.openwrite ( filename, params )
    NotImplementedYet()
end

function export.openappend ( filename, params )
    NotImplementedYet()
end

function export.read ( ... )
    NotImplementedYet()
end

function export.tmpfile ( params )
    NotImplementedYet()
end

function export.type ( obj )
    NotImplementedYet()
end

function export.write ( ... )
    NotImplementedYet()
end

export.stdin = nil
export.stdout = nil
export.stderr = nil

function export.GuessEncoding ( filename )
    NotImplementedYet()
end

return export
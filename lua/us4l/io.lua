--us4l.io sub-module, equivalent to Lua's standard io module

require "us4l"
local MakeUString = require "us4l.internals.MakeUString"
local LuaVersion = require "us4l.internals.LuaVersion"

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
                SystemImplementation = false;
                SkipBom = true;
                BufferingMode = "line";
                LineNormalization = true;
                Decoding = "normal";
            }
            if ParamsType=="table" and params.SystemImplementation == true then
                NewParams.Decoding = "system"
            end
        else
            NewParams = {
                SkipBom = true;
                BufferingMode = "full";
                LineNormalization = true;
                Decoding = "normal";
            }
        end
        
        if params == nil then
            return NewParams
        elseif ParamsType == "table" then
            local ExpectedEntriesList = { "Encoding", "SkipBom", "BufferingMode", "LineNormalization", "Decoding" }
            if NewParams.Encoding == "UTF8" then
                ExpectedEntriesList[ #ExpectedEntriesList+1 ] = "SystemImplementation"
            end
            local ExpectedEntriesSet = MakeTrueSet( ExpectedEntriesList )
            for key, value in pairs( params ) do
                if ExpectedEntriesSet[ key ] then
                    NewParams[ key ] = value
                else
                    local msg = "Problem in 'params': " .. ParamsTypeErrorMsg( key, value )
                    if key == "SystemImplementation" then
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
    
    --NAIVE READ METHODS
    --These work using only :GetCharacter() and :UngetCharacter(), and perform no line normalization.
    local function NaiveReadCharacters ( self, numchars )
        local cp_list = {}
        for i = 1, numchars do
            cp_list[i] = self:GetCharacter()
        end
        return MakeUString( cp_list )
    end
    
    local NewlineSet = MakeTrueSet{
        0x000D, --CR
        0x000A, --LF
        0x2028, --LS
        0x000C, --FF
        0x2029  --PS
    }
    local CR, LF = 0x000D, 0x000A
    local function NaiveReadLine ( self, include_term )
        local cp_list = {}
        local term = {}
        
        local cp = self:GetCharacter()
        while cp and not NewlineSet[cp] do
            cp_list[#cp_list+1] = cp
        end
        
        if cp == CR then
            local cp_next = self:GetCharacter()
            if cp_next == LF then
                term[1] = CR
                term[2] = LF
            elseif cp_next ~= nil then
                self:UngetCharacter( cp_next )
            end
        else
            term[1] = cp
        end
        
        if include_term then
            local ofs = #cp_list
            for i = 1, #term do
                cp_list[ ofs+i ] = term[i]
            end
        end
        
        return MakeUString( cp_list )
    end
    
    local function NaiveReadLineWithTerminator ( self )
        return NaiveReadLine( self, true )
    end
    
    --Probably even our most naive implementations won't use this
    local function NaiveReadAll ( self )
        local cp_list = {}
        
        local cp = self:GetCharacter()
        while cp do
            cp_list[ #cp_list+1 ] = cp
        end
        
        return MakeUString( cp_list )
    end
    --END NAIVE READ METHODS

function export.openread ( filename, params )
    if type(filename) ~= "string" then
        return error( string.format( "problem with argument 'filename': string expected, got '%s'", type(filename) ) )
    end
    
    local object, params_err_msg = CheckOpenReadParams( params )
    if not object then
        return error( "problem with argument 'params': " .. params_err_msg )
    end
    
    --Now to build up the object's fields and methods
    local InternalFile --Will fill this in later
    object.AtBeginning = true
    if object.Encoding == "UTF8" then
        if object.SystemImplementation then
            --TODO
        end
    end
    
    object.InternalFile = InternalFile
    
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
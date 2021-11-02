--us4l.io sub-module, equivalent to Lua's standard io module

require "us4l"
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

local function errorfmt( msgfmt, ... )
    return error( string.format( msgfmt, ... ) )
end

--Raises appropriate error if any parameters are ill-formed
local check_read_parameters
do
    local allowed_formats = MakeTrueSet{ "*a", "a", "*l", "l", "*L", "L", "*n", "n" }
    local inf = 1.0/0.0
    local function is_finite ( n ) --Checks if a parameter (which must be a number) is not an infinite or a NaN
        return n ~= inf and n ~= -inf and n == n
    end
    local is_integer --Checks if a parameter (which must be a finite number) has an integral value
    if LuaVersion == [[Lua53]] then
        local tointeger = math.tointeger
        function is_integer ( n )
            return tointeger(n) ~= nil
        end
    else
        function is_integer ( n )
            return (n % 1.0) == 0.0
        end
    end
    
function check_read_parameters ( args )
    for n, val in ipairs( args ) do
        local t = type( val )
        if t == "number" then
            if not (is_finite(val) and is_integer(val)) then
                error( string.format( "bad argument #%i (number not an integer)", n ) )
            elseif val < 0 then --Additional requirement of this library, as a form of future-proofing (and simplification)
                error( string.format( "bad argument #%i (negative number)", n ) )
            end
        elseif t == "string" then
            if not allowed_formats[val] then
                error( string.format( "bad argument #%i (invalid format)", n ) )
            end
        else
            error( string.format( "bad argument #%i (invalid option)", n ) )
        end
    end
end end

function export.close ( file )
    NotImplementedYet()
end

function export.flush ( )
    NotImplementedYet()
end

--WARNING: In Lua 5.4, io.lines() returns 4 values instead of 1, implement this behavior only in that version
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
        local DecodingMethodAllowedSet = MakeTrueSet{ "normal", "replacement", "system" }
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
                msg_part2 = string.format( "(with value '%s' of type '%s')", tostring(value), valtype )
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
                UseSystemImplementation = false;
                SkipBom = true;
                BufferingMode = "line";
                LineNormalization = true;
                DecodingMethod = "normal";
            }
            if ParamsType=="table" and params.UseSystemImplementation == true then
                NewParams.DecodingMethod = "system"
            end
        else
            NewParams = {
                SkipBom = true;
                BufferingMode = "full";
                LineNormalization = true;
                DecodingMethod = "normal";
            }
        end
        
        if params == nil then
            return NewParams
        elseif ParamsType == "table" then
            local ExpectedEntriesList = { "Encoding", "SkipBom", "BufferingMode", "LineNormalization", "DecodingMethod" }
            if NewParams.Encoding == "UTF8" then
                ExpectedEntriesList[ #ExpectedEntriesList+1 ] = "UseSystemImplementation"
            end
            local ExpectedEntriesSet = MakeTrueSet( ExpectedEntriesList )
            for key, value in pairs( params ) do
                if ExpectedEntriesSet[ key ] then
                    NewParams[ key ] = value
                else
                    local msg = "Problem in 'params': " .. ParamsTypeErrorMsg( key, value )
                    if key == "UseSystemImplementation" then
                        msg = msg .. " (key 'UseSystemImplementation' only allowed if key 'Encoding' is implicity or explicitly set to \"UTF8\")"
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
            if NewParams.Encoding == "UTF8" and type( NewParams.UseSystemImplementation ) ~= "boolean" then
                return nil, "Problem in 'params': " .. ParamsBooleanValueErrorMsg( "UseSystemImplementation", NewParams.SystemLineHandling )
            end
            
            --Decoding
            if not DecodingMethodAllowedSet[ NewParams.DecodingMethod ] then
                return nil, "Problem in 'params': " .. ParamsStringValueErrorMsg( "DecodingMethod", NewParams.DecodingMethod )
            end
            
            return NewParams
        else
            return nil, string.format("table expected, got '%s'", ParamsType)
        end
    end end
    
    local UReadFileMeta = {
        --TODO: must implement __tostring, __gc, __close, and possibly __name, and could vary based on version
    }

function export.openread ( filename, params )
    local impl = require "us4l.internals.IOImplementations"
    
    if type(filename) ~= "string" then
        return error( string.format( "problem with argument 'filename': string expected, got '%s'", type(filename) ) )
    end
    
    local UFile, params_err_msg = CheckOpenReadParams( params )
    local params = UFile --Not sure if we're going to always keep the parameters embedded in the UFile or not, but for now we are
    if not UFile then
        return error( "problem with argument 'params': " .. params_err_msg )
    end
    
    --Now to build up the object's fields and methods
    --Only file:close(), file:lines(), and file:read() are available from the original API
    UFile.AtEOF = false
    UFile.AtError = false
    UFile.Closed = false --TODO: Need to check how this interacts with stuff
    local file, base_read --Will be filled-in later
    if params.UseSystemImplementation then
        --TODO
        error( "not implemented" )
    else
        local errmsg, errno
        file, errmsg, errno = io.open( filename, "rb" )
        --TODO: Check errors
        
        if params.Encoding == "UTF8" then
            file:setvbuf( params.BufferingMode )
        elseif params.BufferingMode == "no" then
            file:setvbuf( "no" )
        else --For UTF-16 and UTF-32, line-buffering isn't supported on reading; just use full-buffering instead.
            file:setvbuf( "full" )
        end
        
        --TODO: What's our behavior when we read a partial code unit? Currently, it's treated like EOF, but I think we need different behavior.
        --TODO: Document answer: "normal" DecodingMethod treats it as an error, "replace" treats it as any other invalid code unit.
        local GetCodeUnit, UngetCodeUnit = impl.NewGetCodeUnitFromFile( UFile, file, params.Encoding )
        if params.DecodingMethod == "replace" then
            GetCodeUnit, UngetCodeUnit = impl.NewGetCodeUnit( UFile, GetCodeUnit )
        end
        local GetCharacterFromFile = impl.NewGetCharacterFromFile( UFile, params.Encoding, params.DecodingMethod, GetCodeUnit, UngetCodeUnit )
        if params.SkipBom then
            GetCharacterFromFile = impl.NewSkipBomHandler( GetCharacterFromFile )
        end
        local GetCharacter, UngetCharacter = impl.NewGetCharacter( UFile, GetCharacterFromFile )
        if params.LineNormalization then
            GetCharacter = impl.NewReadLineNormalizationHandler( GetCharacter, UngetCharacter )
        end
        --Might eliminate this next line and re-do impl.NewBaseReadFunction()
        local readall, readcharacters, readline, readnumber = impl.NewBaseReadSubfunctions( UFile, GetCharacter, UngetCharacter )
        base_read = impl.NewBaseReadFunction( UFile, file, readall, readcharacters, readline, readnumber )
    end
    
    function UFile:close ( )
        --TODO
        error( "not implemented" )
    end
    
    --Note that this follows requirements of later versions of Lua; numbers must be integers. I also require 
    function UFile:read ( ... )
        local args = { ... }
        if #args == 0 then
            args[1] = "*l"
        else
            check_read_parameters( args )
        end
        return base_read( args )
    end
    
    --TODO: Not sure if this functionality is entirely correct, need to verify
    --Particularly, check behavior if file ends in the middle of reading the arguments, does iteration terminate correctly?
    function UFile:lines ( ... )
        local args = { ... }
        if #args == 0 then
            args[1] = "*l"
        else
            check_read_parameters( args )
        end
        return function ( )
            return base_read( args )
        end
    end
    
    --Used for debugging
    UFile.InternalFile = file
    
    --NotImplementedYet()
    
    return setmetatable( UFile, UReadFileMeta )
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
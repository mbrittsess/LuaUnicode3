--TODO: Really not sure exactly what we should be putting in here
require "us4l.internals.MasterTable.InitAllChunks"

local export = {}

local MakeUString = require "us4l.internals.MakeUString"

local Ascii2CpList = require( "us4l.internals.BasicEncodings" ).ASCII.ToCpList
function export.ASCII ( in_str )
    return MakeUString( Ascii2CpList( in_str ) )
end

export.MakeUString = MakeUString --TEMP

--[[    U()
    One of our workhorse functions. Used for creating essentially UString literals.
    Can be called in several ways:
        U( str ) --Takes a string in UTF-8, possibly containing escape sequences. Designed around it always being used with long literals.
        U( cp_list ) --Takes an array of code points
        U( cp, cp, cp, ... ) --Takes a bunch of code points as multiple arguments
]]
do
    local ustring_meta = require "us4l.internals.UStringMetatable"
    local char = string.char
    local CpListFromUtf8 = require( "us4l.internals.Encodings" ).UTF8.DecodeWholeString
    local fmt = string.format
    local NormCharName = require( "us4l.Normalize" ).CharacterName
    local NameLookupTable = require "us4l.internals.CharacterNameLookupTable"
    local NamedSequencesTable = require "us4l.internals.NamedSequencesTable"
    
    local MakeUStringFromLiteral
    do
        local simple_escapes = {
            a = 0x0007; --ALERT, BEL
            b = 0x0008; --BACKSPACE
            f = 0x000C; --FORM FEED
            n = 0x000A; --LINE FEED, NEWLINE
            r = 0x000D; --CARRIAGE RETURN
            t = 0x0009; --CHARACTER TABULATION, HORIZONTAL TABULATION
            v = 0x000B; --LINE TABULATION, VERTICAL TABULATION
            ['\\'] = ('\\'):byte();
        }
    function MakeUStringFromLiteral( str )
        local cp_list = {}
        
        local pos = 1
        while pos <= #str do
            if str:sub(pos,pos) ~= '\\' then --Normal stretch of characters
                local seq_start, seq_end = str:find( "^[^\\]+", pos ) --TODO: Rewrite this logic to use string.find( s, '\\', pos, true )
                local cp_seq, err = CpListFromUtf8( str:sub( seq_start, seq_end ) );
                if not cp_seq then
                    error( string.format( "UTF-8 decoding error at byte %i: %s", pos, err ) )
                end
                local ofs = #cp_list
                for i = 1, #cp_seq do
                    cp_list[ i+ofs ] = cp_seq[ i ]
                end
                pos = seq_end + 1
            else
                if pos == #str then
                    error "un-escaped backslash at end of string"
                end
                
                local esc_type = str:sub( pos+1, pos+1 )
                local simple_escape = simple_escapes[ esc_type ]
                if simple_escape then --Simple Escape
                    cp_list[ #cp_list+1 ] = simple_escape
                    pos = pos + 2
                elseif esc_type == 'z' then --Special Whitespace Escape
                    pos = str:match( [[^\z%s*()]], pos )
                elseif esc_type == 'u' then --Numeric Codepoint Escape
                    local brackets_content = str:match("^{([^}]*)}", pos+2)
                    if not brackets_content then
                        error( fmt( "\\u escape sequence at byte %i not followed by balanced curly brackets", pos ) )
                    elseif brackets_content == "" then
                        error( fmt( "\\u escape sequence at byte %i has nothing inside its curly brackets", pos ) )
                    elseif brackets_content:find( "%X" ) then
                        error( fmt( "\\u escape sequence at byte %i contains non-hexadecimal characters inside curly brackets", pos ) )
                    end
                    local cp = tonumber( brackets_content, 16 )
                    if (not ( 0x0000 <= cp and cp <= 0x10FFFF )) or ( 0xD800 <= cp and cp <= 0xDFFF ) then
                        error( fmt( "\\u escape sequence at byte %i specifies invalid code point (%04X)", pos, cp ) )
                    end
                    cp_list[ #cp_list + 1 ] = cp
                    pos = pos + 4 + #brackets_content
                elseif esc_type == 'N' then --Named Character/Sequence Escape
                    local brackets_content = str:match("^{([^}]*)}", pos+2)
                    if not brackets_content then
                        error( fmt( "\\N escape sequence at byte %i not followed by balanced curly brackets", pos ) )
                    elseif brackets_content == "" then
                        error( fmt( "\\N escape sequence at byte %i has nothing inside its curly brackets", pos ) )
                    elseif not brackets_content:find( "^[%w _%-]+$" ) then
                        error( fmt( "\\N escape sequence at byte %i contains invalid characters (only numbers, letters, spaces, underscores, and hyphens allowed)", pos ) )
                    end
                    local name = NormCharName( brackets_content )
                    local char_by_name = NameLookupTable[ name ]
                    if char_by_name then --Matches a character name or character alias
                        cp_list[ #cp_list + 1 ] = char_by_name.codepoint
                    else
                        local seq_by_name = NamedSequencesTable[ name ]
                        if seq_by_name then --Matches a named sequence
                            local ofs = #cp_list
                            for i = 1, #seq_by_name do
                                cp_list[ i+ofs ] = seq_by_name[ i ].codepoint
                            end
                        else
                            error( fmt( "\\N escape sequence at byte %i contains unrecognized name '%s' (not a recognized character name, character alias, or named sequence)", pos, brackets_content ) )
                        end
                    end
                    pos = pos + 4 + #brackets_content
                else
                    error( fmt( "unrecognized escape sequence '%s' at byte %i", esc_type, pos ) )
                end
            end
        end
        
        return MakeUString( cp_list )
    end end
    
    local function errorf( fmt, ... )
        return error( "Error calling us4l.U(): " .. fmt:format( ... ), 4 )
    end
    local function MakeUStringFromCpList( cp_list )
        for i = 1, #cp_list do
            local cp = cp_list[i]
            if     type(cp) ~= "number" then
                errorf( "character #%i is a '%s', number expected", i, type(cp) )
            elseif cp % 1 ~= 0 then
                errorf( "character #%i is '%f', integer expected", i, cp )
            elseif cp < 0x0000 or 0x10FFFF < cp then
                errorf( "character #%i is '0x%X', not in range 0x0000..0x10FFFF", i, cp )
            end
        end
        return MakeUString( cp_list )
    end
function export.U( ... )
    local n_arg = select( '#', ... )
    if n_arg == 1 then
        local arg = (...)
        local arg_type = type(arg)
        if arg_type == [[string]] then
            return MakeUStringFromLiteral( arg )
        elseif arg_type == [[table]] then
            if getmetatable(arg) == ustring_meta then --Common mistake
                error( "Cannot pass UString as argument to U()" )
            end
            return MakeUStringFromCpList( arg )
        elseif arg_type == [[number]] then
            return MakeUStringFromCpList{ arg }
        else
            error( string.format( "Bad argument of type %s to U()", type(arg) ) )
        end
    else
        return MakeUStringFromCpList{ ... }
    end
end end

return export
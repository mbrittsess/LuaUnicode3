--Aside from us4l.internals.LuaVersion, this file needs to not use any other modules.
local LuaVersion = require "us4l.internals.LuaVersion"

--TODO: Everything in here eventually needs to be highly-optimized

--[[    Every encoding form has the following functions available:
    * DecodeCpAtPos( str[, pos := 1] ) --> cp, len | nil, msg
    * DecodeCpWithReplacementAtPos( str[, pos := 1 ] ) --> cp, len
    * DecodeWholeString( str ) --> cp_list | nil, msg
    * DecodeWholeStringWithReplacement( str ) --> cp_list
    * EncodeCp( cp ) --> string
    * EncodeCpList( cp, skip_check ) --> string
    
        Initially, behavior of the decoding functions was to only throw an error involving incomplete code units if they tried to read
    the final code unit of a string and it was incomplete. But since I couldn't think of any actual use for that, I just changed it to
    require that any string passed to a decoding function must contain only complete code units.
]]

local fmt = string.format

local MaxArgsPassed = 128 --[[Certain functions take a series of distinct arguments instead of a list. There's a limit to how many
    arguments can be passed or values returned at once (somewhere below 2^8 or so), so this number controls how many are used at once.]]

local function IsValidCp ( cp )
    return 0x0000 <= cp and cp <= 0x10FFFF and not ( 0xD800 <= cp and cp <= 0xDFFF )
end

local ReplacementCp = 0xFFFD

--Shortcut for making integers with binary literals
local bin
if LuaVersion == "Lua53" then
    function bin ( in_str )
        return math.tointeger( tonumber( in_str:gsub("_", ""), 2 ) )
    end
else
    function bin ( in_str )
        return tonumber( in_str:gsub("_", ""), 2 )
    end
end

local tointeger
if LuaVersion == "Lua53" then
    tointeger = math.tointeger
else
    tointeger = function ( x ) return x end
end

--[[==============
    UTF-8 HANDLING
    ==============]]
--[[Decoding with replacement is so complex that it's handled the same in all versions of Lua, so the code ins't in either branch of the
if-statement below]]
local UTF8 = {}
if LuaVersion == "Lua53" then
    local codepoint = utf8.codepoint
    local char = utf8.char
    local unpack = table.unpack
    local concat = table.concat
    
    local function EncodeCp ( cp )
        assert( IsValidCp( cp ), fmt( "invalid code point 0x%04X", cp ) )
        return char( cp )
    end
    
    local min = math.min
    local function EncodeCpList ( cp_list, skip_check )
        if not skip_check then
            for i = 1, #cp_list do
                local cp = cp_list[ i ]
                assert( IsValidCp( cp ), fmt( "invalid code point 0x%04X at position %i", i, cp ) )
            end
        end
        
        local out_buf = {}
        for cp_i = 1, #cp_list, MaxArgsPassed do
            out_buf[ #out_buf + 1 ] = char( unpack( cp_list, cp_i, min( cp_i + (MaxArgsPassed-1), #cp_list ) ) )
        end
        
        return concat( out_buf )
    end
    
    local pcall = pcall
    local codepoint = utf8.codepoint
    local max_1byte =         bin"0111_1111"
    local max_2byte = bin"00000111_11111111"
    local max_3byte = bin"11111111_11111111"
    local function DecodeCp ( str, pos )
        pos = pos or 1
        assert( 1 <= pos and pos <= #str, fmt( "invalid byte pos %i in string of length %i", pos, #str ) )
        local success, res = pcall( codepoint, str, pos )
        if not success then
            return nil, res
        end
        
        local cp = success
        if not IsValidCp( cp ) then --Not entirely confident that their library is bulletproof
            return nil, "invalid code point"
        end
        
        if     cp <= max_1byte then
            return cp, 1
        elseif cp <= max_2byte then
            return cp, 2
        elseif cp <= max_3byte then
            return cp, 3
        else
            return cp, 4
        end
    end
    
    local codes = utf8.codes
    local function DecodeWholeString ( str )
        local success, res = pcall(function()
            local cp_list = {}
            for pos, cp in codes( str ) do
                cp_list[ #cp_list + 1 ] = cp
            end
            return cp_list
        end)
        if success then
            return res
        else
            return nil, res
        end
    end
    
    UTF8.DecodeCp = DecodeCp
    UTF8.DecodeWholeString = DecodeWholeString
    UTF8.EncodeCp = EncodeCp
    UTF8.EncodeCpList = EncodeCpList
else
    local char = string.char
    local floor = math.floor
    local concat = table.concat
    local lead2, lead3, lead4, follow = bin"1100_0000", bin"1110_0000", bin"1111_0000", bin"1000_0000"
    local function EncodeCp ( cp )
        assert( IsValidCp( cp ), fmt( "invalid code point 0x%04X", cp ) )
        if     cp <= 0x007F then
            return char( cp )
        elseif cp <= 0x07FF then
            return char( lead2 + floor(cp / 2^6), follow + (cp % 2^6) )
        elseif cp <= 0xFFFF then
            return char( lead3 + floor(cp / 2^12), follow + (floor(cp/2^6) % 2^6), follow + (cp % 2^6) )
        else--if cp <= 0x10FFFF then
            return char( lead4 + floor(cp / 2^18), follow + (floor(cp/2^12) % 2^6), follow + (floor(cp/2^6) % 2^6), follow + (cp % 2^6) )
        end
    end
    
    local function EncodeCpList ( cp_list, skip_check )
        if not skip_check then
            for i = 1, #cp_list do
                local cp = cp_list[ i ]
                assert( IsValidCp( cp ), fmt( "invalid code point 0x%04X at position %i", i, cp ) )
            end
        end
        
        local out_buf = {}
        for i = 1, #cp_list do
            out_buf[ i ] = EncodeCp( cp_list[i] )
        end
        
        return concat( out_buf )
    end
    
    local limits = {
        { lo = 0,              hi = bin"0111_1111", following = 0, min_cp = 0x0000  },
        { lo = bin"1100_0000", hi = bin"1101_1111", following = 1, min_cp = 0x0080  },
        { lo = bin"1110_0000", hi = bin"1110_1111", following = 2, min_cp = 0x0800  },
        { lo = bin"1111_0000", hi = bin"1111_0111", following = 3, min_cp = 0x10000 }
    }
    local following_sub     = bin"1000_0000"
    local following_sub_max = bin"1011_1111"
    
    local function DecodeCp ( str, pos )
        pos = pos or 1
        assert( 1 <= pos and pos <= #str, fmt( "invalid pos %i in string of length %i", pos, #str ) )
        local byte1 = str:byte( pos )
        for _, vals in ipairs( limits ) do
            if vals.lo <= byte1 and byte1 <= vals.hi then
            
                local end_pos = pos + vals.following
                if not ( end_pos <= #str ) then
                    return nil, "incomplete byte sequence"
                end
                
                local cp = byte1 - vals.lo
                for ofs = 1, vals.following do
                    local follow_byte = str:byte(pos+ofs)
                    if not ( following_sub <= follow_byte and follow_byte <= following_sub_max ) then
                        return nil, "malformed byte sequence"
                    end
                    cp = (cp * 2^6) + (follow_byte - following_sub)
                end
                
                if     0xD800 <= cp and cp <= 0xDBFF then
                    return nil, "high surrogate"
                elseif 0xDC00 <= cp and cp <= 0xDFFF then
                    return nil, "low surrogate"
                elseif 0x10FFFF < cp then
                    return nil, "code point above repertoire"
                end
                
                if cp < vals.min_cp then
                    return nil, "code point not in shortest-form"
                end
                
                return cp, vals.following+1
            end
        end
        --Byte does not match any valid starter sequence
        return nil, "malformed byte sequence"
    end
    
    local function DecodeWholeString ( str )
        local pos, cp_list = 1, {}
        
        repeat
            local cp, len = DecodeCp( str, pos )
            
            if not cp then
                --len is the error message
                return nil, fmt( "invalidity at byte %i: %s", pos, len )
            end
            
            cp_list[ #cp_list + 1 ] = cp
            pos = pos + len
        until pos > #str
        
        return cp_list
    end
    
    UTF8.DecodeCp = DecodeCp
    UTF8.DecodeWholeString = DecodeWholeString
    UTF8.EncodeCp = EncodeCp
    UTF8.EncodeCpList = EncodeCpList
end

--Decoding with replacements for UTF-8
do
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
    local two_byte_starter_sub   = bin"1100_0000"
    local three_byte_starter_sub = bin"1110_0000"
    local four_byte_starter_sub  = bin"1111_0000"
    local follower_byte_sub      = bin"1000_0000"
    
    local function process2bytes ( b1, b2 )
        if b2 and 0x80 <= b2 and b2 <= 0xBF then
            local cp = (b1-two_byte_starter_sub)*2^6 + (b2-follower_byte_sub)
            return cp, 2
        else
            return ReplacementCp, 1
        end
    end
    
    local function common3byte3( b1, b2, b3 )
        if b3 and 0x80 <= b3 and b3 <= 0xBF then
            local cp = ((b1-three_byte_starter_sub)*2^12) + ((b2-follower_byte_sub)*2^6) + (b3-follower_byte_sub)
            return cp, 3 
        else
            return ReplacementCp, 2
        end
    end
    
    local function process3bytes ( b1, b2, b3 )
        if     b1 == 0xE0 then
            if b2 and 0xA0 <= b2 and b2 <= 0xBF then
                return common3byte3( b1, b2, b3 )
            else
                return ReplacementCp, 1
            end
        elseif    ( 0xE1 <= b1 and b1 <= 0xEC )
               or ( 0xEE <= b1 and b1 <= 0xEF ) then
            if b2 and 0x80 <= b2 and b2 <= 0xBF then
                return common3byte3( b1, b2, b3 )
            else
                return ReplacementCp, 1
            end
        elseif b1 == 0xED then
            if b2 and 0x80 <= b2 and b2 <= 0x9F then
                return common3byte3( b1, b2, b3 )
            else
                return ReplacementCp, 1
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
                return cp, 4
            else
                return ReplacementCp, 3
            end
        else
            return ReplacementCp, 2
        end
    end
    
    local function process4bytes ( b1, b2, b3, b4 )
        if     b1 == 0xF0 then
            if b2 and 0x90 <= b2 and b2 <= 0xBF then
                return common4byte34( b1, b2, b3, b4 )
            else
                return ReplacementCp, 1
            end
        elseif 0xF1 <= b1 and b1 <= 0xF3 then
            if b2 and 0x80 <= b2 and b2 <= 0xBF then
                return common4byte34( b1, b2, b3, b4 )
            else
                return ReplacementCp, 1
            end
        elseif b1 == 0xF4 then
            if b2 and 0x80 <= b2 and b2 <= 0x8F then
                return common4byte34( b1, b2, b3, b4 )
            else
                return ReplacementCp, 1
            end
        else
            error "Can't happen"
        end
    end
    
    local function DecodeCpWithReplacement ( str, pos )
        pos = pos or 1
        assert( 1 <= pos and pos <= #str, fmt( "invalid pos %i in string of length %i", pos, #str ) )
        
        --If there's not enough characters left in the string, the missing values get nil
        local b1, b2, b3, b4 = str:byte( pos, pos+3 )
        
        if     0x00 <= b1 and b1 <= 0x7F then
            return b1, 1
        elseif 0xC2 <= b1 and b1 <= 0xDF then
            return process2bytes( b1, b2 )
        elseif 0xE0 <= b1 and b1 <= 0xEF then
            return process3bytes( b1, b2, b3 )
        elseif 0xF0 <= b1 and b1 <= 0xF4 then
            return process4bytes( b1, b2, b3, b4 )
        else --Non-starter
            return ReplacementCp, 1
        end
    end
    
    local function DecodeWholeStringWithReplacement ( str )
        local pos, cp_list = 1, {}
        
        repeat
            local cp, len = DecodeCpWithReplacement( str, pos )
            cp_list[ #cp_list + 1 ] = cp
            pos = pos + len
        until pos > #str
        
        return cp_list
    end
    
    UTF8.DecodeCpWithReplacement = DecodeCpWithReplacement
    UTF8.DecodeWholeStringWithReplacement = DecodeWholeStringWithReplacement
end

--[[===============
    UTF-16 HANDLING
    ===============]]
local UTF16LE, UTF16BE = {}, {}
do
    local out_tbls = { UTF16LE = UTF16LE, UTF16BE = UTF16BE }
    
    local specs
    if LuaVersion == "Lua53" then
        local pack, unpack = string.pack, string.unpack
        specs = {
            UTF16LE = {
                write_cu = function ( cu ) return pack( "<I2", cu ) end;
                read_cu  = function ( str, pos ) return unpack( "<I2", str, pos ) end;
            };
            UTF16BE = {
                write_cu = function ( cu ) return pack( ">I2", cu ) end;
                read_cu  = function ( str, pos ) return unpack( ">I2", str, pos ) end;
            };
        }
    else
        local char = string.char
        local floor = math.floor
        specs = {
            UTF16LE = {
                write_cu = function ( cu ) return char( cu % 2^8, floor( cu / 2^8 ) ) end;
                read_cu  = function ( str, pos )
                    local byte1, byte2 = str:byte(pos,pos+1)
                    return byte1 + (byte2 * 2^8)
                end;
            };
            UTF16BE = {
                write_cu = function ( cu ) return char( floor( cu / 2^8 ), cu % 2^8 ) end;
                read_cu  = function ( str, pos )
                    local byte1, byte2 = str:byte(pos,pos+1)
                    return (byte1 * 2^8) + byte2
                end;
            };
        }
    end
    
    for variant, spec in pairs( specs ) do
        local write_cu, read_cu = spec.write_cu, spec.read_cu
        local floor = math.floor
        
        local function EncodeCp ( cp )
            assert( IsValidCp( cp ), fmt( "invalid code point 0x%04X", cp ) )
            if cp <= 0xFFFF then
                return write_cu( cp )
            else
                return write_cu( floor((cp-0x10000)/2^10) + 0xD800 ) .. write_cu( ((cp-0x10000)%2^10) + 0xDC00 )
            end
        end
        
        local concat = table.concat
        local function EncodeCpList ( cp_list, skip_check )
            if not skip_check then
                for i = 1, #cp_list do
                    local cp = cp_list[ i ]
                    assert( IsValidCp( cp ), fmt( "invalid code point 0x%04X at position %i", i, cp ) )
                end
            end
            local out_buf = {}
            for i = 1, #cp_list do
                out_buf[i] = EncodeCp( cp_list[i] )
            end
            return concat( out_buf )
        end
        
        local function DecodeCp ( str, pos )
            pos = pos or 1
            assert( 1 <= pos and pos <= #str, fmt( "invalid byte pos %i in string of length %i", pos, #str ) )
            assert( pos % 2 == 1, fmt( "invalid byte pos %i (must be a multiple of 2 plus 1)", pos ) )
            assert( #str % 2 == 0, fmt( "string length (%i bytes) not a multiple of 2 bytes", #str ) )
            
            local code1 = read_cu( str, pos )
            if     0xDC00 <= code1 and code1 <= 0xDFFF then
                --Low surrogate, illegal sequence
                return nil, "isolated low surrogate"
            elseif 0xD800 <= code1 and code1 <= 0xDBFF then
                --High surrogate, start of a surrogate pair
                if pos == #str-1 then
                    --No following code unit
                    return nil, "high surrogate without following code unit"
                else
                    local code2 = read_cu( str, pos+2 )
                    if not ( 0xDC00 <= code2 and code2 <= 0xDFFF ) then
                        if 0xD800 <= code2 and code2 <= 0xDBFF then
                            return nil, "high surrogate followed by another high surrogate"
                        else
                            return nil, "high surrogate followed by non-surrogate"
                        end
                    else
                        local cp = tointeger( (code1-0xD800)*2^10 + (code2-0xDC00) + 0x10000 )
                        return cp, 4
                    end
                end
            else
                --Non-surrogate, interpret literally
                return code1, 2
            end
        end
        
        local function DecodeCpWithReplacement ( str, pos )
            local cp, len = DecodeCp( str, pos )
            if not cp then
                return ReplacementCp, 2
            else
                return cp, len
            end
        end
        
        local function DecodeWholeString ( str )
            assert( #str % 2 == 0, fmt( "string length (%i bytes) not a multiple of 2 bytes", #str ) )
            local pos, cp_list = 1, {}
            
            repeat
                local cp, len = DecodeCp( str, pos )
                
                if not cp then
                    --len is the error message
                    return nil, fmt( "invalidity at byte %i: %s", pos, len )
                end
                
                cp_list[ #cp_list + 1 ] = cp
                pos = pos + len
            until pos > #str
            
            return cp_list
        end
        
        local function DecodeWholeStringWithReplacement ( str )
            assert( #str % 2 == 0, fmt( "string length (%i bytes) not a multiple of 2 bytes", #str ) )
            local pos, cp_list = 1, {}
            
            repeat
                local cp, len = DecodeCpWithReplacement( str, pos )
                cp_list[ #cp_list + 1 ] = cp
                pos = pos + len
            until pos > #str
            
            return cp_list
        end
        
        local out = out_tbls[ variant ]
        out.DecodeCp = DecodeCp
        out.DecodeCpWithReplacement = DecodeCpWithReplacement
        out.DecodeWholeString = DecodeWholeString
        out.DecodeWholeStringWithReplacement = DecodeWholeStringWithReplacement
        out.EncodeCp = EncodeCp
        out.EncodeCpList = EncodeCpList
    end
end

--[[===============
    UTF-32 HANDLING
    ===============]]
local UTF32LE, UTF32BE = {}, {}
do
    local out_tbls = { UTF32LE = UTF32LE, UTF32BE = UTF32BE }
    local concat = table.concat
    
    local specs
    if LuaVersion == "Lua53" then
        local pack, unpack = string.pack, string.unpack
        specs = {
            UTF32LE = {
                pack   = function ( cu ) return pack( "<I4", cu ) end;
                unpack = function ( str, pos ) return unpack( "<I4", str, pos ) end;
            };
            UTF32BE = {
                pack   = function ( cu ) return pack( ">I4", cu ) end;
                unpack = function ( str, pos ) return unpack( ">I4", str, pos ) end;
            };
        }
    else
        local char = string.char
        local floor = math.floor
        specs = {
            UTF32LE = {
                pack   = function ( cu )
                    return char( cu % 2^8, floor( cu / 2^8 ) % 2^8, floor( cu / 2^16 ) % 2^8, floor( cu / 2^24 ) % 2^8 )
                end;
                unpack = function ( str, pos )
                    local byte1, byte2, byte3, byte4 = str:byte(pos, pos+3)
                    return byte1 + (byte2 * 2^8) + (byte3 * 2^16) + (byte4 * 2^24)
                end;
            };
            UTF32BE = {
                pack   = function ( cu )
                    return char( floor( cu / 2^24 ) % 2^8, floor( cu / 2^16 ) % 2^8, floor( cu / 2^8 ) % 2^8, cu % 2^8 )
                end;
                unpack = function ( str, pos )
                    local byte1, byte2, byte3, byte4 = str:byte(pos, pos+3)
                    return (byte1 * 2^24) + (byte2 * 2^16) + (byte3 * 2^8) + byte4
                end;
            };
        }
    end
    
    for variant, spec in pairs( specs ) do
        local pack = spec.pack
        local s_unpack = spec.unpack
        --out_tbls[ variant ].EncodeCp = function ( cp )
        local function EncodeCp ( cp )
            assert( IsValidCp( cp ), fmt( "invalid code point 0x%04X", cp ) )
            return pack( cp )
        end
        
        --out_tbls[ variant ].EncodeCpList = function ( cp_list, skip_check )
        local function EncodeCpList ( cp_list, skip_check )
            if not skip_check then
                for i = 1, #cp_list do
                    local cp = cp_list[ i ]
                    assert( IsValidCp( cp ), fmt( "invalid code point 0x%04X at position %i", i, cp ) )
                end
            end
            local out_buf = {}
            for i = 1, #cp_list do
                out_buf[i] = pack( cp_list[i] )
            end
            return concat( out_buf )
        end
        
        --out_tbls[ variant ].DecodeCp = function ( str, pos )
        local function DecodeCp ( str, pos )
            pos = pos or 1
            assert( 1 <= pos and pos <= #str, fmt( "invalid byte pos %i in string of length %i", pos, #str ) )
            assert( pos % 4 == 1, fmt( "invalid byte pos %i (must be a multiple of 4 plus 1)", pos ) )
            assert( #str % 4 == 0, fmt( "string length (%i bytes) not a multiple of 4 bytes", #str ) )
            
            local cp = s_unpack( str, pos )
            
            if     0xD800 <= cp and cp <= 0xDBFF then
                return nil, "high surrogate"
            elseif 0xDC00 <= cp and cp <= 0xDFFF then
                return nil, "low surrogate"
            elseif 0x10FFFF < cp then
                return nil, "code point above repertoire"
            end
            
            return cp, 4
        end
        
        --out_tbls[ variant ].DecodeCpWithReplacement = function ( str, pos )
        local function DecodeCpWithReplacement ( str, pos )
            pos = pos or 1
            assert( 1 <= pos and pos <= #str, fmt( "invalid byte pos %i in string of length %i", pos, #str ) )
            assert( pos % 4 == 1, fmt( "invalid byte pos %i (must be a multiple of 4 plus 1)", pos ) )
            assert( #str % 4 == 0, fmt( "string length (%i bytes) not a multiple of 4 bytes", #str ) )
            
            local cp = s_unpack( str, pos )
            
            if IsValidCp( cp ) then
                return cp, 4
            else
                return ReplacementCp, 4
            end
        end
        
        local function DecodeWholeString ( str )
            assert( #str % 4 == 0, fmt( "string length (%i bytes) not a multiple of 4 bytes", #str ) )
            local pos, cp_list = 1, {}
            
            repeat
                local cp, len = DecodeCp( str, pos )
                
                if not cp then
                    --len is the error message
                    return nil, fmt( "invalidity at byte %i: %s", pos, len )
                end
                
                cp_list[ #cp_list + 1 ] = cp
                pos = pos + len
            until pos > #str
            
            return cp_list
        end
        
        local function DecodeWholeStringWithReplacement ( str )
            assert( #str % 4 == 0, fmt( "string length (%i bytes) not a multiple of 4 bytes", #str ) )
            local pos, cp_list = 1, {}
            
            repeat
                local cp, len = DecodeCpWithReplacement( str, pos )
                cp_list[ #cp_list + 1 ] = cp
                pos = pos + len
            until pos > #str
            
            return cp_list
        end
        
        local out = out_tbls[ variant ]
        out.DecodeCp = DecodeCp
        out.DecodeCpWithReplacement = DecodeCpWithReplacement
        out.DecodeWholeString = DecodeWholeString
        out.DecodeWholeStringWithReplacement = DecodeWholeStringWithReplacement
        out.EncodeCp = EncodeCp
        out.EncodeCpList = EncodeCpList
    end
end

local export = {
    UTF8 = UTF8;
    
    UTF16LE = UTF16LE;
    UTF16BE = UTF16BE;
    
    UTF32LE = UTF32LE;
    UTF32BE = UTF32BE;
}

do
    local char = string.char
    local BOM_Signatures = {
        { "UTF8", char( 0xEF, 0xBB, 0xBF ) };
        { "UTF32LE", char( 0x00, 0x00, 0xFE, 0xFF ) };
        { "UTF32BE", char( 0xFF, 0xFE, 0x00, 0x00 ) };
        { "UTF16LE", char( 0xFE, 0xFF ) };
        { "UTF16BE", char( 0xFF, 0xFE ) };
    }
function export.TryIdentifyBom ( str )
    for _, data in ipairs( BOM_Signatures ) do
        local EncodingName, Signature = data[1], data[2]
        if str:sub(1, #Signature) == Signature then
            return EncodingName
        end
    end
    return nil
end end

return export
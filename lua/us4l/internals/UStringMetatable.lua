--[[==========================
    A NOTE REGARDING COERCIONS
    ==========================
        UStrings are meant, as much as possible, to be used in all the same ways as regular Lua strings. However,
    this does not mean that UStrings and regular strings should be able to be mixed arbitrarily. Particularly,
    I'm not implementing a way to do direct comparisons between strings and UStrings.
        I'm also not implementing coercion of UStrings to numbers in arithmetic contexts, as it's such a
    rarely-used feature in the kind of non-trivial code which would be using a comprehensive Unicode library to
    begin with.
]]

local MakeUString = require "us4l.internals.MakeUString"
local Encodings = require "us4l.internals.Encodings"
local Utf8ToCpList = Encodings.UTF8.DecodeWholeString

local umeta = {}
local ustr_methods = {}

local GetEmptyUString
do
    local empty_ustr
function GetEmptyUString ( )
    if not empty_ustr then
        empty_ustr = MakeUString{}
    end
    return empty_ustr
end end

local function isUString ( val )
    return getmetatable( val ) == umeta
end

local function toUString ( val )
    local val_type, val_isustr = type(val), isUString(val)
    assert( val_type == "string" or isUstring, "argument must be string or UString" )
    if val_type == "string" then
        return MakeUString( Utf8ToCpList( val ) )
    else
        return val
    end
end

local function toCpList ( val )
    if getmetatable( val ) == umeta then --UString
        local cp_list = {}
        for i = 1, #val do
            cp_list[i] = val[i].codepoint
        end
        return cp_list
    elseif type(val) == [[string]] then  --string
        local res, err_msg = Utf8ToCpList( val )
        if not res then
            return nil, "error converting from UTF-8: " .. err_msg
        else
            return res
        end
    else                                 --anything else
        return nil, "not a string or UString"
    end
end

--[[===============================
    OPERATORS AND OTHER METAMETHODS
    ===============================]]

--[[    __concat metamethod
    Operands supported:
        * UString .. UString
        * UString .. string
        * string .. UString
]]
function umeta.__concat ( left, right )
    local left_cpl, err_msg = toCpList( left )
    if not left_cpl then
        error( "error with left operand: " .. err_msg )
    end
    
    local right_cpl, err_msg = toCpList( right )
    if not right_cpl then
        error( "error with right operand: " .. err_msg )
    end
    
    local out_cp_list = left_cpl
    local ofs = #out_cp_list
    for i = 1, #right_cpl do
        out_cp_list[ ofs+i ] = right_cpl[i]
    end
    
    return MakeUString( out_cp_list )
end

--[[    __tostring metamethod]]
function umeta.__tostring ( ustr )
    return ustr:ToUtf8()
end

--[[    __lt metamethod
    Implements a simple binary sort. UTF-16 binary sorts and proper Unicode collation are available through library functions.]]
do
    local min = math.min
function umeta.__lt ( left, right )
    assert( getmetatable(left) == umeta, "left operand not a UString" )
    assert( getmetatable(right) == umeta, "right operand not a UString" )
    
    if #left == 0 and #right ~= 0 then
        return true
    elseif #left ~= 0 and #right == 0 then
        return false
    else
        for idx = 1, min( #left, #right ) do
            local lcp, rcp = left[ idx ].codepoint, right[ idx ].codepoint
            if lcp ~= rcp then
                return lcp < rcp
            end
        end
        
        return false
    end
end end

--[[    __index metamethod]]
umeta.__index = ustr_methods

--[[=======
    METHODS
    =======]]
local CachedStringMaxLength = 32 --Any strings <= this length will have their UTF conversions cached in the string itself

--Conversion Methods
local names = { UTF8 = "Utf8", UTF16LE = "Utf16LE", UTF16BE = "Utf16BE", UTF32LE = "Utf32LE", UTF32BE = "Utf32BE" }
for encname, methname in pairs( names ) do
    local ConvFunc = Encodings[ encname ].EncodeCpList
    local cache_key = "_" .. methname:lower()
    ustr_methods[ "To" .. methname ] = function ( self )
        local out = self[ cache_key ]
        if not out then
            local cp_list = toCpList( self )
            out = ConvFunc( cp_list, true )
            if #self <= CachedStringMaxLength then
                rawset( self, cache_key, out )
            end
        end
        return out
    end
end

--Casing Methods
--ToLowercase() and ToUppercase() have completely identical behavior
--TODO: Could use some optimization to determine if they *need* to be converted or can just be returned as-is
do
    local context_functions, MakeUString
    local function init ( )
        context_functions = require "us4l.internals.CasingContexts"
        MakeUString = require "us4l.internals.MakeUString"
        init = function ( ) end
    end
for _, CaseName in ipairs{ "Lowercase", "Uppercase" } do
    init()
    
    local mapping_name = CaseName:lower() .. "mapping"
    local simple_mapping_name = "simple" .. CaseName:lower() .. "mapping"
    local condition_name = CaseName:lower() .. "mappingcondition"
    
    ustr_methods[ "To" .. CaseName ] = function ( self )
        local cp_list = {}
        local function add_cp( cp ) cp_list[ #cp_list+1 ] = cp end
        
        for idx = 1, #self do
            local ch = self[idx]
            
            --Check most common case first
            local full_mapping = ch[ mapping_name ]
            if not full_mapping then
                local simple_mapping = ch[ simple_mapping_name ]
                if simple_mapping then
                    add_cp( simple_mapping[1].codepoint )
                else
                    add_cp( ch.codepoint )
                end
            else
                local condition = ch[ condition_name ]
                if not condition or context_functions[ condition ]( self, idx ) then
                    for i = 1, #full_mapping do
                        add_cp( full_mapping[i].codepoint )
                    end
                else
                    local simple_mapping = ch[ simple_mapping_name ]
                    if simple_mapping then
                        add_cp( simple_mapping[1].codepoint )
                    else
                        add_cp( ch.codepoint )
                    end
                end
            end
        end
        
        return MakeUString( cp_list )
    end
end end

--Normalization Methods
--TODO: Need to implement caching of results
local Norm = require "us4l.internals.Normalization"
ustr_methods.ToNFD = Norm.ToNFD
ustr_methods.ToNFKD = Norm.ToNFKD
ustr_methods.ToNFC = Norm.ToNFC
ustr_methods.ToNFKC = Norm.ToNFKC

--TODO: Needs proper code for constructing code point labels
do
    local fmt = string.format
function ustr_methods:PrettyPrint ( )
    local out_buf = {}
    if #self == 0 then
        return "(empty string)"
    end
    for i = 1, #self do
        local char_i = self[i]
        local cp_printed = fmt( "U+%04X", char_i.codepoint )
        local name = char_i.originalname
        if not name then
            if char_i.namealias then
                name = "(" .. char_i.namealias[1] .. ")"
            else
                name = fmt( "<%s-%04X>", char.generalcategory, char.codepoint )
            end
        end
        out_buf[i] = fmt( "%-8s %s", cp_printed, name )
    end
    return table.concat( out_buf, "\n" )
end end

--Standard Lua string library methods
ustr_methods.lower = ustr_methods.ToLowercase
ustr_methods.upper = ustr_methods.ToUppercase

function ustr_methods:rep( n, sep )
    local n_type, sep_type = type(n), type(sep)
    
    --Check that 'n' is valid
    if n_type ~= "number" then
        error( string.format( "bad argument #1 to 'rep' (number expected, got %s)", n_type ) )
    elseif n % 1 ~= 0 then
        error( "bad argument #1 to 'rep' (not an integer)" )
    end
    
    --Check that 'sep' is nil or valid
    if sep ~= nil and sep_type ~= "string" and not isUString( sep ) then
        error( string.format( "bad argument #2 to 'rep' (string or UString expected, got %s)", sep_type ) )
    end
    
    --If 'n' is less than 1, return empty string
    if n < 1 then
        return GetEmptyUString()
    end
    
    local self_cpl = toCpList( self )
    if sep == nil then
        local ret_cpl = {}
        for i = 0, n-1 do
            local ins = #self_cpl * i
            for j = 1, #self_cpl do
                ret_cpl[ ins + j ] = self_cpl[ j ]
            end
        end
        
        return MakeUString( ret_cpl )
    else
        local ret_cpl = {}
        local sep_cpl = toCpList( sep )
        local use_sep = false
        local ins = 0
        for i = 0, n-1 do
            if use_sep then
                for j = 1, #sep_cpl do
                    ret_cpl[ ins + j ] = sep_cpl[ j ]
                end
                ins = ins + #sep_cpl
            end
            
            for j = 1, #self_cpl do
                ret_cpl[ ins + j ] = self_cpl[ j ]
            end
            ins = ins + #self_cpl
            
            use_sep = true
        end
        
        return MakeUString( ret_cpl )
    end
end

function ustr_methods:reverse ( )
    if #self <= 1 then
        return self
    else
        local ret_cpl = toCpList( self )
        for i = 1, math.floor( #self / 2 ) do
            local j = (#self+1)-i
            ret_cpl[i], ret_cpl[j] = ret_cpl[j], ret_cpl[i]
        end
        return MakeUString( ret_cpl )
    end
end

function ustr_methods:sub ( i, j )
    local type_i, type_j = type(i), type(j)
    if type_i ~= "number" then
        error( string.format( "bad argument #1 to 'sub' (number expected, got %s)", type_i ) )
    elseif type_i == "number" and i % 1 ~= 0 then
        error( "bad argument #1 to 'sub' (not an integer)" )
    end
    
    if j ~= nil and type_j ~= "number" then
        error( string.format( "bad argument #2 to 'sub' (number expected, got %s)", type_j ) )
    elseif type_j == "number" and j %1 ~= 0 then
        error( "bad argument #2 to 'sub' (not an integer)" )
    end
    
    if j == nil then
        j = -1
    end
    
    --Convert and normalize indices
    if i < 0 then
        i = #self + i + 1
    end
    if i < 0 then
        i = 1
    end
    
    if j < 0 then
        j = #self + j + 1
    end
    if j > #self then
        j = #self
    end
    
    if i <= j then
        local ret_cpl = {}
        for idx = i, j do
            ret_cpl[ #ret_cpl + 1 ] = self[ idx ].codepoint
        end
        return MakeUString( ret_cpl )
    else
        return GetEmptyUString()
    end
end

function ustr_methods:byte ( i, j )
    local type_i, type_j = type(i), type(j)
    if i ~= nil and type_i ~= "number" then
        error( string.format( "bad argument #1 to 'byte' (number expected, got %s)", type_i ) )
    elseif type_i == "number" and i % 1 ~= 0 then
        error( "bad argument #1 to 'byte' (not an integer)" )
    end
    
    if i == nil then
        i = 1
    end
    
    if j ~= nil and type_j ~= "number" then
        error( string.format( "bad argument #2 to 'byte' (number expected, got %s)", type_j ) )
    elseif type_j == "number" and j %1 ~= 0 then
        error( "bad argument #2 to 'byte' (not an integer)" )
    end
    
    if j == nil then
        j = -1
    end
    
    --Convert and normalize indices
    if i < 0 then
        i = #self + i + 1
    end
    if i < 0 then
        i = 1
    end
    
    if j < 0 then
        j = #self + j + 1
    end
    if j > #self then
        j = #self
    end
    
    if i < j then
        local ret_cpl = {}
        for idx = i, j do
            ret_cpl[ #ret_cpl + 1 ] = self[ idx ].codepoint
        end
        return table.unpack( ret_cpl )
    else
        return
    end
end

return umeta
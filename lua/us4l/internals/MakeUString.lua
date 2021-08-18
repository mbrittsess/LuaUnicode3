--[[
    Notes:
        Strings of a particular hash are inserted into their matching sub-table in the string memo table with essentially random keys. The
    exact value of the key is basically irrelevant. ]]

local HashPackageNames = {
    Lua51  = "FnvHash51";
    LuaJIT = "FnvHashJIT";
    Lua52  = "FnvHash52";
    Lua53  = "FnvHash53";
}

local LuaVersion = require "us4l.internals.LuaVersion"

local HashFunction = require( "us4l.internals." .. HashPackageNames[ LuaVersion ] )
local HashPrintFormat = ( LuaVersion == "Lua53" ) and "%i" or "0x%08X"
local function HashPrint ( h )
    return HashPrintFormat:format( h )
end

local RootMemoTable = require "us4l.internals.UStringMemoTable"

local SubTableMeta = {
    __mode = "v";
    __tostring = function ( tbl )
        local str_count = 0
        for key, val in pairs( tbl ) do
            if key ~= "hash" then
                str_count = str_count + 1
            end
        end
        return string.format( "UString Memo Table Sub-Table (hash %s, %i %s)", HashPrint( tbl.hash ), str_count, (str_count==1) and "string" or "strings" )
    end;
}

--Delay-load functionality for Master Character Table
local MasterCharacterTable
local function LoadGetTable ( )
    --require "us4l.internals.MasterTable.InitAllChunks"
    MasterCharacterTable = require "us4l.internals.MasterTable.ActualMasterTable"
    return MasterCharacterTable
end
local function GetMasterCharacterTable ( )
    return MasterCharacterTable or LoadGetTable()
end

--Delay-load functionality for UString metatable
local UStringMetatable
local function GetUStringMetatable ( )
    UStringMetatable = require "us4l.internals.UStringMetatable"
    return UStringMetatable
end

local function CpListMatchesUString ( cp_list, ustr )
    if #cp_list == #ustr then
        for i = 1, #cp_list do
            if cp_list[i] ~= ustr[i].codepoint then
                return false
            end
        end
        return true
    else
        return false
    end
end

local function NewUString ( cp_list, sub_tbl )
    local new_str = {}
    local mct = MasterCharacterTable or GetMasterCharacterTable()
    for idx = 1, #cp_list do
        local cp = cp_list[ idx ]
        local char = mct[ cp ]
        --TEMP
        if not char then
            error( string.format( "Error making UString with character #%i with code point U+%04X: no such character", idx, cp ) )
        end
        new_str[ idx ] = char
    end
    new_str._SubTable = sub_tbl
    return setmetatable( new_str, UStringMetatable or GetUStringMetatable() )
end

--MakeUString( cp_list )
return function ( cp_list )
    --TODO: Verify cp_list
    local hash = HashFunction( cp_list )
    local sub_table = RootMemoTable[ hash ]
    
    if not sub_table then
        --No strings with this hash yet, must make table.
        sub_table = setmetatable( { hash = hash }, SubTableMeta )
        local ret = NewUString( cp_list, sub_table )
        sub_table[1] = ret
        RootMemoTable[ hash ] = sub_table
        return ret
    else
        --Hash exists, check if exact string exists
        for key, es in pairs( sub_table ) do
            if key ~= "hash" and CpListMatchesUString( cp_list, es ) then
                return es
            end
        end
        --No match found, make new string.
        local ret = NewUString( cp_list, sub_table )
        sub_table[ #sub_table + 1 ] = ret
        return ret
    end
end
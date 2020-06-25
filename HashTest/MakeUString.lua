local export = {}

local HashFunction = require( hash_function_package )

local hashlist_meta = { __mode = "v" }

local master_hash_table = setmetatable( {}, {
    __mode = "v";
    __index = function ( master_tbl, hash )
        local ret_tbl = setmetatable( { hash = hash }, hashlist_meta )
        master_tbl[ hash ] = ret_tbl
        return ret_tbl
    end;
} )

local MakeUString --Forward declaration
local ustring_meta = {
    __concat = function ( left, right )
        --Just assume they're both UStrings for now
        local new_cp_list = {}
        for i = 1, #left do
            new_cp_list[i] = left[i]
        end
        for i = 1, #right do
            new_cp_list[#left + i] = right[i]
        end
        return MakeUString( new_cp_list )
    end;
    --Still need to implement __tostring, __lt, and __le
}

function MakeUString ( cp_list )
    local hash = HashFunction( cp_list )
    local hashlist = master_hash_table[ hash ]
    
    --Current version: hashlist stores a linear list of strings with the same hash, the list *may* have holes in it.
    local existing = false
    
    for key, value in pairs( hashlist ) do
        if type( value ) == "table" and #value == #cp_list then
            local matched = true
            for i = 1, #value do
                if value[i] ~= cp_list[i] then
                    matched = false
                    break
                end
            end
            if matched then
                existing = value
                break
            end
        end
    end
    
    if existing then
        return existing
    else
        cp_list._hash = hash
        cp_list._hashlist = hashlist
        setmetatable( cp_list, ustring_meta )
        hashlist[ #hashlist + 1 ] = cp_list
        return cp_list
    end
end

export.MakeUString = MakeUString
export.master_hash_table = master_hash_table
return export
local RootTable = setmetatable( {}, {
    __mode = "v";
    __tostring = function ( tbl )
        local num_hashes = 0
        for hash, sub_tbl in pairs( tbl ) do
            num_hashes = num_hashes + 1
        end
        return string.format( "UString Memo Table Root (%i unique hashes)", num_hashes )
    end;
} )

return RootTable
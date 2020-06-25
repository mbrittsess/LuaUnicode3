local floor, char, unpack = math.floor, string.char, ( table.unpack or unpack )

return function ( cp_list )
    local bytes = {}
    for cp_idx = 1, #cp_list do
        local bytes_idx = (cp_idx-1)*3 + 1
        local cp = cp_list[ cp_idx ]
        bytes[ bytes_idx     ] = cp % 2^8
        bytes[ bytes_idx + 1 ] = floor( cp / 2^8  ) % 2^8
        bytes[ bytes_idx + 2 ] = floor( cp / 2^16 ) % 2^8
    end
    return char( unpack( bytes ) )
end
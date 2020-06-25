assert( _VERSION == "Lua 5.2" )

local fnv_prime = 2^24 + 2^8 + 0x93
local offset_basis = 2166136261

local xor = bit32.bxor

return function ( cp_list )
    local hash = offset_basis
    for cp_idx = 1, #cp_list do
        local cp = cp_list[ cp_idx ]
        hash = xor( hash, cp % 2^8 ) * fnv_prime % 2^32
        hash = xor( hash, (cp / 2^8) % 2^8 ) * fnv_prime % 2^32
        hash = xor( hash, (cp / 2^16) % 2^8 ) * fnv_prime % 2^32
    end
    return hash
end
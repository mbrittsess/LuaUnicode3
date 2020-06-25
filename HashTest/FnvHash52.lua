--Approximately implements 32-bit FNV-1a hash
--Main difference is 32-bit * 32-bit multiplication doesn't work exactly the same.

local fnv_prime = 2^24 + 2^8 + 0x93
local offset_basis = 2166136261

local type = type
local xor = bit32.bxor

return function ( cp_list )
    local hash = offset_basis
    
    for i = 1, #cp_list do
        local cp = cp_list[ i ]
        
        --Changed from an assert to remove call to string.format with every CP
        if not ( type(cp) == "number" and cp % 1.0 == 0.0 and 0 <= cp and cp <= 0x10FFFF ) then 
            error( string.format( "value %s at index %i is not a valid code point", tostring(cp), i ) )
        end
        
        hash = xor( hash, cp % 2^8 ) * fnv_prime % 2^32
        hash = xor( hash, (cp / 2^8) % 2^8 ) * fnv_prime % 2^32
        hash = xor( hash, (cp / 2^16) % 2^8 ) * fnv_prime % 2^32
    end
    
    return hash
end
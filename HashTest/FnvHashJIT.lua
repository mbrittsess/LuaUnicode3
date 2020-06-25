--Approximately implements 32-bit FNV-1a hash
--Main difference is 32-bit * 32-bit multiplication doesn't work exactly the same.

local fnv_prime = 2^24 + 2^8 + 0x93
local offset_basis = 2166136261

local type = type
local bxor, band, rshift, tobit = bit.bxor, bit.band, bit.rshift, bit.tobit

return function ( cp_list )
    local hash = offset_basis
    
    for i = 1, #cp_list do
        local cp = cp_list[ i ]
        
        --Changed from an assert to remove call to string.format with every CP
        if not ( type(cp) == "number" and cp % 1.0 == 0.0 and 0 <= cp and cp <= 0x10FFFF ) then 
            error( string.format( "value %s at index %i is not a valid code point", tostring(cp), i ) )
        end
        
        hash = tobit( bxor( hash, band( cp, 0xFF ) ) * fnv_prime )
        hash = tobit( bxor( hash, band( rshift( cp, 8 ), 0xFF ) ) * fnv_prime )
        hash = tobit( bxor( hash, rshift( cp, 16 ) ) * fnv_prime )
    end
    
    return hash
end
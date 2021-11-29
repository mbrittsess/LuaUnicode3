--Approximately implements 32-bit FNV-1a hash
--Main difference is 32-bit * 32-bit multiplication doesn't work exactly the same.

local xor8_tbl = require "us4l.internals.8BitXorTable"

local fnv_prime = 2^24 + 2^8 + 0x93
local offset_basis = 2166136261

local type, floor = type, math.floor

--xors the left number with the right number. It's assumed l is a 32-bit value and r is an 8-bit value
local function xor8 ( l, r )
    local lo8 = l % 2^8
    local hi24 = l - lo8
    return hi24 + xor8_tbl[ lo8 ][ r ]
end

return function ( cp_list )
    local hash = offset_basis
    
    for i = 1, #cp_list do
        local cp = cp_list[i]
        
        --Changed from an assert to remove call to string.format with every CP
        if not ( type(cp) == "number" and cp % 1.0 == 0.0 and 0 <= cp and cp <= 0x10FFFF ) then 
            error( string.format( "value %s (type %s) at index %i is not a valid code point", tostring(cp), type(cp), i ) )
        end
        
        hash = xor8( hash, cp % 2^8 ) * fnv_prime % 2^32
        hash = xor8( hash, floor(cp / 2^8) % 2^8 ) * fnv_prime % 2^32
        hash = xor8( hash, floor(cp / 2^16) % 2^8 ) * fnv_prime % 2^32
    end
    
    return hash
end
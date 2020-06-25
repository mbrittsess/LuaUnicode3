--Implements a 64-bit FNV-1a hash
--TODO: Check if results are correct, Lua 5.3 uses signed 64-bit integers but uses unsigned bitwise operations.

local fnv_prime = math.tointeger(2^40) + math.tointeger(2^8) + 0xB3
local offset_basis = -3750763034362895579 --Signed interpretation of unsigned 64-bit value 14695981039346656037

local inttype = math.type

return function ( cp_list )
    local hash = offset_basis
    
    for i = 1, #cp_list do
        local cp = cp_list[ i ]
        
        --Changed from an assert to remove call to string.format with every CP
        if not ( inttype( cp ) == "integer" and 0 <= cp and cp <= 0x10FFFF ) then
            error( string.format( "value %s (type %s) at index %i is not a valid code point", tostring(cp), type(cp), i ) )
        end
        
        hash = ( hash ~ ( cp & 0xFF ) ) * fnv_prime
        hash = ( hash ~ ( ( cp >> 8 ) & 0xFF ) ) * fnv_prime
        hash = ( hash ~ ( cp >> 16 ) ) * fnv_prime
    end
    
    return hash
end
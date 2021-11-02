--Returns function for creating integer, little-endian
return function ( b1, b2 )
    return b1 | (b2 << 8)
end
local ten1s = tonumber( "1111111111", 2 )

return function ( cu1, cu2 )
    return 0x10000 + ( ((cu1 & ten1s) << 10) | (cu2 & ten1s) )
end
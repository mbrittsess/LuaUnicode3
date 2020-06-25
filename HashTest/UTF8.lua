local export = {}

function export.utf2cplist ( in_str )
    local cp_list = {}
    
    local i = 1
    while i <= #in_str do
        local first_byte = in_str:byte( i )
        local value = first_byte
        local bytes = 0
        
        if     first_byte <= 0x7F then --0b01111111
            bytes = 1
        elseif first_byte <= 0xDF then --0b11011111
            bytes = 2
            value = value - 0xC0
        elseif first_byte <= 0xEF then --0b11101111
            bytes = 3
            value = value - 0xE0
        elseif first_byte <= 0xF7 then --0b11110111
            bytes = 4
            value = value - 0xF0
        else
            error "Malformed first byte"
        end
        
        for j = 1, bytes-1 do
            value = (value * 2^6) + (in_str:byte(i+j) - 2^7)
        end
        
        i = i + bytes
        
        cp_list[ #cp_list + 1 ] = value
    end
    
    return cp_list
end

function export.cplist2utf ( in_list )
    local out_chars = {}
    
    for _, cp in ipairs( in_list ) do
        local bytes = {
            cp % 2^7,
            math.floor( cp / 2^6 ) % 2^6,
            math.floor( cp / 2^12 ) % 2^4,
            math.floor( cp / 2^16 ) % 2^5
        }
        
        local char
        if cp <= 0x7F then
            char = string.char( bytes[1] )
        elseif cp <= 0x07FF then
            char = string.char( bytes[1], bytes[2] )
        elseif cp <= 0xFFFF then
            char = string.char( bytes[1], bytes[2], bytes[3] )
        elseif cp <= 0x10FFFF then
            char = string.char( bytes[1], bytes[2], bytes[3], bytes[4] )
        else
            error "Bad input value"
        end
        
        out_chars[ #out_chars + 1 ] = char
    end
    
    return table.concat( out_chars )
end

if _VERSION == "Lua 5.3" then
    function export.utf2cplist ( in_str )
        local out = {}
        for _, cp in utf8.codes( in_str ) do
            out[ #out+1 ] = cp
        end
        return out
    end
    
    function export.cplist2utf ( in_list )
        return utf8.char( table.unpack( in_list ) )
    end
end

return export
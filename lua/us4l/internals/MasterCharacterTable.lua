--TODO: TEMP IMPLEMENTATION UNTIL WE WORK OUT INITIALIZATION

local MasterTable = setmetatable( {}, {
    __index = function ( tbl, key )
        if not ( type(key) == 'number' and key % 1.0 == 0.0 and 0 <= key and key <= 0x10FFFF ) then
            error( string.format( "Invalid index '%s' into master character table", tostring( key ) ) )
        end
        
        local new_char = { cp = key }
        tbl[ key ] = new_char
        
        return new_char
    end;
} )

return MasterTable
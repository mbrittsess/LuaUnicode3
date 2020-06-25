local allowed_reads = { _PROMPT = true }
local allowed_writes = { GlobalGuard = true, arg = true }

setmetatable( _G, {
    __index = function ( tbl, idx )
        if allowed_reads[ idx ] then
            return nil
        else
            error( string.format( "Attempt to read undefined global variable '%s'", tostring(idx) ) )
        end
    end;
    __newindex = function ( tbl, idx, val )
        if allowed_writes[ idx ] then
            rawset( tbl, idx, val )
        else
            error( string.format( "Attempt to write value '%s' to undefined global variable '%s'", tostring( val ), tostring( idx ) ) )
        end
    end;
} )

return true
if     _VERSION == "Lua 5.1" and not rawget( _G, 'jit' ) then
    return "Lua51"
elseif _VERSION == "Lua 5.1" and rawget( _G, 'jit' ) then
    return "LuaJIT"
elseif _VERSION == "Lua 5.2" then
    return "Lua52"
elseif _VERSION == "Lua 5.3" then
    return "Lua53"
else
    return error "Cannot determine version of Lua or version unsupported"
end
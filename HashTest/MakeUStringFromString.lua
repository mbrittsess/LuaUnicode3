local MakeUString = require("MakeUString").MakeUString
local utf2cplist = require("UTF8").utf2cplist

return function ( in_str )
    return MakeUString( utf2cplist( in_str ) )
end
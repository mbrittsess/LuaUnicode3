local cplist2utf = require("UTF8").cplist2utf

return function ( cp_list )
    return cplist2utf( cp_list ):gsub( "(.).", "%1" )
end
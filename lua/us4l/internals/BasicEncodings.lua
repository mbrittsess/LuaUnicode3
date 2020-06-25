--TODO: Temporary, delete later
local export = {
    ASCII = {};
    UTF8  = {};
    UTF16LE = {};
    UTF16BE = {};
    UTF32LE = {};
    UTF32BE = {};
}

--TEMP
function export.ASCII.ToCpList ( str )
    assert( str:find( "[\127-\255]" ) == nil, "Non-ASCII character in string" )
    
    local ret = {}
    for i= 1, #str do
        ret[i] = str:byte(i)
    end
    
    return ret
end

--TEMP
function export.ASCII.FromCpList ( cp_list )
    local ret = {}
    for i = 1, #cp_list do
        local cp = cp_list[i]
        assert( cp <= 126, "Non-ASCII character in string" )
        ret[ i ] = string.char( cp )
    end
    return table.concat( ret )
end

--TEMP
function export.ASCII.FromUString ( ustr )
    local ret = {}
    for i = 1, #ustr do
        local cp = ustr[i].codepoint
        assert( cp <= 126, "Non-ASCII character in string" )
        ret[i] = string.char( cp )
    end
    return table.concat( ret )
end

function export.UTF8.ToCpList ( str )
end

function export.UTF8.FromCpList ( cp_list )
end

function export.UTF16LE.ToCpList ( str )
end

function export.UTF16LE.FromCpList ( str )
end

function export.UTF16BE.ToCpList ( str )
end

function export.UTF16BE.FromCpList ( str )
end

function export.UTF32LE.ToCpList ( str )
end

function export.UTF32LE.FromCpList ( str )
end

function export.UTF32BE.ToCpList ( str )
end

function export.UTF32BE.FromCpList ( str )
end

return export
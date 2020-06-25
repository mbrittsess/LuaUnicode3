require "us4l.internals.MasterTable.InitAllChunks"
local MakeUString = require "us4l.internals.MakeUString"

str_lines = {}
for line in io.lines [[..\HashTest\jp_words.txt]] do
    str_lines[ #str_lines + 1 ] = line
    if #str_lines == 20 then
        break
    end
end

cplist_lines = {}
for i,line in ipairs( str_lines ) do
    local cp_list = {}
    for _, cp in utf8.codes( line ) do
        cp_list[ #cp_list+1 ] = cp
    end
    cplist_lines[i] = cp_list
end

ustr_lines = {}
for i,cp_list in ipairs( cplist_lines ) do
    ustr_lines[ i ] = MakeUString( cp_list )
end
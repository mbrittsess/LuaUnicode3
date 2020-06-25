--TEMP

local IntMakeUString = require "u4sl.internals.MakeUString"
local MemoTable = require "u4sl.internals.UStringMemoTable"

local function UStringFromAscii ( in_str )
    local cp_list = { in_str:byte( 1, -1 ) }
    return IntMakeUString( cp_list )
end

local words = {}
local word_count = 0

print( string.format( "At start: %s", tostring( MemoTable ) ) )

for word in io.lines( [[..\HashTest\linuxwords.txt]] ) do
    words[ #words + 1 ] = UStringFromAscii( word )
    word_count = word_count + 1
end

print( string.format( "After reading %i words: %s", word_count, tostring( MemoTable ) ) )
words = nil
collectgarbage()
print( string.format( "After deleting references and collecting garbage: %s", tostring( MemoTable ) ) )
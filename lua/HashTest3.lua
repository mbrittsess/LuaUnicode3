--TEMP

local MemoTable = require "us4l.internals.UStringMemoTable"

local ASCII = require("us4l").ASCII

local words = {}
local word_count = 0

print( string.format( "At start: %s", tostring( MemoTable ) ) )

for word in io.lines( [[..\HashTest\linuxwords.txt]] ) do
    words[ #words + 1 ] = ASCII( word )
    word_count = word_count + 1
end

print( string.format( "After reading %i words: %s", word_count, tostring( MemoTable ) ) )
words = nil
collectgarbage()
print( string.format( "After deleting references and collecting garbage: %s", tostring( MemoTable ) ) )
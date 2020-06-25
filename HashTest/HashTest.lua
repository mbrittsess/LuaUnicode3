local hash_function = require( hash_function_package )
local utf2cp = require("UTF8").utf2cplist

collectgarbage()
local start_mem = collectgarbage "count" * 1024.0

local word_table, hash_table = {}, {}

local function process_word( word_str )
    local word_cplist = utf2cp( word_str )
    local word_hash = hash_function( word_cplist )
    if not word_table[ word_str ] then
        word_table[ word_str ] = true
        local word_with_hash_list = hash_table[ word_hash ] or {}
        word_with_hash_list[ #word_with_hash_list + 1 ] = word_str
        hash_table[ word_hash ] = word_with_hash_list
    end
end

for word in io.lines( "linuxwords.txt" ) do
    process_word( word )
end

for line in io.lines( "HuckleberryFinn.txt" ) do
    for word in line:gmatch("%S+") do
        process_word( word )
    end
end

for line in io.lines( "quran-simple.txt" ) do
    for word in line:gmatch("%S+") do
        process_word( word )
    end
end

for line in io.lines( "jp_words.txt" ) do
    process_word( line )
end

local numwords = 0
local mean_hashlist_size = 0
local stddev_hashlist_size = 0
local num_unique_hashes = 0
do  local k = 0
    for hash, hashlist in pairs( hash_table ) do
        numwords = numwords + #hashlist
        k = k + 1
        stddev_hashlist_size = stddev_hashlist_size + ((k-1)/k)*(#hashlist - mean_hashlist_size)^2
        mean_hashlist_size = mean_hashlist_size + ((#hashlist - mean_hashlist_size) / k)
    end
    num_unique_hashes = k
    stddev_hashlist_size = math.sqrt( stddev_hashlist_size / num_unique_hashes )
end

local end_mem = collectgarbage "count" * 1024.0
collectgarbage()
local end_mem_collected = collectgarbage "count" * 1024.0

print( string.format([[
There are %i words,
containing %i unique hashes,
with an average of %f entries per hash,
with a standard deviation of %f,
using %.2fMB of additional memory before garbage collection,
and   %.2fMB of additional memory after]],
    numwords,
    num_unique_hashes,
    mean_hashlist_size,
    stddev_hashlist_size,
    (end_mem - start_mem) / 1024.0^2,
    (end_mem_collected - start_mem) / 1024.0^2
) )

--So we can investigate things afterwards
_G.hash_table = hash_table
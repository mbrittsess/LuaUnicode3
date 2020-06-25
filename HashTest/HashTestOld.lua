hash_function_package = hash_function_package or "SimpleStringHash"

U_List = require("MakeUString").MakeUString
U = require "MakeUStringFromString"

collectgarbage()
local start_mem = collectgarbage "count" * 1024.0

local wordlist = {}

for word in io.lines( "linuxwords.txt" ) do
    wordlist[ #wordlist + 1 ] = U( word )
end

local numwords = #wordlist
local mean_hashlist_size = 0
local stddev_hashlist_size = 0
local num_hashlists = 0
do  local k = 0
    for hash, hashlist in pairs( require("MakeUString").master_hash_table ) do
        k = k + 1
        stddev_hashlist_size = stddev_hashlist_size + ((k-1)/k)*(#hashlist - mean_hashlist_size)^2
        mean_hashlist_size = mean_hashlist_size + ((#hashlist - mean_hashlist_size) / k)
    end
    num_hashlists = k
    stddev_hashlist_size = math.sqrt( stddev_hashlist_size / num_hashlists )
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
and   %.2fMb of additional memory after]],
    numwords,
    num_hashlists,
    mean_hashlist_size,
    stddev_hashlist_size,
    (end_mem - start_mem) / 1024.0^2,
    (end_mem_collected - start_mem) / 1024.0^2
    ) )
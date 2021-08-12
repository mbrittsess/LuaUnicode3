local U = require("us4l").U
local UTF8 = require("us4l.Encodings").UTF8
local TS = require "us4l.TextSegmentation"

local mul_sign, div_sign = U[[\N{MULTIPLICATION SIGN}]]:ToUtf8(), U[[\N{DIVISION_SIGN}]]:ToUtf8()

local line_num = 0
for line in io.lines( [[..\UCD\auxiliary\WordBreakTest.txt]] ) do
    line_num = line_num + 1

    --Discard comment-only lines
    if not(#line == 0 or line:sub(1,1) == "#") then
        repeat
            line = line:sub(3,-1):match("^([^#]+)")
            local line_cps = {}
            for cp_str in line:gmatch("%x+") do
                line_cps[ #line_cps + 1 ] = tonumber( cp_str, 16 )
            end
            local succ, in_line = pcall( U, line_cps )
            if not succ then 
                print( "Failed to create string on line " .. tostring(line_num) )
                break
            end

            local seqs = {}
            local cur_str_cps = {}
            for token in line:gmatch("%S+") do
                if token == mul_sign then
                    --Do nothing
                elseif token == div_sign then
                    seqs[ #seqs+1 ] = U( cur_str_cps )
                    cur_str_cps = {}
                else
                    cur_str_cps[ #cur_str_cps + 1 ] = tonumber( token, 16 )
                end
            end

            local out_seqs = {}
            for gc in TS.Words( in_line ) do
                out_seqs[ #out_seqs+1 ] = gc
            end

            for i = 1, math.max( #seqs, #out_seqs ) do
                if seqs[i] ~= out_seqs[i] then
                    print( ("="):rep(10) )
                    print( string.format( "Failed test from line #%i:", line_num ) )
                    print( "  Input string:" )
                    print( "      " .. in_line:PrettyPrint():gsub( "\n", "\n      " ) )
                    print( "  Expected words:" )
                    for i,str in ipairs( seqs ) do
                        print( string.format( "    Word #%i:", i ) )
                        print( "      " .. str:PrettyPrint():gsub( "\n", "\n      " ) )
                    end
                    print( "  Output words:" )
                    for i,str in ipairs( out_seqs ) do
                        print( string.format( "    Word #%i:", i ) )
                        print( "      " .. str:PrettyPrint():gsub( "\n", "\n      " ) )
                    end
                    print( ("="):rep(10) )
                    print()
                    break
                end
            end
        until true
    end
end

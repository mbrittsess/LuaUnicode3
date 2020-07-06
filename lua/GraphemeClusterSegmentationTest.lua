U = require("us4l").U
UTF8 = require("us4l.Encodings").UTF8

local mul_sign, div_sign = U[[\N{MULTIPLICATION SIGN}]]:ToUtf8(), U[[\N{DIVISION_SIGN}]]:ToUtf8()

local line_num = 0
for line in io.lines( [[..\UCD\auxiliary\GraphemeBreakTest.txt]] ) do
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
            if not succ then break end
            
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
            local seqs_str = {}
            for i,seq in ipairs(seqs) do
                seqs_str[i] = '"' .. seqs[i]:ToUtf8() .. '"'
            end
            local seq_str = table.concat( seqs_str, ", " )
            
            print( string.format( 'Test for line #%i:\nExpected in-string:\n    %q\nExpected out-string:\n    %s\n', line_num, in_line:ToUtf8(), seq_str ) )
        until true
    end
end
local Encodings = require "us4l.internals.Encodings"

--Takes a string containing pairs of hex characters separated by spaces, returns a string containing those corresponding bytes
local function byte_str ( str )
    return str:gsub(" ",""):gsub("%x%x", function(pair)
        return string.char( tonumber( pair, 16 ) )
    end )
end

--Takes an arbitrary string, pretty-prints it as hex pairs
local function to_byte_str ( str )
    return str:gsub(".", function( ch )
        return string.format("%02X ", ch:byte())
    end):sub(1,-2)
end

local function print_cp_list ( cp_list )
    local buf = {}
    for i, cp in ipairs( cp_list ) do
        buf[i] = string.format( "%04X", cp )
    end
    return table.concat( buf, " " )
end

local function compare_cp_lists ( cpl1, cpl2 )
    if #cpl1 ~= #cpl2 then
        return false
    end
    
    for i = 1, #cpl1 do
        if cpl1[i] ~= cpl2[i] then
            return false
        end
    end
    
    return true
end

local RepetitionNumber = 200
local function cp_list_rep ( cp_list, n )
    local out = {}
    for rep_n = 1, n do
        local ofs = #out
        for i = 1, #cp_list do
            out[ ofs+i ] = cp_list[i]
        end
    end
    return out
end

test_sequences = {
    {   code_points = { 0x0041, 0x03A9, 0x8A9E, 0x10384 },
        UTF8    = byte_str"41 CE A9 E8 AA 9E F0 90 8E 84",
        UTF16LE = byte_str"41 00 A9 03 9E 8A 00 D8 84 DF",
        UTF16BE = byte_str"00 41 03 A9 8A 9E D8 00 DF 84",
        UTF32LE = byte_str"41 00 00 00 A9 03 00 00 9E 8A 00 00 84 03 01 00",
        UTF32BE = byte_str"00 00 00 41 00 00 03 A9 00 00 8A 9E 00 01 03 84" },
    
    {   code_points = { 0x00F0, 0x0436, 0x0628, 0x0905, 0x3042, 0x4E0A, 0x1040C, 0x20021, 0xE0021, 0x100021 },
        UTF8    = byte_str"C3 B0 D0 B6 D8 A8 E0 A4 85 E3 81 82 E4 B8 8A F0 90 90 8C F0 A0 80 A1 F3 A0 80 A1 F4 80 80 A1",
        UTF16LE = byte_str"F0 00 36 04 28 06 05 09 42 30 0A 4E 01 D8 0C DC 40 D8 21 DC 40 DB 21 DC C0 DB 21 DC",
        UTF16BE = byte_str"00 F0 04 36 06 28 09 05 30 42 4E 0A D8 01 DC 0C D8 40 DC 21 DB 40 DC 21 DB C0 DC 21",
        UTF32LE = byte_str"F0 00 00 00 36 04 00 00 28 06 00 00 05 09 00 00 42 30 00 00 0A 4E 00 00 0C 04 01 00 21 00 02 00 21 00 0E 00 21 00 10 00",
        UTF32BE = byte_str"00 00 00 F0 00 00 04 36 00 00 06 28 00 00 09 05 00 00 30 42 00 00 4E 0A 00 01 04 0C 00 02 00 21 00 0E 00 21 00 10 00 21" }
}

local encoding_names = { "UTF8", "UTF16LE", "UTF16BE", "UTF32LE", "UTF32BE" }
local success_terms = {
    [ true  ] = "passed";
    [ false ] = "failed !!!"; --Needs the extra characters so it stands out more, since the two words are the same length
}

local no_tests_failed = true
for seq_num, seq_data in ipairs( test_sequences ) do
    print( string.format( "Testing sequence #%i: %s", seq_num, print_cp_list( seq_data.code_points ) ) )
    
    --Test conversions of cp_list -> UTF
    for _, enc_name in ipairs(encoding_names) do
        local expected_string = seq_data[ enc_name ]
        local converted_string = Encodings[ enc_name ].EncodeCpList( seq_data.code_points )
        local success = expected_string == converted_string
        print( string.format( "    cp_list     -> %-8s %s", enc_name .. ":", success_terms[ success ] ) )
        if not success then
            print( string.format( "        Expected:  %s", to_byte_str( expected_string ) ) )
            print( string.format( "        Converted: %s", to_byte_str( converted_string ) ) )
        end
    end
    
    --Test conversions of cp_list -> UTF with large string
    for _, enc_name in ipairs(encoding_names) do
        local cp_list = cp_list_rep( seq_data.code_points, RepetitionNumber )
        local expected_string = seq_data[ enc_name ]:rep( RepetitionNumber )
        local converted_string = Encodings[ enc_name ].EncodeCpList( cp_list )
        local success = expected_string == converted_string
        print( string.format( "    cp_list*%i -> %-8s %s", RepetitionNumber, enc_name .. ":", success_terms[ success ] ) )
    end
    
    --Test conversions of UTF -> cp_list
    for _, enc_name in ipairs(encoding_names) do
        local converted_cp_list = Encodings[ enc_name ].DecodeWholeString( seq_data[ enc_name ] )
        local success = compare_cp_lists( seq_data.code_points, converted_cp_list )
        print( string.format( "    %-7s     -> cp_list: %s", enc_name, success_terms[ success ] ) )
        if not success then
            print( string.format( "        Expected:  %s", print_cp_list( seq_data.code_points ) ) )
            print( string.format( "        Converted: %s", print_cp_list( converted_cp_list ) ) )
        end
    end
    
    --Test conversions of UTF -> cp_list with large string
    for _, enc_name in ipairs(encoding_names) do
        local converted_cp_list = Encodings[ enc_name ].DecodeWholeString( seq_data[ enc_name ]:rep( RepetitionNumber ) )
        local success = compare_cp_lists( cp_list_rep( seq_data.code_points, RepetitionNumber ), converted_cp_list )
        print( string.format( "    %-11s -> cp_list: %s", enc_name .. "*" .. tostring(RepetitionNumber), success_terms[ success ] ) )
    end
    
    print ""
end

if no_tests_failed then
    print "All tests passed"
else
    print "Some tests failed"
end

return no_tests_failed
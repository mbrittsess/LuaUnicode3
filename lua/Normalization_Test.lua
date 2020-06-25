require "us4l"
local MakeUString = require "us4l.internals.MakeUString" --U{ cp, cp, cp } isn't implemented yet

local function CpTextToUString ( txt )
    local cp_list = {}
    for cp_txt in txt:gmatch("%x+") do
        cp_list[ #cp_list + 1 ] = tonumber( cp_txt, 16 )
    end
    return MakeUString( cp_list )
end

local unpack = table.unpack or unpack

local tests = {
    { 2, 1, "ToNFC" },
    { 2, 2, "ToNFC" },
    { 2, 3, "ToNFC" },
    { 4, 4, "ToNFC" },
    { 4, 5, "ToNFC" },
    
    { 3, 1, "ToNFD" },
    { 3, 2, "ToNFD" },
    { 3, 3, "ToNFD" },
    { 5, 4, "ToNFD" },
    { 5, 5, "ToNFD" },
    
    { 4, 1, "ToNFKC" },
    { 4, 2, "ToNFKC" },
    { 4, 3, "ToNFKC" },
    { 4, 4, "ToNFKC" },
    { 4, 5, "ToNFKC" },
    
    { 5, 1, "ToNFKD" },
    { 5, 2, "ToNFKD" },
    { 5, 3, "ToNFKD" },
    { 5, 4, "ToNFKD" },
    { 5, 5, "ToNFKD" }
}

local success = true
local line_number = 0
for line in io.lines[[../UCD/NormalizationTest.txt]] do
    line_number = line_number + 1
    if line:match("^%x") then
        print( string.format( "Executing test on line %i", line_number ) )
        local columns = {}
        for column_txt in line:gmatch("[^;]+") do
            columns[ #columns+1 ] = CpTextToUString( column_txt )
            if #columns == 5 then
                break
            end
        end
        
        for _, test_parms in ipairs( tests ) do
            local plain_col, trans_col, methname = unpack( test_parms )
            local plain_s, trans_s = columns[ plain_col ], columns[ trans_col ]
            if plain_s ~= trans_s[ methname ]( trans_s ) then
                print( string.format( "On line %i, test c%i == %s( c%i ) failed", line_number, plain_col, methname, trans_col ) )
                --print( string.format( "String c%i:\n%s", plain_col, plain_s:PrettyPrint() ) )
                --print( string.format( "String %s( c%i ):\n%s", methname, trans_col, trans_s[methname]( trans_s ):PrettyPrint() ) )
                success = false
            end
        end
    end
end

print( success and "All tests passed" or "Some tests failed" )
return success

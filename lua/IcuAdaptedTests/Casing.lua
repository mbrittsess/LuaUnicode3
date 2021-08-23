local U = require "us4l".U
local TestCases = {
    { 
        Conversion = "Lowercase";
        { U[[ tHe QUIcK bRoWn]], U[[ the quick brown]] };
        --{ U[[aBI\u{3A3}\u{DF}\u{3A3}/\u{5FFFF}\u{10405}]], U[[abi\u{3C3}\u{DF}\u{3C2}/\u{5FFFF}\u{1042D}]] }; --TODO: Need support for unassigned characters
    };
    {
        Conversion = "Uppercase";
        { U[[ tHe QUIcK bRoWn]], U[[ THE QUICK BROWN]] };
        --{ U[[aBi\u{3C3}\u{DF}\u{3C2}/\u{FB03}\u{5FFFF}\u{1042D}]], U[[ABI\u{3A3}SS\u{3A3}/FFI\u{5FFFF}\u{10405}]] }; --TODO: Need support for unassigned characters
    };
    {
        Conversion = "Titlecase";
        { U[[\u{2BB}aMeLikA huI P\u{16B} \u{2BB}\u{2BB}\u{2BB}iA]], U[[\u{2BB}Amelika Hui P\u{16B} \u{2BB}\u{2BB}\u{2BB}Ia]] };
        { U[[ tHe QUIcK bRoWn]], U[[ The Quick Brown]] };
        { U[[\u{1C9}ubav ljubav]], U[[\u{1C8}ubav Ljubav]] };
        { U[[ijssel igloo IJMUIDEN]], U[[Ijssel Igloo Ijmuiden]] };
        { U[['oH dOn'T tItLeCaSe AfTeR lEtTeR+']], U[['Oh Don't Titlecase After Letter+']] };
        { U[[a \u{2BB}CaT. A \u{2BB}dOg! \u{2BB}eTc.]], U[[A \u{2BB}Cat. A \u{2BB}Dog! \u{2BB}Etc.]] };
    };
    --[=[
    {
        Conversion = "Casefold";
        --{ U[[aB\u{130}I\u{131}\u{3D0}\u{DF}\u{FB03}\u{5FFFF}]], U[[abi\u{307}i\u{131}\u{3B2}ssffi\u{5FFFF}]] }; --TODO: Need support for unassigned characters
    };
    --]=]
}

for _, cases in ipairs( TestCases ) do
    local any_failed = false
    print( string.format( "Trying test cases for '%s'", cases.Conversion ) )
    local method_name = "To" .. cases.Conversion
    for i = 1, #cases do
        local input = cases[i][1]
        local expected = cases[i][2]
        local actual = input[ method_name ]( input )
        if expected ~= actual then
            any_failed = true
            print( string.format( "Failed case #%i: expected:\n%s\ngot:\n%s", i, expected:PrettyPrint(), actual:PrettyPrint() ) )
        end
    end
    
    if not any_failed then
        print "All test cases successful!"
    end
end
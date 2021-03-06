$Combos = @(
    @{ Name = "Lua 5.1"; Exe = "lua";   Hashes = @( "UTF8Hash", "UTF24Hash" ) },
    @{ Name = "Lua 5.2"; Exe = "lua52"; Hashes = @( "UTF8Hash", "UTF24Hash", "TestFnvHash" ) }
)

ForEach( $Data in $Combos )
{
    $Name = $Data.Name
    $Exe = $Data.Exe
    ForEach ( $HashPackage in $Data.Hashes )
    {
        $ExecTime = Measure-Command { $Global:ExecOutput = & $Exe -e ("hash_function_package = '{0}'" -f $HashPackage) HashTest.lua }
        "Executing $Name with hash package $HashPackage"
        "Execution took {0:F3}s" -f $ExecTime.TotalSeconds
        $Global:ExecOutput
        ""
    }
}
$CompilerParameters = New-Object System.CodeDom.Compiler.CompilerParameters -Property @{
    IncludeDebugInformation = $True;
    GenerateInMemory        = $True;
}
$CompilerParameters.Referencedassemblies.AddRange( @(
    'System.dll',
    'System.Core.dll'
) )

$CodeProvider = New-Object Microsoft.CSharp.CSharpCodeProvider <# (
    & { $P = New-Object 'System.Collections.Generic.Dictionary[String,String]'
        $P.Add( "CompilerVersion", "v3.5" )
        $P | Write-Output
    }
) #>

$Files = Resolve-Path "$Pwd\*.cs"
#TODO: Debug/Verbose Output

$CompilerResults = $CodeProvider.CompileAssemblyFromFile(
    $CompilerParameters,
    [String[]]@( Resolve-Path "$Pwd\*.cs" )
)

If ( $CompilerResults.Errors.Count -gt 0 )
{
    $CompilerResults.Errors | Write-Error
}

Export-ModuleMember #Nothing is exported
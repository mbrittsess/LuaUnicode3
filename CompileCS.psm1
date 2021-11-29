$CompilerParameters = New-Object System.CodeDom.Compiler.CompilerParameters -Property @{
    IncludeDebugInformation = $True;
    GenerateInMemory        = $True;
}
$CompilerParameters.Referencedassemblies.AddRange( @(
    'System.dll',
    'System.Core.dll'
) )

Function TryCompile ( [Microsoft.CSharp.CSharpCodeProvider]$CodeProvider )
{
    $CompilerResults = $CodeProvider.CompileAssemblyFromFile(
        $CompilerParameters,
        [String[]]@( Resolve-Path "$Pwd\*.cs" )
    )
    If ( $CompilerResults.Errors.Count -gt 0 )
    {
        $CompilerResults.Errors | Write-Error
    }
}

$CodeProvider = New-Object Microsoft.CSharp.CSharpCodeProvider

$Files = Resolve-Path "$Pwd\*.cs"
#TODO: Debug/Verbose Output

Try
{
    TryCompile $CodeProvider
}
Catch
{
    $CodeProvider = New-Object Microsoft.CSharp.CSharpCodeProvider (
        & { $P = New-Object 'System.Collections.Generic.Dictionary[String,String]'
            $P.Add( "CompilerVersion", "v3.5" )
            $P | Write-Output
        }
    )
    TryCompile $CodeProvider
}

Export-ModuleMember #Nothing is exported

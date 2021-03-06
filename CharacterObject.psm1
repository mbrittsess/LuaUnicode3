Import-Module .\CompileCS.psm1

Function New-Character
{
    Param
    (
        [UInt32]$CP
    )
    
    $Ret = New-Object PSObject -Property @{
        cp = $CP;
        properties = @{};
    }
    
    [LuaInteger]$Val = New-Object LuaInteger $CP, Hexadecimal
    [LuaKV]$Prop = New-Object LuaKV codepoint, $Val
    
    Add-CharacterProperty $Ret $Prop
    
    Return $Ret
}

Function Add-CharacterProperty
{
    #TODO: Parameter validation, -PassThru, -Force, pipeline binding
    Param
    (
        [PSObject]
        $Character,
        
        [LuaKV]
        $Property #TODO: Assert that the key is a LuaString
    )
    
    [String]$Key = $Property.Key.Value
    If ($Character.properties.ContainsKey( $Key ) )
    {
        Throw New-Object Exception ("Character U+{0:X4} already contains a property '{1}'" -f $Character.cp, $Key)
    }
    
    $Character.properties[ $Key ] = $Property
}

Function Get-CharacterProperty
{
    #TODO: Ability to decide which property/ies one would like to query
    Param
    (
        [PSObject]
        $Character
    )
    
    ForEach ( $Val in $Character.properties.Values )
    {
        $Val | Write-Output
    }
}

Export-ModuleMember -Function New-Character, Add-CharacterProperty, Get-CharacterProperty
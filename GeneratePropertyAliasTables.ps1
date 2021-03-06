#TODO: Need to update to use the full list of properties from Normalize.psm1

Import-Module .\CompileCS.psm1
#Import-Module .\Progress.psm1 # TODO: Add progress stuff later
Import-Module .\FileUtilities.psm1

$PropertyNames = @{}

[String[]]$ExtraProperties = ,"Prepended_Concatenation_Mark"

$PASR = Get-StreamReader UCD\PropertyAliases.txt
& {
'return {'
    While ( ($Line = $PASR.ReadNonCommentLine()) -ne $Null )
    {
        [String[]]$Names = ($Line -split ';') | ForEach-Object { [Normalize]::PropertyName( $_.Trim() ) }
        $CanonName = $Names[1]
        ForEach ( $Name in $Names )
        {
            '    [ "{0}" ] = "{1}";' -f $Name, $CanonName
            $PropertyNames[ $Name ] = $CanonName
        }
    }
    ForEach ( $Name in $ExtraProperties )
    {
        $NormName = [Normalize]::PropertyName( $Name )
        '    [ "{0}" ] = "{1}";' -f $NormName, $NormName
        $PropertyNames[ $NormName ] = $NormName
    }
'}'
} | Out-File -FilePath lua\us4l\internals\PropertyAliasesTable.lua -Encoding ASCII


$PVASR = Get-StreamReader UCD\PropertyValueAliases.txt
$Properties = @{}
$PropertiesList = New-Object ([System.Collections.Generic.List[System.String]]).ToString()
Function KVPair ( $Key, $Value ) { return New-Object ([System.Collections.Generic.KeyValuePair[String,String]]).ToString() $Key, $Value }
#Function KVList { return New-Object ([System.Collections.Generic.List[System.Collections.Generic.KeyValuePair[String,String]]]).ToString() }

While ( ($Line = $PVASR.ReadNonCommentLine()) -ne $Null )
{
    [String]$Category, [String[]]$Values = ($Line -split ';') | ForEach-Object { $_.Trim() }
    $Category = [Normalize]::PropertyName( $Category )
    $Values = $Values | ForEach-Object { '[[' + [Normalize]::PropertyValue( $_ ) + ']]' }
    
    # Age requires some special handling and I haven't quite decided how it works yet
    If ( $Category -eq 'age' -and $Values[0] -ne '[[na]]' )
    {
        Continue
    }
    
    # Canonical_Combining_Class also requires special handling. Again, not quite sure how to handle
    # Another issue with CCC is that it has one value alias "IS", which normalizes to the empty string, which might not be good to allow.
    If ( $Category -eq 'ccc' )
    {
        $Values = $Values[ 1 .. ($Values.Count-1) ]
    }
    
    If ( -not $Properties.ContainsKey( $Category ) )
    {
        $KVList = New-Object ([System.Collections.Generic.List[System.Collections.Generic.KeyValuePair[String,String]]]).ToString()
        $Properties.Add( $Category, $KVList )
        $PropertiesList.Add( $Category )
    }
    $ValuesList = $Properties[ $Category ]
    
    # Special handling for boolean types
    $CanonValue = $Values[1]
    If ( $CanonValue -eq '[[no]]' )
    {
        $CanonValue = 'false'
    } 
    ElseIf ( $CanonValue -eq '[[yes]]' )
    {
        $CanonValue = 'true'
    }
    
    ForEach ( $Value in $Values )
    {
        If ( $Value -ne $CanonValue )
        {
            $KV = KVPair $Value $CanonValue
            $ValuesList.Add( $KV )
        }
    }
}
& {
'return {'
    ForEach ( $Category in $PropertiesList )
    {
        '    {0} = {{' -f $PropertyNames[ $Category ]
        ForEach ( $KV in $Properties[ $Category ] )
        {
            '        [ {0} ] = {1};' -f $KV.Key, $KV.Value
        }
        '    };'
    }
'}'
} | Out-File -FilePath lua\us4l\internals\PropertyValueAliasesTable.lua -Encoding ASCII
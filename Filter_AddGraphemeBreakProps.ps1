<# Processes auxiliary\GraphemeBreakProperty.txt
    This filter adds the Grapheme_Cluster_Break property.
#>

Param
(
    [Parameter(
        Mandatory=$True,
        ValueFromPipeline=$True)]
    [PSObject[]]
    $InputCharacter
)

Begin
{
    Import-Module .\Normalize.psm1
    Import-Module .\CharacterObject.psm1
    
    $GraphemeBreakProperties_Unsorted = New-Object ([System.Collections.Generic.List[PSObject]]).ToString()
    
    Get-Content UCD\auxiliary\GraphemeBreakProperty.txt | Where-Object {
        $_ -ne "" -and -not $_.StartsWith( "#" )
    } | ForEach-Object {
        [Void]($_ -match '^([^#]+)')
        $Line = $Matches[1]

        $CP, $Value = $Line -split ';' | ForEach-Object { $_.Trim() }
        If ( -not $CP.Contains("..") )
        {
            [UInt32]$CP_Start = [UInt32]::Parse( $CP, 'AllowHexSpecifier' )
            [UInt32]$CP_End = $CP_Start
        }
        Else
        {
            [UInt32]$CP_Start, [UInt32]$CP_End = $CP -split "\.\." | ForEach-Object { [UInt32]::Parse( $_, 'AllowHexSpecifier' ) }
        }

        $NormValue = Normalize-PropertyValueName -PropertyName Grapheme_Cluster_Break -Value $Value
        $KeyName = Normalize-PropertyName Grapheme_Cluster_Break
        $KV = New-Object LuaKV $KeyName, (New-Object LuaString $NormValue, Long)
        $GraphemeBreakProperties_Unsorted.Add( (New-Object PSObject -Property @{
            Start = $CP_Start;
            End   = $CP_End;
            Value = $NormValue;
            KV    = $KV;
        }) )
    }

    $GraphemeBreakProperties = $GraphemeBreakProperties_Unsorted | Sort-Object -Property Start

    # Verify that there is no overlap
    ForEach ( $Idx in 0 .. ($GraphemeBreakProperties.Count-2) )
    {
        If ( $GraphemeBreakProperties[ $Idx ].End -ge $GraphemeBreakProperties[ $Idx+1 ].Start )
        {
            $GBP1 = $GraphemeBreakProperties[$Idx]
            $GBP2 = $GraphemeBreakProperties[$Idx+1]
            $ErrMsg = "Overlap between {0:X4}..{1:X4} ({2}) and {3:X4}..{4:X4} ({5})" -f $GBP1.Start, $GBP1.End, $GBP1.Value, $GBP2.Start, $GBP2.End, $GBP2.Value
            Write-Error $ErrMsg
        }
    }

    $CurPropIdx = 0
    $CurProp = $GraphemeBreakProperties[ 0 ]
}

Process
{
    ForEach ( $Character in $InputCharacter )
    {
        $CharCP = $Character.cp
        
        If ( $CurProp -ne $Null -and $CurProp.Start -le $CharCP -and $CharCP -le $CurProp.End )
        {
            Add-CharacterProperty $Character $CurProp.KV
            If ( $CharCP -eq $CurProp.End )
            {
                $CurPropIdx += 1
                If ( $CurPropIdx -ge $GraphemeBreakProperties.Count )
                {
                    $CurProp = $Null
                }
                Else
                {
                    $CurProp = $GraphemeBreakProperties[ $CurPropIdx ]
                }
            }
        }
        
        $Character | Write-Output
    }
}
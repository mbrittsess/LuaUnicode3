﻿Function Get-UcdData
{
    [CmdletBinding()]
    
    Param
    (
        [Parameter(Mandatory=$True,Position=0)]
        [String]
        $Path,
        
        [Text.Encoding]
        $Encoding = [Text.Encoding]::UTF8,
        
        [Parameter(Mandatory=$True,Position=1)]
        [ScriptBlock]
        $Action
        <# The public interface of the $Action scriptblock is:
            [Double]$Progress
            [String]$Comment
            [Boolean]$CommentOnly
            $CodePoint # Either a single [UInt32] or a 2-element [UInt32[]]
            [Boolean]$IsRange
            [String[]]$Fields #>
    )
    
    $FI = Get-Item -Path $Path
    $Stream = $FI.OpenRead()
    $Reader = New-Object System.IO.StreamReader $Stream, $Encoding
    
    While ( -not $Reader.EndOfStream )
    {
        $WholeLine = $Reader.ReadLine()
        [Double]$Progress = $Stream.Position / $Stream.Length
        [Void]($WholeLine -match '^(?<Content>[^#]*)#?(?<Comment>.*)$')
        $Content, [String]$Comment = $Matches['Content'].Trim(), $Matches['Comment'].Trim()
        
        [Boolean]$CommentOnly = $Content -eq "" -and $Comment -ne ""
            
        If ( $Content -ne "" )
        {
            $CP, [String[]]$Fields = $Content -split ';' | ForEach-Object { $_.Trim() }
            $CodePoint = $CP -split '\.\.' | ForEach-Object { [UInt32]::Parse( $_, 'AllowHexSpecifier' ) }
            [Boolean]$IsRange = $CodePoint -is [Object[]]
        }
        
        If ( $Content -ne "" -or $Comment -ne "" )
        {
            & $Action | Write-Output
        }
    }
    
    $Reader.Close()
    $Stream.Close()
}

<# This was just written as a test.
Iterate-UcdFile UCD\HangulSyllableType.txt {
    If ( -not $CommentOnly ) {
        If ( -not $IsRange ) {
            Write-Progress -Activity 'Gathering Hangul syllable types' -Status Running -PercentComplete ($Progress * 100.0) -CurrentOperation ("U+{0:X4} = {1}" -f $CodePoint, $Fields[0]) -Id 1
        } Else {
            Write-Progress -Activity 'Gathering Hangul syllable types' -Status Running -PercentComplete ($Progress * 100.0) -CurrentOperation ("Expanding U+{0:X4} to U+{1:X4}" -f $CodePoint[0], $CodePoint[1]) -Id 1
            $Start, $End = $CodePoint[0], $CodePoint[1]
            $Length = $End - $Start + 1
            ForEach ( $CP in $Start .. $End )
            {
                Write-Progress -Activity "Expanding code points" -Status Running -PercentComplete ( (($CP - $Start) / $Length) * 100.0 ) -CurrentOperation ("U+{0:X4} = {1}" -f [UInt32]$CP, $Fields[0]) -Id 2 -ParentId 1
            }
            Write-Progress -Activity "Expanding code points" -Status Done -Completed -Id 2 -ParentId 1
        }
    }
}
Write-Progress -Activity 'Gathering Hangul syllable types' -Status Done -Completed -Id 1 #>

# This is used for the variant-formatted data in UnicodeData.txt
Function Get-UcdDataUnicodeData
{
    [CmdletBinding()]
    
    Param
    (
        [Parameter(Mandatory=$True,Position=0)]
        [String]
        $Path,
        
        [Text.Encoding]
        $Encoding = [Text.Encoding]::UTF8,
        
        [Parameter(Mandatory=$True,Position=1)]
        [ScriptBlock]
        $Action
        <# The public interface of the $Action scriptblock is:
            [Double]$Progress
            [String]$Comment
            [Boolean]$CommentOnly
            $CodePoint # Either a single [UInt32] or a 2-element [UInt32[]]
            [Boolean]$IsRange
            [String[]]$Fields # Fields are taken from the first line (not that it is ever different from the second) #>
        <# In the case of a range, $Fields[0] will contain the range name. In the case of:
                DC00;<Low Surrogate, First>;Cs;0;L;;;;;N;;;;;
                DFFF;<Low Surrogate, Last>;Cs;0;L;;;;;N;;;;;
            , the range name will be "Low Surrogate" #>
    )
    
    $FI = Get-Item -Path $Path
    $Stream = $FI.OpenRead()
    $Reader = New-Object System.IO.StreamReader $Stream, $Encoding
    
    While ( -not $Reader.EndOfStream )
    {
        $WholeLine = $Reader.ReadLine()
        [Double]$Progress = $Stream.Position / $Stream.Length
        [Void]($WholeLine -match '^(?<Content>[^#]*)#?(?<Comment>.*)$')
        $Content, [String]$Comment = $Matches['Content'].Trim(), $Matches['Comment'].Trim()
        
        [Boolean]$CommentOnly = $Content -eq "" -and $Comment -ne ""
            
        If ( $Content -ne "" )
        {
            $CP, [String[]]$Fields = $Content -split ';' | ForEach-Object { $_.Trim() }
            $CodePoint = [UInt32]::Parse( $CP, 'AllowHexSpecifier' )
            [Boolean]$IsRange = $Fields[0].EndsWith( "First>" )
        }
        
        If ( $IsRange )
        {
            $SecondLine = $Reader.ReadLine()
            $SecondCodePoint = @($SecondLine -split ';')[0]
            $CodePoint = $CodePoint, [UInt32]::Parse( $SecondCodePoint, 'AllowHexSpecifier' )
            [Void]( $Fields[0] -match '^\<(.+?),' )
            $Fields[0] = $Matches[1]
        }
        
        If ( $Content -ne "" -or $Comment -ne "" )
        {
            & $Action | Write-Output
        }
    }
    
    $Reader.Close()
    $Stream.Close()
}

<# This was just written as a test.
Iterate-UcdFileUnicodeData UCD\UnicodeData.txt {
    If ( -not $CommentOnly ) {
        If ( -not $IsRange ) {
            Write-Progress -Activity 'Gathering General_Category values' -Status Running -PercentComplete ($Progress * 100.0) -CurrentOperation ("U+{0:X4} {1} = {2}" -f $CodePoint, $Fields[0], $Fields[1]) -Id 1
        } Else {
            Write-Progress -Activity 'Gathering General_Category values' -Status Running -PercentComplete ($Progress * 100.0) -CurrentOperation ("Expanding U+{0:X4} to U+{1:X4} ({2})" -f $CodePoint[0], $CodePoint[1], $Fields[0]) -Id 1
            $Start, $End = $CodePoint[0], $CodePoint[1]
            $Length = $End - $Start + 1
            ForEach ( $CP in $Start .. $End )
            {
                Write-Progress -Activity "Expanding code points" -Status Running -PercentComplete ( (($CP - $Start) / $Length) * 100.0 ) -CurrentOperation ("U+{0:X4} = {1}" -f [UInt32]$CP, $Fields[1]) -Id 2 -ParentId 1
            }
            Write-Progress -Activity "Expanding code points" -Status Done -Completed -Id 2 -ParentId 1
        }
    }
}
Write-Progress -Activity 'Gathering General_Category values' -Status Done -Completed -Id 1 #>

Function Get-UnihanData
{
    [CmdletBinding()]
    
    Param
    (
        [Parameter(Mandatory=$True,Position=0)]
        [String]
        $Path,
        
        [Text.Encoding]
        $Encoding = [Text.Encoding]::UTF8,
        
        [Parameter(Mandatory=$True,Position=1)]
        [ScriptBlock]
        $Action
        <# The public interface of the $Action scriptblock is:
            [Double]$Progress
            [String]$Comment
            [Boolean]$CommentOnly
            [UInt32]$CodePoint # A single [UInt32], Unihan files never contain ranges.
            [String]FieldName
            [String[]]$Fields
            [String]$WholeFields #>
    )
    
    $FI = Get-Item -Path $Path
    $Stream = $FI.OpenRead()
    $Reader = New-Object System.IO.StreamReader $Stream, $Encoding
    
    While ( -not $Reader.EndOfStream )
    {
        $WholeLine = $Reader.ReadLine()
        [Double]$Progress = $Stream.Position / $Stream.Length
        [Void]($WholeLine -match '^(?<Content>[^#]*)#?(?<Comment>.*)$')
        $Content, [String]$Comment = $Matches.Content.Trim(), $Matches.Comment.Trim()
        
        [Boolean]$CommentOnly = $Content -eq "" -and $Comment -ne ""
            
        If ( $Content -ne "" )
        {
            $CodePoint, [String]$FieldName, $SubFields = $Content -split "`t" | ForEach-Object { $_.Trim() }
            $CodePoint = [UInt32]::Parse( $CodePoint.Remove( 0, 2 ), 'AllowHexSpecifier' )
            [String[]]$Fields = $Subfields -split '\s'
            [String]$WholeFields = $SubFields
        }
        
        If ( $Content -ne "" -or $Comment -ne "" )
        {
            & $Action | Write-Output
        }
    }
    
    $Reader.Close()
    $Stream.Close()
}

<# This was just written as a test.
Iterate-UnihanFile Unihan\Unihan_Readings.txt {
    If ( -not $CommentOnly -and $FieldName -eq 'kDefinition' )
    {
        Write-Progress -Activity 'Scanning readings' -Status Running -CurrentOperation ('U+{0:X4}' -f $CodePoint) -PercentComplete ($Progress * 100.0)
        'U+{0:X4}: "{1}"' -f $CodePoint, $WholeFields
    }
}
Write-Progress -Activity 'Scanning readings' -Status Done -Completed #>

Export-ModuleMember -Function Get-UcdData, Get-UcdDataUnicodeData, Get-UnihanData

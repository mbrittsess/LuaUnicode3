<# Adds the Hangul_Syllable_Type property, and also generates the Decomposition_Mapping for Precomposed Hangul Syllables #>

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
    #Import-Module .\Progress.psm1
    Import-Module .\FileUtilities.psm1
    Import-Module .\CharacterObject.psm1
    
    $HSTR = Get-StreamReader UCD\HangulSyllableType.txt
    
    $PropertyName = Normalize-PropertyName Hangul_Syllable_Type
    
    $SingleCodePoints = @{}
    $CodePointRanges = & {
        While ( ($Line = $HSTR.ReadNonCommentLine()) -ne $Null )
        {
            $Points, $SylType = (($Line | Strip-Comment) -split ';') | ForEach-Object { $_.Trim() }
            $SylValue = Normalize-PropertyValueName Hangul_Syllable_Type $SylType
            $SylLuaValue = New-Object LuaString $SylValue, Long
            $Value = New-Object LuaKV $PropertyName, $SylLuaValue
            If ( -not $Points.Contains( ".." ) )
            {
                $SingleCodePoints[ [UInt32]::Parse( $Points, 'AllowHexSpecifier' ) ] = $Value
            }
            Else
            {
                $StartPoint, $EndPoint = ($Points -split '\.\.') | ForEach-Object { [UInt32]::Parse( $_, 'AllowHexSpecifier' ) }
                New-Object PSObject -Property @{
                    Lo = $StartPoint;
                    Hi = $EndPoint;
                    Val = $Value;
                } | Write-Output
            }
        }
    } | Sort-Object -Property Lo
    
    $RangesPos = 0
    
    Function Get-HangulSyllableDecomposition
    {
        Param
        (
            [Parameter(Mandatory=$True)]
            [ValidateRange(0xAC00,0xD7A3)]
            [UInt32]
            $CodePoint,
            
            [Parameter(Mandatory=$True)]
            [ValidateSet('lvsyllable', 'lvtsyllable')]
            [String]
            $SyllableType
        )
        
        Function IntDiv ( [UInt32]$L, [UInt32]$R ) { Return [UInt32][Math]::Truncate( $L / $R ) }
        
        [UInt32]$SBase = 0xAC00
        [UInt32]$LBase = 0x1100
        [UInt32]$VBase = 0x1161
        [UInt32]$TBase = 0x11A7
        
        [UInt32]$LCount = 19
        [UInt32]$VCount = 21
        [UInt32]$TCount = 28
        [UInt32]$NCount = $VCount * $TCount
        [UInt32]$SCount = $LCount * $NCount
        
        [UInt32]$SIndex = $CodePoint - $SBase
        If ( $SyllableType -eq 'lvtsyllable' )
        {
            [UInt32]$LVIndex = (IntDiv $SIndex $TCount) * $TCount
            [UInt32]$TIndex = $SIndex % $TCount
            
            $LVPart = $SBase + $LVIndex
            $TPart = $TBase + $TIndex
            
            Return $LVPart, $TPart
        }
        Else #$SyllableType -eq 'lvsyllable'
        {
            $LIndex = IntDiv $SIndex $NCount
            $VIndex = IntDiv ($SIndex % $NCount) $TCount
            
            $LPart = $LBase + $LIndex
            $VPart = $VBase + $VIndex
            
            Return $LPart, $VPart
        }
    }
    
    $DecompMappingName = Normalize-PropertyName Decomposition_Mapping
}

Process
{
    ForEach ( $Character in $InputCharacter )
    {
        $CharCP = $Character.cp
        
        $CurRng = $CodePointRanges[ $RangesPos ]
        [LuaKV]$Value = $Null
        
        If ( $SingleCodePoints.ContainsKey( $CharCP ) )
        {
            $Value = $SingleCodePoints[ $CharCP ]
            #Add-CharacterProperty $Character $SingleCodePoints[ $CharCP ]
        }
        ElseIf ( $CurRng.Lo -le $CharCP -and $CharCP -le $CurRng.Hi )
        {
            $Value = $CurRng.Val
            #Add-CharacterProperty $Character $CurRng.Val
        }
        
        If ( $Value -ne $Null )
        {
            Add-CharacterProperty $Character $Value
            
            $SylType = $Value.Value.Value
            If ( "lvsyllable", "lvtsyllable" -contains $SylType )
            {
                [UInt32[]]$DecompPoints = Get-HangulSyllableDecomposition $CharCP $SylType # Always guaranteed to return 2 code points
                $DecompVal = New-Object LuaUString ([Char]::ConvertFromUtf32( [Int32]$DecompPoints[0] ) + [Char]::ConvertFromUtf32( [Int32]$DecompPoints[1] ))
                $DecompKV = New-Object LuaKV $DecompMappingName, $DecompVal
                Add-CharacterProperty $Character $DecompKV
            }
        }
        
        If ( $CurRng.Hi -eq $CharCP )
        {
            $RangesPos += 1
        }
        
        $Character | Write-Output
    }
}
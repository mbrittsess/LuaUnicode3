<# Processes auxiliary\WordBreakProperty.txt
    This filter adds the Word_Break property.
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
    Import-Module .\FileUtilities.psm1
    
    $Reader = Get-StreamReader UCD\auxiliary\WordBreakProperty.txt
    $PropertyName = Normalize-PropertyName -Name Word_Break
    
    $Props_Unsorted = New-Object ([System.Collections.Generic.List[PSObject]]).ToString()
    
    While ( ($Line = $Reader.ReadNonCommentLine()) -ne $Null )
    {
        $Line = $Line | Strip-Comment
        $CP, $Cat = @($Line -split ';') | ForEach-Object { $_.Trim() }
        $Cat = Normalize-PropertyValueName -PropertyName Word_Break -Value $Cat
        If ( $CP.Contains( '.' ) )
        {
            [UInt32]$CP_Start, [UInt32]$CP_End = @($CP -split '\.\.') | ForEach-Object { [UInt32]::Parse( $_, 'AllowHexSpecifier' ) }
        }
        Else
        {
            [UInt32]$CP_Start = [UInt32]::Parse( $CP, 'AllowHexSpecifier' )
            [UInt32]$CP_End = $CP_Start
        }
        [LuaString]$LuaVal = New-Object LuaString $Cat, 'Long'
        [LuaKV]$KV = New-Object LuaKV $PropertyName, $LuaVal
        [PSObject]$Prop = New-Object PSObject -Property @{
            Start = $CP_Start;
            End   = $CP_End;
            KV    = $KV;
        }
        $Props_Unsorted.Add( $Prop )
    }
    
    [PSObject[]]$Props_Sorted = $Props_Unsorted | Sort-Object -Property Start
    
    [System.Collections.Generic.LinkedList[PSObject]]$Prop_LL = New-Object ([System.Collections.Generic.LinkedList[PSObject]]) (,$Props_Sorted)
    $CurNode = $Prop_LL.First
    
    Function CurS { Return $CurNode.Value.Start }
    Function CurE { Return $CurNode.Value.End }
}

Process
{
    ForEach ( $Character in $InputCharacter )
    {
        $CharCP = $Character.cp
        
        While ( $CurNode -ne $Null )
        {
            If ( (CurE) -lt $CharCP )
            {
                $CurNode = $CurNode.Next
                Continue
            }
            
            If ( (CurS) -le $CharCP -and $CharCP -le (CurE) )
            {
                Add-CharacterProperty $Character $CurNode.Value.KV
            }
            
            Break
        }
        
        $Character | Write-Output
    }
}
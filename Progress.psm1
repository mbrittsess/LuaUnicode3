$Script:IdCounter = 0

Function Script:InternalNewProgress
{
    Param
    (
        [String]
        $ActivityName,
        
        [Object]
        $Parent
    )
    
    $Ret = New-Object PSObject -Property @{
        _Id = ++$Script:IdCounter;
        _ParentProgress = $Parent;
        _Activity = $ActivityName;
        _OverallStatus = "Default Status";
        _CurrentOperation = "";
        _PercentComplete = [Double]0.0;
    } | Add-Member ScriptMethod _Flush {
        $ParentId = -1
        If ( $This._ParentProgress -ne $Null )
        {
            $ParentId = $This._ParentProgress._Id
        }
        
        $ProgArgs = @{
            Activity = $This._Activity;
            Status   = $This._OverallStatus;
            Id       = $This._Id;
            ParentId = $ParentId;
            PercentComplete = [Int32]( $This._PercentComplete * 100.0 );
        }
        
        If ( -not [String]::IsNullOrEmpty( $This._CurrentOperation ) )
        {
            $ProgArgs[ 'CurrentOperation' ] = $This._CurrentOperation 
        }
        
        If ( -not $Global:US4L_DISABLE_PROGRESS )
        {
            Write-Progress @ProgArgs
        }
    } -PassThru | Add-Member ScriptMethod NewChild {
        [OutputType([PSObject])]
        Param
        (
            [String]$Activity
        )
        
        Return InternalNewProgress -ActivityName $Activity -Parent $This
    } -PassThru | Add-Member ScriptMethod Update { # Is the only one which refreshes the display.
        Param
        (
            [ValidateRange(0.0, 1.0)]
            [Double]
            $PercentComplete
        )
        
        $This._PercentComplete = $PercentComplete
        $This._Flush()
    } -PassThru | Add-Member ScriptProperty OverallStatus {
        Return $This._OverallStatus
    } {
        $This._OverallStatus = $args[0]
    } -PassThru | Add-Member ScriptProperty CurrentOperation {
        Return $This._CurrentOperation
    } {
        $This._CurrentOperation = $args[0]
    } -PassThru
    
    $Ret.Update( 0.0 )
    
    Return $Ret
}

Function New-RootProgress
{
    Param
    (
        [String]
        $Activity
    )
    
    Return Script:InternalNewProgress $Activity $Null
}

Export-ModuleMember -Function New-RootProgress
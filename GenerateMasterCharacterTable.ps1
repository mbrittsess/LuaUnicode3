#Remove-Item Output\*

$Global:WarningPreference = 'SilentlyContinue'
$Global:ErrorActionPreference = 'Stop'
$Global:US4L_DISABLE_PROGRESS = $True

$StartTime = [DateTime]::Now
"Started generating table at {0}" -f $StartTime
.\Source_UnicodeData.ps1 | 
ForEach-Object -Begin { $NumTotal = 0 } -Process { If ( ++$NumTotal % 1000 -eq 0 ) { [Console]::Beep() }; $_ } | 
.\Filter_AddNameAliases.ps1 | 
.\Filter_AddBlocks.ps1 |
.\Filter_AddAge.ps1 |
.\Filter_AddPropList.ps1 |
.\Filter_AddSpecialCasing.ps1 |
.\Filter_AddDerivedCoreProps.ps1 |
.\Filter_AddHangulSyllableType.ps1 | 
.\Filter_AddUnihanNumericValues.ps1 |
.\Filter_AddUnihanReadings.ps1 |
.\Filter_MakePrimaryCompositesTable.ps1 |
.\Filter_AddGraphemeBreakProps.ps1 |
.\Filter_AddCaseFolding.ps1 |
.\Sink_MasterTable.ps1
$EndTime = [DateTime]::Now
[Console]::Beep( 800, 1000 )
"Finished generating table at {0}" -f $EndTime
$Span = ($EndTime - $StartTime)
"Time elapsed: {0}h{1}m{2}s" -f $Span.Hours, $Span.Minutes, $Span.Seconds
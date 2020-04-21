# ref:  https://www.aussierobsql.com/using-powershell-to-setup-performance-monitor-data-collector-sets/
# 04202020 - added section to create 'SQLAudit-Server.xml' file with drive letter metrics.  Also remove the dependency of
# the files being formatted correctly by creating them from within the script.

Param(
[string]$Server = $env:ComputerName,
[switch]$updateDC
)
 
#region Functions
Function CheckCollector([System.Object]$DCS,[string]$DCName)
{
    # Check if the data collector exists in the DataCollectorSet
    If (($DCS.DataCollectors | Select Name) -match $DCName)
        { Return $true }
    ELSE
        { Return $false }
}
 
Function CreateCollectorServer([System.Object]$DCS,[string]$DCName)
{
     $XML = Get-Content $ScriptDir\SQLAudit-Server.xml
     $DC = $DCS.DataCollectors.CreateDataCollector(0)
     $DC.Name = $DCName
     $DC.FileName = $DCName + "_";
     $DC.FileNameFormat = 0x0003;
     $DC.FileNameFormatPattern = "yyyyMMddHHmm";
     $DC.SampleInterval = 15;
     $DC.LogFileFormat = 0x0003;
     $DC.SetXML($XML);
     $DCS.DataCollectors.Add($DC)
}
 
Function CreateCollectorInstance([System.Object]$DCS,[string]$DCName,[string]$ReplaceString)
{
     $XML = (Get-Content $ScriptDir\SQLAudit-Instance.xml) -replace "%instance%", $ReplaceString
     $DC = $DCS.DataCollectors.CreateDataCollector(0)
     $DC.Name = $DCName
     $DC.FileName = $DCName + "_";
     $DC.FileNameFormat = 0x0003;
     $DC.FileNameFormatPattern = "yyyyMMddHHmm";
     $DC.SampleInterval = 15;
     $DC.LogFileFormat = 0x0003;
     $DC.SetXML($XML);
     $DCS.DataCollectors.Add($DC)
}
Function CommitChanges([System.Object]$DCS,[string]$DCSName)
{
    $DCS.SetCredentials($null,$null) # clear credentials 0x80300103 fix
    $DCS.Commit($DCSName,$Server,0x0003) | Out-Null
    $DCS.Query($DCSName,$Server) #refresh with updates.
}
 
Function Get-SqlInstances {
  Param($Server = $env:ComputerName)
 
  $Instances = @()
  [array]$captions = gwmi win32_service -computerName $Server | ?{$_.Caption -match "SQL Server*" -and $_.PathName -match "sqlservr.exe"} | %{$_.Caption}
  foreach ($caption in $captions) {
    if ($caption -eq "MSSQLSERVER") {
      $Instances += "MSSQLSERVER"
    } else {
      $Instances += $caption | %{$_.split(" ")[-1]} | %{$_.trimStart("(")} | %{$_.trimEnd(")")}
    }
  }
  $Instances
}

#endregion Functions

## Script starts here ##
$DCSName = "SQLAudit"; #Set this to what you want the Data Collector Set to be called.
Write-Host "Running Perfmon-Collector to create / update Perfmon Data Collector Set $DCSName on $Server" -ForegroundColor Green
#Directory for the output Perfmon files.
$SubDir = "C:\PerfMon\PerfmonLogs"
# Location of the Scripts/Files. SQLAudit-Server.XML, SQLAudit-Instance.XML
$ScriptDir = (Resolve-Path .\).Path

#region DriveLetters
# inject the drive letter 'stuff' into the perfmon xml file.
# drive letter format:  0 C:
$DLETTERS = $Null
$DLETTERS = get-counter -listset PhysicalDisk | Select-Object -ExpandProperty PathsWithInstances | 
  Where-Object {$_ -like "*Disk Time*"} | Out-String

#Split the output into multiple lines on delimiters () and then exclude those containing # or \
$DLETTERS = $DLETTERS.split("(,)")
$DLETTERS = $DLETTERS | Select-String -Pattern "\\" -NotMatch

#Filter out the queues that we are not interested in
$DLETTERS = $DLETTERS | Where-Object {$_ -notlike "*_Total*"}

$Disk_Perfmon_Template = @"
<Counter>\PhysicalDisk($DRIVELETTER)\Avg. Disk Read Queue Length
<Counter>\PhysicalDisk($DRIVELETTER)\Avg. Disk sec/Read
<Counter>\PhysicalDisk($DRIVELETTER)\Avg. Disk sec/Write
<Counter>\PhysicalDisk($DRIVELETTER)\Avg. Disk Write Queue Length
<Counter>\PhysicalDisk($DRIVELETTER)\Disk Read Bytes/sec
<Counter>\PhysicalDisk($DRIVELETTER)\Disk Reads/sec
<Counter>\PhysicalDisk($DRIVELETTER)\Disk Write Bytes/sec
<Counter>\PhysicalDisk($DRIVELETTER)\Disk Writes/sec
"@

$out = $Null
$out = "
<PerformanceCounterDataCollector>
    <Counter>\Processor(*)\% Processor Time</Counter>
    <Counter>\System\Context Switches/sec</Counter>
    <Counter>\Memory\Cache Bytes</Counter>
    <Counter>\System\Processor Queue Length</Counter>
    <Counter>\Memory\Pages/sec</Counter>
    <Counter>\Memory\Pool Nonpaged Bytes</Counter>
    <Counter>\System\Threads</Counter>"

if ($DLETTERS)
{
    foreach($DRIVELETTER in $DLETTERS)
    {

        $out = $out + "
    <Counter>\PhysicalDisk($DRIVELETTER)\Avg. Disk Read Queue Length</Counter>
    <Counter>\PhysicalDisk($DRIVELETTER)\Avg. Disk sec/Read</Counter>
    <Counter>\PhysicalDisk($DRIVELETTER)\Avg. Disk sec/Write</Counter>
    <Counter>\PhysicalDisk($DRIVELETTER)\Avg. Disk Write Queue Length</Counter>
    <Counter>\PhysicalDisk($DRIVELETTER)\Disk Read Bytes/sec</Counter>
    <Counter>\PhysicalDisk($DRIVELETTER)\Disk Reads/sec</Counter>
    <Counter>\PhysicalDisk($DRIVELETTER)\Disk Write Bytes/sec</Counter>
    <Counter>\PhysicalDisk($DRIVELETTER)\Disk Writes/sec</Counter>"
    }
}
$out = $out + "`n</PerformanceCounterDataCollector>"

$out | Out-File -FilePath $ScriptDir\SQLAudit-Server.xml -Force -Encoding ascii
#endregion DriveLetters

#region SQLAudit-Instance.xml 
$SQLAuditInstance = "
<PerformanceCounterDataCollector>
    <Counter>\%instance%:SQL Statistics\Batch Requests/sec</Counter>
    <Counter>\%instance%:Buffer Manager\Page life expectancy</Counter>
    <Counter>\%instance%:Buffer Manager\Buffer cache hit ratio</Counter>
    <Counter>\%instance%:General Statistics\Processes blocked</Counter>
    <Counter>\%instance%:Buffer Manager\Database pages</Counter>
    <Counter>\%instance%:Buffer Manager\Lazy writes/sec</Counter>
    <Counter>\%instance%:Locks(_Total)\Average Wait Time (ms)</Counter>
    <Counter>\%instance%:Locks(_Total)\Lock Waits/sec</Counter>
    <Counter>\%instance%:Transactions\Longest Transaction Running Time</Counter>
    <Counter>\%instance%:Memory Manager\Memory Grants Pending</Counter>
    <Counter>\%instance%:Locks(_Total)\Number of Deadlocks/sec</Counter>
    <Counter>\%instance%:General Statistics\User Connections</Counter>
    <Counter>\%instance%:Buffer Manager\Page reads/sec</Counter>
    <Counter>\%instance%:Buffer Manager\Page writes/sec</Counter>
    <Counter>\%instance%:SQL Statistics\SQL Re-Compilations/sec</Counter>
    <Counter>\%instance%:Memory Manager\Total Server Memory (KB)</Counter>
    <Counter>\%instance%:Transactions\Transactions</Counter>
    <Counter>\%instance%:Databases(_Total)\Transactions/sec</Counter>
</PerformanceCounterDataCollector>
"
$SQLAuditInstance | Out-File -FilePath $ScriptDir\SQLAudit-Instance.xml -Force -Encoding ascii
#endregion 

# Create directories if they do not exist.
Invoke-Command -ComputerName $Server -ArgumentList $SubDir,$ScriptDir -ScriptBlock {
    param($SubDir,$ScriptDir)
    If (!(Test-Path -PathType Container $SubDir))
    {
        New-Item -ItemType Directory -Path $SubDir | Out-Null
    }
    If (!(Test-Path -PathType Container $ScriptDir))
    {
        New-Item -ItemType Directory -Path $ScriptDir | Out-Null
    }
}
 
# DataCollectorSet Check and Creation
$DCS = New-Object -COM Pla.DataCollectorSet
 
try # Check to see if the Data Collector Set exists
{
    $DCS.Query($DCSName,$Server)
}
# Need to catch both exceptions. Different O/S have different exceptions.
catch [System.Management.Automation.MethodInvocationException],[System.Runtime.InteropServices.COMException]
{
    Write-Host "Creating the $DCSName Data Collector Set" -ForegroundColor Green
    $DCS.DisplayName = $DCSName;
    $DCS.Segment = $true;
    $DCS.SegmentMaxDuration = 86400; # 1 day duration
    $DCS.SubdirectoryFormat = 1; # empty pattern, but use the $SubDir
    $DCS.RootPath = $SubDir;
 
    try #Commit changes
    {
        CommitChanges $DCS $DCSName
 
<#         Invoke-Command -ComputerName $Server -ArgumentList $DCSName -ScriptBlock {
            param($DCSName)
            $Trigger = @()
            #Start when server starts.
            $Trigger += New-ScheduledTaskTrigger -AtStartup
            #Restart Daily at 5AM. Note: I have not used Segments.
            $Trigger += New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday -at 05:00
            $Path = (Get-ScheduledTask -TaskName $DCSName).TaskPath
            #This setting in the Windows Scheduler forces the existing Data Collector Set to stop, and a new one to start
            $StopExisting = New-ScheduledTaskSettingsSet
            $StopExisting.CimInstanceProperties['MultipleInstances'].Value=3
            Set-ScheduledTask -TaskName $DCSName -TaskPath $Path -Trigger $Trigger -Settings $StopExisting | Out-Null
        } #>
        $DCS.Query($DCSName,$Server) #refresh with updates.
    }
    catch
    {
        Write-Host "Exception caught: " $_.Exception -ForegroundColor Red
        return
    }
}
 
#If updateDC parameter is supplied, Stop the existing data collectors and clear the data collectors from the data collector set.
 
If ($updateDC) {
    If ($DCS.Status -ne 0) {
        try {
                $DCS.Stop($true)
            }
        Catch {
                 Write-Host '-updateDC parameter was supplied but collectors did not stop successfully. Script exiting.' -ForegroundColor Red
                 Exit 1
            }
    }
    $DCS.DataCollectors.Clear()
    CommitChanges $DCS $DCSName
}
 
#DataCollector - SQLAudit-Server
$DCName = "$DCSName-Server";
 
# If the Data Collector does not exist, create it!
If (!(CheckCollector $DCS $DCName))
{
    Write-Host "Creating the $DCName Data Collector in the $DCSName Data Collector Set" -ForeGroundColor Green
    CreateCollectorServer $DCS $DCName
    CommitChanges $DCS $DCSName
}
 
#Data Collector - SQLAudit-Instances. Loop through installed instances and create collector for each if they do not exist.
$Instances = Get-SQLInstances -Server $Server
 
foreach ($Instance in $Instances) {
    If ($Instance -eq "MSSQLSERVER") {
        $ReplaceString = "SQLServer";
        }
        ELSE {
        $ReplaceString = "MSSQL`$$Instance";
        }
    $DCName = "$DCSName-$Instance";
 
    If (!(CheckCollector $DCS $DCName))
    {
        Write-Host "Creating the $DCName Data Collector in the $DCSName Data Collector Set" -ForeGroundColor Green
        CreateCollectorInstance $DCS $DCName $ReplaceString
        CommitChanges $DCS $DCSName
    }
}
 
# Start the data collector set.
try {
 
    If ($DCS.Status -eq 0) {
    $DCS.Start($true)
    Write-Host "Successfully created $DCSName and started the collectors." -ForeGroundColor Green
    }
}
catch {
    Write-Host "Exception caught: " $_.Exception -ForegroundColor Red
    return
}
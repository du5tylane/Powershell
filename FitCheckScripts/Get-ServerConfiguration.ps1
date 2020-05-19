<#
.SYNOPSIS
    Gather server configuration to assist with gather Fit Check data.
.DESCRIPTION
    This script will pull configuration settings from within the OS.  Run this script
    locally on the server to gather metrics

    This script gathers settings for CPU, Memory, Disk and Network settings, drivers, etc.
.EXAMPLE
    PS C:\Scripts> Get-ServerConfiguration.ps1 -ComputerName <Some_VMName>
    The script will write output to c:\reports.
.EXAMPLE
    Get-ServerConfiguration.ps1 -ComputerName <Some_VMName> -ReportPath <full_path_to_report_folder>

    PS C:\Scripts> Get-ServerConfiguration.ps1 -ComputerName SQL1 -ReportPath d:\MyReports

    The script will write output to d:\MyReports instead of the default c:\reports
.NOTES
    Author:  Dusty Lane
    Created:  04/20/2020
    Version:  0.5
#>


Param(
    [Parameter(Mandatory=$false)]
    [string]$ComputerName = $env:computername,
    [Parameter(Mandatory=$false)]
    [string]$ReportPath = "c:\reports"
)

if (test-path $ReportPath)
{
    Write-Output "Report folder already exists"
}else{
    mkdir $ReportPath
}


$working_path = (Resolve-Path .\).Path
if (!(test-path $working_path\coreinfo.exe))
{
    Invoke-WebRequest -Uri https://download.sysinternals.com/files/Coreinfo.zip -OutFile $working_path\Coreinfo.zip
    Expand-Archive -Path $working_path\coreinfo.zip -DestinationPath $working_path
}

if(!(Test-Path "HKCU:\Software\Sysinternals\Coreinfo"))
{
    New-Item -Path "HKCU:\Software\Sysinternals\Coreinfo" -Force | Out-Null
    New-ItemProperty -Path "HKCU:\Software\Sysinternals\Coreinfo" -Name "EulaAccepted" -Value "00000001" -PropertyType DWORD -Force | Out-Null
}else{
    New-ItemProperty -Path "HKCU:\Software\Sysinternals\Coreinfo" -Name "EulaAccepted" -Value "00000001" -PropertyType DWORD -Force | Out-Null
}

#region MainServerConfigurations
$OS = Get-WmiObject -Class win32_operatingsystem | Format-Table Caption,OSArchitecture,Version -Autosize | out-string
$CoreInfo = (.\coreinfo.exe -n) + "`n"| Out-String
$Memory = ((get-ciminstance -class "cim_physicalmemory" | % {$_.Capacity})/1024/1024) | out-string
$TCPChimney = (cmd /c "netsh int tcp show global") | Out-String
$SoftwareList = Get-WmiObject -Class Win32_Product | Format-Table Name, Version -AutoSize | out-string
$DiskInfo = Get-WmiObject -ComputerName $ComputerName -Class Win32_Volume | Select-Object DriveLetter, Label, BlockSize, Capacity, Freespace | Format-Table -AutoSize | out-string
$nics = get-netadapter
# Begin sifting throuh the objects and formatting to write to a txt file.
$Output = $null
$Output = "`nHostname:  $($env:ComputerName) `n"
$Output = $Output + $OS
$Output = $Output + $CoreInfo
$Output = $Output + "######## Memory (MB): $($Memory)`n"
$Output = $Output + "######## Network Cards(s):"

ForEach ($nic in $Nics)
{
    $Output = $Output + "$($nic | format-table ifAlias,ifDesc,DriverProvider,driverinformation,MtuSize -AutoSize | out-string)"
}


$Output = $Output + $TCPChimney

$Output = $Output + "######## Drive Information: $($DiskInfo)"

$Output = $Output + "######## Software Information: $($SoftwareList)"

#endregion MainServerConfigurations


#region SQLSettings

$SQLServiceCheck = Get-Service MSSQLSERVER -Erroraction Ignore

if ($SQLServiceCheck)
{
    $Output = $Output + "################  SQL Server Configuration: ################  "
    
    $QuerySQLVer = "SELECT @@VERSION AS 'SQL Server Version';  "
    
    $QueryDBs = "select name from sys. databases WHERE name NOT IN ('master', 'tempdb', 'model', 'msdb')"

    $QueryMem = "SELECT name, value, value_in_use, [description] FROM sys.configurations WHERE name like '%server memory%' ORDER BY name OPTION (RECOMPILE);"

    $QueryDBLocations = "SELECT db.name AS DBName,type_desc AS FileType,Physical_Name AS Location FROM sys.master_files mf INNER JOIN sys.databases db ON db.database_id = mf.database_id"

    $QueryDBAutogrow = "exec sp_MSforeachdb 'use [?]; EXEC sp_helpfile'"

    $SQLVer = Invoke-SQLCMD -ServerInstance $ComputerName -Query $QuerySQLVer
    $SQLMem = Invoke-SQLCMD -ServerInstance $ComputerName -Query $QueryMem
    $SQLDBs = Invoke-SQLCMD -ServerInstance $ComputerName -Query $QueryDBs
    $SQLDBLocations = Invoke-SQLCMD -ServerInstance $ComputerName -Query $QueryDBLocations
    $SQLDBAutogrow = Invoke-SQLCMD -ServerInstance $ComputerName -Query $QueryDBAutogrow | ft name, filename,size,growth,maxsize -AutoSize

    $Output = $Output + "######## SQL Version: $($SQLVer| Out-string)"
    $Output = $Output + "######## SQL Memory: $($SQLMem | Out-string)"
    $Output = $Output + "######## SQL DB Locations: $($SQLDBLocations | Out-string)"
    $Output = $Output + "######## SQL datafile settings: $($SQLDBAutogrow | Out-string)"
}
#endregion SQLSettings


# Write the output (overwrite if the file already exists)
$Output | Out-File "$ReportPath\$($ComputerName)_Configuration.txt" -Encoding ascii -Force


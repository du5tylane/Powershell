 
<#
.SYNOPSIS
    Gather server configuration to assist with gather Fit Check data.
.DESCRIPTION
    This script will pull configuration settings from within the OS. It can be ran from any server.

    This script gathers settings for CPU, Memory, Disk and Network settings, drivers, and performs a SQL Assessment.

    An output script will be used to format the data gathered at this time no data is outputted

    Please add in your variables in the declare variable section.

.NOTES
    Author:  Matthew Foster 
    Co-Contributor Dusty Lane
    Created:  10/10/2020
    Version:  1.0
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


#Declare Variables
$Return =@()
$SQLServer = "$ComputerName"
$FitPath = "$ReportPath"
#$UserName = ""
#$Password = ""
#$SEC_PASS = ConvertTo-SecureString -String $Password -AsPlainText -Force
$Credential = Get-Credential -Message "Enter credential with SQL permissions"
#New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $Username, $SEC_PASS

$SQLFitScript ={ 
#Create Function
Function Create-SQLFitCheck {
[hashtable]$return =@{}
   $SQLServiceCheck = Get-Service MSSQLSERVER -Erroraction Ignore

    if ($SQLServiceCheck)
        {

            $AssessmentModule = Get-Command -Module SqlServer -Name *sqlassessment*

                if (!$AssessmentModule){

                #set strong cryptography on 64 bit .Net Framework
                Set-ItemProperty -Path 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NetFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Value '1' -Type DWord

                #set strong cryptography on 32 bit .Net Framework
                Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\.NetFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Value '1' -Type DWord

                #Install Require Nuget Package
                Install-PackageProvider -Name NuGet -Force

                #Install Moddule 
                Install-Module -Name PowerShellGet -Force

                #Get Module SQLServer
                Get-Module SQLServer 

                #Install SQLServer Module
                Install-Module -Name SqlServer -Force -AllowClobber 
                }

          

          $SQLAssessmentItems = Get-SqlInstance -ServerInstance localhost | Get-SqlAssessmentItem | Out-String
          $SQLAssessment = get-sqlinstance -ServerInstance localhost | Invoke-SqlAssessment | out-string

          $return.SQLAssessmentItems = $SQLAssessmentItems
          $return.SQLAssessment = $SQLAssessment

          return $return
        }

}
    $Results = Create-SQLFitCheck
    $Results.SQLAssessmentItems
    $Results.SQLAssessment
}

$MEMScript = {
#Discover Computer Memory
Function Get-ComputerMemory {
    $mem = Get-WMIObject -class Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
return ($mem.Sum / 1MB);
}
    $Memory = Get-ComputerMemory
    $Memory
}

$ComputerScript = {
Function Get-ComputerInfo {
[hashtable]$return =@{}
    
    $OS = Get-WmiObject -Class win32_operatingsystem | Format-Table Caption,OSArchitecture,Version -Autosize | out-string
    $SoftwareList = Get-WmiObject -Class Win32_Product | Format-Table Name, Version -AutoSize | out-string
    $DiskInfo = Get-WmiObject -Class Win32_Volume | Select-Object Name, Label, BlockSize, Capacity, Freespace | Format-Table -AutoSize | out-string
    $cs = Get-WmiObject -class Win32_ComputerSystem
    $Sockets=$cs.numberofprocessors
    $cores = $cs.NumberOfLogicalProcessors
    $OS = Get-WmiObject -class Win32_OperatingSystem
    $bitlevel = $OS.OSArchitecture
    $bitlevel = $bitlevel.trim("-bit")


$return.sockets = $sockets
$return.Cores = $cores
$return.bitlevel = $bitlevel
$return.diskinfo = $diskinfo
$return.OS = $OS
$return.Softwarelist = $SoftwareList

return $return
}
    $Results = Get-ComputerInfo
    $Results.sockets
    $Results.cores
    $Results.bitlevel
    $Results.diskinfo
    $Results.os
    $Results.Softwarelist
}

$NetworkScript = {

Function Get-NetworkCheck {

[hashtable]$return =@{}

$nics = get-netadapter
$TCPChimney = (cmd /c "netsh int tcp show global") | Out-String

ForEach ($nic in $Nics)
{
    $Output = $Output + "$($nic | format-table ifAlias,ifDesc,DriverProvider,driverinformation,MtuSize -AutoSize | out-string)"
}

$return.output = $Output
$return.TCPChimney = $TCPChimney

return $return

}

    $Results = Get-NetworkCheck
    $Results.output
    $Results.TCPChimney
}

$SQlRegionalScript = {

    Function Get-SQLRegionalSettings {
    
    [hashtable]$return =@{}
    
    $SQLServiceCheck = Get-Service MSSQLSERVER -Erroraction Ignore

    if ($SQLServiceCheck)
        {
    
            $QuerySQLVer = "SELECT @@VERSION AS 'SQL Server Version';  "
    
            $QueryDBs = "select name from sys. databases WHERE name NOT IN ('master', 'tempdb', 'model', 'msdb')"

            $QueryMem = "SELECT name, value, value_in_use, [description] FROM sys.configurations WHERE name like '%server memory%' ORDER BY name OPTION (RECOMPILE);"

            $QueryDBLocations = "SELECT db.name AS DBName,type_desc AS FileType,Physical_Name AS Location FROM sys.master_files mf INNER JOIN sys.databases db ON db.database_id = mf.database_id"

            $QueryDBAutogrow = "exec sp_MSforeachdb 'use [?]; EXEC sp_helpfile'"

            $QueryNUMANode = "SELECT memory_node_id FROM sys.dm_os_memory_nodes" 

            $SQLVer = Invoke-SQLCMD -Query $QuerySQLVer | Out-String
            $SQLMem = Invoke-SQLCMD -Query $QueryMem | Out-String
            $SQLDBs = Invoke-SQLCMD -Query $QueryDBs | Out-String
            $SQLDBLocations = Invoke-SQLCMD -Query $QueryDBLocations | Out-String
            $SQLDBAutogrow = Invoke-SQLCMD -Query $QueryDBAutogrow | ft name, filename,size,growth,maxsize -AutoSize | Out-String
            $SQLNUMANode = Invoke-SQLCMD -Query $QueryNUMANode | Out-String

      
        }

$return.SQLVersion = $SQLVer
$return.SQLMem = $SQLMem
$return.SQLNUMANode = $SQLNUMANode
$return.SQLDBs = $SQLDBs
$return.SQLDBLocations = $SQLDBLocations
$return.SQLDBAutogrow = $SQLDBAutogrow


return $return
}

    $Results = Get-SQLRegionalSettings
    $Results.SQLVersion
    $Results.SQLMem
    $Results.SQLNUMANode
    $Results.SQLDBs
    $Results.SQLDBLocations
    $Results.SQLDBAutogrow
    
}

function get-SQlMemoryConfig {

    [cmdletbinding()]


Param(
    [ValidateNotNullorEmpty()]
    [int]$CPUCores,
    [ValidateNotNullorEmpty()]
    [INT]$MemoryMB,
    [ValidateNotNullorEmpty()]
    [String]$OSBitLevel,
    [ValidateNotNullorEmpty()]
    [INT]$CPUs,
    [ValidateNotNullorEmpty()]
    [INT]$OSReserveMemMB

)

$SQLThreads = ""
$ThreadStack = ""

if ($OSBitLevel -eq 32 -and $CPUs -le 4){
$SQLThreads = 256
}
if ($OSBitLevel -eq 32 -and $CPUs -gt 4){
$SQLThreads = 256 + (($CPUCores - 4) * 16)
}
if ($OSBitLevel -eq 64 -and $CPUs -le 4){
$SQLThreads = 512
}
if ($OSBitLevel -eq 64 -and $CPUs -gt 4){
$SQLThreads = 512 + (($CPUCores - 4) * 16)
}

if ($OSBitLevel -eq 32){
$ThreadStack = 2
}
if ($OSBitLevel -eq 64){
$ThreadStack = .5
}


$MaxMemory = $MemoryMB - $OSReserveMemMB - (250 * $CPUCores) - ($SQLThreads * $ThreadStack)

return $MaxMemory

}

try {
    $Memory = Invoke-Command -ComputerName $SQLServer -ScriptBlock $MEMScript -Credential $Credential
    $ComputerInfo = Invoke-Command -ComputerName $SQLServer -ScriptBlock $ComputerScript -Credential $Credential
    $NICinfo = Invoke-Command -ComputerName $SQLServer -ScriptBlock $NetworkScript -Credential $Credential
    $SQLinfo = Invoke-Command -ComputerName $SQLServer -ScriptBlock $SQlRegionalScript -Credential $Credential
    $SQLFitCheck = Invoke-Command -ComputerName $SQLServer -ScriptBlock $SQLFitScript -Credential $Credential
}
catch {
    Write-Host $Error[0]
    break
}
#Get Operating System

$Operating_System = $ComputerInfo[4]

#Processor Information
$CPUs = $ComputerInfo[0]
$CPUCores = $ComputerInfo[1]
$OSbitlevel = $ComputerInfo[2]

#Get Network Information
$TCPChimneyInfo = $NICinfo[1]
$NetworkInterface = $NICinfo[0]

#Get Memory 
$MaxMemory = get-SQlMemoryConfig -CPUCores $CPUCores -MemoryMB $Memory -OSBitLevel $OSbitlevel -CPUs $CPUs -OSReserveMemMB 4096

#Get DiskInfo
$DiskInfo = $ComputerInfo[3]

#Get SQL Server Version info

$SQLVersion = $SQLinfo[0]

#Get SQL Set Min\Max Memory Allocations

$MINMAX_MEM_Info = $SQLinfo[1]

#Get NUMA Nodes

$NUMA_NODES = $SQLinfo[2]

#Get SQL DBs

$SQL_DBs = $SQLinfo[3]

#Get DQL DBs Locations

$SQL_DBs_Locations = $SQLinfo[4] 

#Get SQL DBs Autogrow Information

$SQL_DBs_AutoGrow = $SQLinfo[5] 

#Get Installed Software List

$Installed_Software = $ComputerInfo[5] 

#Get FitCheck

$Fitcheck_items = $SQLFitCheck[0] | Out-File "$($ReportPath)\SQLFinding_Good.txt"
$Fitcheck_issues = $SQLFitCheck[1] | Out-File "$($ReportPath)\SQLFinding_Issues.txt"


$ComputerInfo | Out-File "$($ReportPath)\SQLFinding_ComputerInfo.txt"
$SQLinfo | Out-File "$($ReportPath)\SQLFinding_SQLInfo.txt"
$SQLFitCheck


 

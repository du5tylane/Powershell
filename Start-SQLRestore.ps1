#requires -version 4 -Modules SQLServer
<#
.SYNOPSIS
    This script will restore a named database from a named file share.
.DESCRIPTION
    This script will restore SQL Server databases using PowerShell, TSQL and 
    DBATools (dbatools.io).  

    To use this tool, the operator should have SA rights on the SQL Instance.

.PARAMETER Source
    This is the name of the source SQL Instance.  It needs to be able to
    be resolved via DNS.  Port 1433 also needs to be accessible.
.PARAMETER Destination
    This is the name of the destination SQL Instance.  It needs to be able to
    be resolved via DNS.  Port 1433 also needs to be accessible.
.PARAMETER BackupPath
    This parameter is the UNC Path to the backup folder.  The destination SQL
    instance must have read access to the unc path.
.PARAMETER Databases
    The names (comma seperated) of any databases that are to be backed up.
.PARAMETER SourceInstanceName
    If the SQL instance is not running in the default namespace, enter
    the name of the instance.
.PARAMETER DestinationInstanceName
    If the SQL instance is not running in the default namespace, enter
    the name of the instance.
.NOTES
    Version:        0.1
    Author:         Dusty Lane
    Creation Date:  06/12/2020
    Modified Date:  06/12/2020
    Purpose/Change: Initial script development
    Source:         https://github.com/du5tylane/Powershell/blob/master/Start-SQLRestore.ps1

  
.EXAMPLE
    .\Start-SQLrestore.ps1 -Source <SQL Source Server> -BackupPath "\\nas1\backups" -Databases DB1,DB2
#>

Param(
    [Parameter(Mandatory=$true,HelpMessage="Enter the name of the Computer running SQL Server.")]
    [ValidateScript({Test-NetConnection -ComputerName $_ -Port 1433})] 
    [string]$Source,
    [Parameter(Mandatory=$true,HelpMessage="Enter the name of the Computer running SQL Server.")]
    [ValidateScript({Test-NetConnection -ComputerName $_ -Port 1433})] 
    [string]$Destination,
    [Parameter(Mandatory=$true,HelpMessage="Enter the backup path in UNC format, leaving off the trailing slash")]
    [ValidateScript({Test-Path $_})] 
    [string]$BackupPath,
    [Parameter(Mandatory=$true,HelpMessage="List the database to be restored up.  Seperate multiple databases with a comma.")]
    [Alias('Database')]
    [string[]]$Databases,
    [Parameter(Mandatory=$false,HelpMessage="Enter the instance name")]
    [string]$SourceInstanceName,
    [Parameter(Mandatory=$false,HelpMessage="Enter the instance name")]
    [string]$DestinationInstanceName
)

Clear-Host

# adding a bunch of white space so that it does not interfere with
# the test banner.
Write-Host "










#########################################################################
#                                                                       #
#    This tool was developed by Nutanix Professional Services.          #
#    It is intended to automate the restore of databases and objects     #
#    in SQL Server.  It leverages Native and 3rd party PowerShell       #
#    commands to streamline this process.  For additional information,  #
#    look at the source code.  This tool is provided as-is without      #
#    any warranty expressed or implied.                                 #
#                                                                       #
#########################################################################
    " -ForegroundColor Cyan

######################################## 
#####           restore            ##### 
######################################## 

try {
    foreach ($DB in $Databases)
    {
        # we need to check and see if the backup exists.
        try {
            Test-Path "$BackupPath\$DB.bak" -ErrorAction Stop
        }
        catch {
            Write-Host "Database backup file ($($DB).bak) does not exist at location $BackupPath"
        }
        
        if ($DestinationInstanceName)
        {
            Restore-SqlDatabase -ServerInstance "$Destination\$DestinationInstanceName" -Database $DB -BackupFile "$BackupPath\$DB.bak"
        }
        else
        {
            Restore-SqlDatabase -ServerInstance $Destination -Database $DB -BackupFile "$BackupPath\$DB.bak"
        }
    } 
}
catch {
    Write-Host "Error encountered Restoring the database, $DB"
}

# dbatools makes it so much easier to copy\export logins....
if (get-command Copy-DbaLogin)
{
}
else
{
    Write-Host "Installing tools, standby" -ForegroundColor Cyan
    $tools = Install-Module dbatools -Force
    $tools.$null
}

# the copy-dbalogin command fails to return to the script.
# I am using powershell to start a new process for 
# copy-dbalogin so that the script can continue.

Write-Host "Copying SQL Logins" -ForegroundColor Cyan
$command = "Copy-DbaLogin -Source $Source -Destination $Destination -ExcludeSystemLogins"
powershell.exe -command $command

if (Get-DBALinkedServer $Source)
{
    Write-Host "Copying Linked Servers" -ForegroundColor Cyan
    $LSCommand = "Copy-DbaLinkedServer -Source $Source -Destination $Destination"
    powershell.exe -command $LSCommand
}

Write-Host "Copying SQL Agent Jobs" -ForegroundColor Cyan
$AgentJobs = "Copy-DbaAgentJob -Source $Source -Destination $Destination"
powershell.exe -command $AgentJobs

Write-Host "

Database(s) for $Source have been restored from $BackupPath.  Please review
and\or validate the databases prior to making putting into production.

" -ForegroundColor Green
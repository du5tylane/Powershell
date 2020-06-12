#requires -version 4 -Modules SQLServer
<#
.SYNOPSIS
    This script will backup a named database to a named file share.
.DESCRIPTION
    This script will backup SQL Server databases using PowerShell, TSQL and 
    DBATools (dbatools.io).  The backups will be compressed, unencrypted
    in the destination folder.

    To use this tool, the operator should have SA rights on the SQL Instance.

.PARAMETER Source
    This is a name of the SQL Instance.  It needs to be able to
    be resolved via DNS.  Port 1433 also needs to be accessible.
.PARAMETER BackupPath
    This parameter is the UNC Path to the backup folder.  The source SQL
    instance must have write access to the unc path.
.PARAMETER Databases
    The names (comma seperated) of any databases that are to be backed up.
.PARAMETER InstanceName
    If the SQL instance is not running in the default namespace, enter
    the name of the instance.
.NOTES
    Version:        0.2
    Author:         Dusty Lane
    Creation Date:  06/11/2020
    Modified Date:  06/11/2020
    Purpose/Change: Initial script development
    Source:         https://github.com/du5tylane/Powershell/blob/master/Start-SQLBackup.ps1

    The goal of this tool is to ultimately back up databases, SQL Logins, 
    Linked Servers, agent jobs, SPs, maintenance plans, and custom roles.

    .1 release only backs up databases and sql logins.
  
.EXAMPLE
    .\Start-SQLBackup.ps1 -Source <SQL Source Server> -BackupPath "\\nas1\backups" -Databases DB1,DB2
#>

Param(
    [Parameter(Mandatory=$true,HelpMessage="Enter the name of the Computer running SQL Server.")]
    [ValidateScript({Test-NetConnection -ComputerName $_ -Port 1433})] 
    [string]$Source,
    [Parameter(Mandatory=$true,HelpMessage="Enter the backup path in UNC format, leaving off the trailing slash")]
    [ValidateScript({Test-Path $_})] 
    [string]$BackupPath,
    [Parameter(Mandatory=$true,HelpMessage="List the database to be backed up.  Seperate multiple databases with a comma.")]
    [Alias('Database')]
    [string[]]$Databases,
    [Parameter(Mandatory=$false,HelpMessage="Enter the instance name")]
    [string]$InstanceName
)

Clear-Host

# adding a bunch of white space so that it does not interfere with
# the test banner.
Write-Host "










#########################################################################
#                                                                       #
#    This tool was developed by Nutanix Professional Services.          #
#    It is intended to automate the backup of databases and objects     #
#    in SQL Server.  It leverages Native and 3rd party PowerShell       #
#    commands to streamline this process.  For additional information,  #
#    look at the source code.  This tool is provided as-is without      #
#    any warranty expressed or implied.                                 #
#                                                                       #
#########################################################################
    " -ForegroundColor Cyan

# before looping through each database, I want to test and make sure
# that we have write access to the file share.  Now, this is
# really just an arbitrary test, as the SQL server really needs
# access to the file share, not the account running this script.

try 
{
    # test write capability
    Get-Date | Out-File -FilePath "$BackupPath\test.txt" -Encoding ascii -Force -ErrorAction Stop
    Remove-Item -Path "$BackupPath\test.txt" -Force -ErrorAction Stop
}
catch
{
    Write-Host "Unable to write files to the path: $BackupPath" -ForegroundColor Red

    break
}


######################################## 
#####           Backup             ##### 
######################################## 

try {
    foreach ($DB in $Databases)
    {
        if ($InstanceName)
        {
            Backup-SqlDatabase -ServerInstance "$($Source)\$($InstanceName)" -CompressionOption On -BackupFile "$BackupPath\$DB.bak" -Database $DB -CopyOnly -Initialize
        }
        else
        {
            Backup-SqlDatabase -ServerInstance $source -CompressionOption On -BackupFile "$BackupPath\$DB.bak" -Database $DB -CopyOnly -Initialize
        }
    } 
}
catch {
    Write-Host "Error encountered backing up the database, $DB"
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

$command = "Copy-DbaLogin -Source $Source -ExcludeSystemLogins -OutFile `"$BackupPath\$($Source)_Logins_Backup.txt`""
powershell.exe -command $command


Write-Host "

Database(s) for $Source have been backed up to $BackupPath.  Please review
and\or validate the backups prior to making any production changes.

" -ForegroundColor Green
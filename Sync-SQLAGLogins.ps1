#requires -version 5
<#
.SYNOPSIS
    This script will synchronize logins between sql AG nodes.
.DESCRIPTION
    Using 3rd party module, DBATools, this script will check for the presense of dbatools
    if not present, it will download the module and install it.  Then it will check for the 
    role of primary.  If primary, it will synchronize logins between the other nodes.
.PARAMETER <null>
    placeholder
.NOTES
    Version:        1.0
    Author:         Dusty Lane
    Creation Date:  10/1/2018
    Modified Date:  06/11/2020
    Purpose/Change: Initial script development
  
.EXAMPLE
    .\Sync-SQLAGLogins.ps1
#>

#region ================== Basic Settings =============
$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
Write-Verbose "My directory is $dir"
Push-location $dir

# we need some way to get a username and password to run as...  This could be addressed
# differently in the future...  maybe credential manager?
$ssPass = Get-Content .\ss.txt | ConvertTo-SecureString -key (Get-Content .\20181002.key)
$ssUser = Get-Content .\ssUser.txt |  ConvertTo-SecureString -key (Get-Content .\20181002.key)

$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ssUser)
$User = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

$Cred = New-Object System.Management.Automation.PSCredential($User,$ssPass)
#endregion ================== Basic Settings =============

#region ================== SQL Ver Check =============
# no sense running on versions of sql that do not support AGs.

$inst = (get-itemproperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server').InstalledInstances
foreach ($i in $inst)
{
   $p = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL').$i
   $version = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$p\Setup").Version
}

# checking for sql 2016 and above.
if ($version -lt 13)
{
    write-verbose "script only supports sql 2016 and above"
    Exit
}

#endregion ===========================================

#region ================== Sync SQL Logins ===========

# get the list of availability groups
try {
    $AGs = (Get-DbaAvailabilityGroup -SqlInstance $env:COMPUTERNAME -ErrorAction Stop).availabilitygroup | Get-Unique
}
catch
{
    Write-Verbose "SQL AlwaysOn Not configured"
    exit
}


# if there is more than one availability group.
foreach ($AG in $AGs)
{
    $Primary = (Get-DbaAvailabilityGroup -SqlInstance $env:COMPUTERNAME -AvailabilityGroup $AG).primaryreplica

    if ($Primary -eq $env:COMPUTERNAME)
    {
        # build list of logins to be excluded from sync.
        $excludelogins = @(get-dbalogin -SqlInstance $env:COMPUTERNAME | Where-Object {$_.name -like "*srvc*"}).name
        $excludelogins += "$($env:userdomain)\Domain Admins"
        # get the list of nodes in the availabiltiy group
        $Nodes = $((Get-DbaAvailabilityGroup -SqlInstance $env:COMPUTERNAME -AvailabilityGroup $AG)).AvailabilityReplicas.name | where-object {$_ -ne $primary}

        foreach ($node in $Nodes)
        {
            # copy\sync the sql logins from the primary to the secondary node.
            Copy-DbaLogin -Source $env:COMPUTERNAME -Destination $node -SourceSqlCredential $Cred -DestinationSqlCredential $Cred -ExcludeLogin $excludelogins -Force -ExcludeSystemLogin -KillActiveConnection
        }
    }else {
        Write-Verbose "This node is not the primary replica"
    }
}
#endregion ===========================================
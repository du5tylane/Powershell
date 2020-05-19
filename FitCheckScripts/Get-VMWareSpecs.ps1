<#
.SYNOPSIS
    Gather Virtual Machine configuration
.DESCRIPTION
    This script will install PowerCli.  It should be run from a workstation that
    can connect to vCenter.  The script will write data to c:\reports.  The report
    is a few KB in size. Copy the script to c:\scripts and run.

    This script gathers settings for CPU, Memory, Disk and Network
.EXAMPLE
    PS C:\Scripts> Get-VMWareSpecs.ps1 -ComputerName <Some_VMName> -vcenter <IP_or_FQDN_of_vcenter>
    The script will write output to c:\reports.
.EXAMPLE
    Get-VMWareSpecs.ps1 -ComputerName <Some_VMName> -vcenter <IP_or_FQDN_of_vcenter> -ReportPath <full_path_to_report_folder>

    PS C:\Scripts> Get-VMWareSpecs.ps1 -ComputerName SQL1 -vcenter vcenter.contoso.com -ReportPath d:\MyReports

    The script will write output to d:\MyReports instead of the default c:\reports
.NOTES
    Author:  Dusty Lane
    Created:  04/20/2020
    Version:  0.5
#>


Param(
    [Parameter(Mandatory=$false)]
    [string]$ComputerName,
    [Parameter(Mandatory=$false)]
    [string]$vcenter,
    [Parameter(Mandatory=$false)]
    [string]$ReportPath = "c:\reports"
)

# Testing - remove this line for 'regular use'.
# $vcenter = "172.16.2.183"

if (test-path $ReportPath)
{
    Write-Output "Report folder already exists"
}else{
    mkdir $ReportPath
}

if (Get-Module VMware.VimAutomation.Core)
{}else{
    Install-Module vmware.powercli -Force -AllowClobber -Confirm:$false
}

Set-PowerCLIConfiguration -Scope User -InvalidCertificateAction Ignore -ParticipateInCEIP $false -confirm:$false
$cred = Get-Credential
connect-viserver $vcenter -credential $cred

# Need to create the objects that we pull data from
$VM = get-vm $ComputerName
$Nics =  $(Get-NetworkAdapter -VM $Computername)
$Controllers = $(Get-ScsiController -VM $Computername)

# Begin sifting throuh the objects and formatting to write to a txt file.
$Output = $null
$Output = $VM | Format-Table Name,NumCpu,CoresPerSocket,MemoryGB,HardwareVersion,VMResourceConfiguration -AutoSize

$Output = $Output + "######## CPU HotAdd Enabled`n $($vm.ExtensionData.config.CpuHotAddEnabled | out-string)"

$GuestTools = $vm.ExtensionData.guest
$Output = $Output + "######## Guest Tools`n $($GuestTools | Format-table ToolsStatus,ToolsVersion,ToolsVersionStatus,GuestFullName | out-string)"

$Output = $Output + "######## Network Cards(s):"

ForEach ($nic in $Nics)
{
    $Output = $Output + "$($nic | format-table Name,Type,MacAddress,NetworkName -AutoSize | out-string)"
}

$Output = $Output + "######## Disk Layout `n`n $($VM.ExtensionData.layout.disk | out-string)"

$Output = $Output + "######## Storage Controller(s):"


ForEach ($Controller in $Controllers)
{
    $Output = $Output + "$($controller.ExtensionData.deviceinfo | Format-Table -AutoSize | Out-String)"
    $Output = $Output + "Disks Assigned to $($controller.ExtensionData.deviceinfo.label | Out-String)$($controller.ExtensionData.device | Out-String)"
}

# Write the output (overwrite if the file already exists)
$Output | Out-File "$ReportPath\$($ComputerName)_VM_Specifications.txt" -Encoding ascii -Force




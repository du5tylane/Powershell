#requires -version 4
<#
    .SYNOPSIS
        Simple Script to change the CDROM drive letter
    .DESCRIPTION
        This script leverages the WMI command (if there are multiple CDs),
        selects the first object in the array and then assigns a 
        specific letter to that device.
    .NOTES
        Version:        1.0
        Author:         Dusty Lane
        Creation Date:  03/20/2020
        Purpose/Change: Initial script development
  
#>
# change drive letter of CD
Write-Host "Changing drive letter for cdrom" -ForegroundColor Green
Get-WmiObject -Class Win32_volume -Filter 'DriveType=5' | Select-Object -First 1 | Set-WmiInstance -Arguments @{DriveLetter='B:'}
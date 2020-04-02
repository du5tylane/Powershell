#requires -version 4
<#
    .SYNOPSIS
        Installs SQL Server Management Studio
    .DESCRIPTION
        SSMS has some issues with installing via command line.
        Using the start-process commandlet appears to work more
        reliably than other approaches.

    .NOTES
        Version:        1.0
        Author:         Dusty Lane
        Creation Date:  04/02/2020
        Purpose/Change: Initial script development
  
#>

$FilePath = "C:\SQLMEDIA"

Start-Process -FilePath "$($FilePath)\SSMS-Setup-ENU.exe" -ArgumentList "/install /quiet" -Wait -Verb RunAs
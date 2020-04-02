#requires -version 4
<#
    .SYNOPSIS
        Simple Script to install prerequisites for SQL AAG
    .DESCRIPTION
        This is one of the scripts in a series of scripts
        that is intended for use in an automation sequence to 
        confiugre SQL Always On.

        This script specifically sets the firewall rules

    .NOTES
        Version:        1.0
        Author:         Dusty Lane
        Creation Date:  04/02/2020
        Purpose/Change: Initial script development
  
#>

New-NetFirewallRule -DisplayName "SQL Server" -Direction Inbound -Protocol TCP -LocalPort 1433 -Action allow
New-NetFirewallRule -DisplayName "SQL Admin Connection" -Direction Inbound -Protocol TCP -LocalPort 1434 -Action allow
New-NetFirewallRule -DisplayName "SQL Database Management" -Direction Inbound -Protocol UDP -LocalPort 1434 -Action allow
New-NetFirewallRule -DisplayName "SQL Service Broker" -Direction Inbound -Protocol TCP -LocalPort 4022 -Action allow
New-NetFirewallRule -DisplayName "SQL Debugger/RPC" -Direction Inbound -Protocol TCP -LocalPort 135 -Action allow
New-NetFirewallRule -DisplayName "SQL Browser" -Direction Inbound -Protocol TCP -LocalPort 2382 -Action allow
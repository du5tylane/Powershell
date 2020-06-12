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
        Version:        1.1
        Author:         Dusty Lane
        Creation Date:  06/09/2020
        Purpose/Change: add AAG port
  
#>

New-NetFirewallRule -DisplayName "SQL Server - TCP 1433" -Direction Inbound -Protocol TCP -LocalPort 1433 -Action allow
New-NetFirewallRule -DisplayName "SQL Admin Connection - TCP 1434" -Direction Inbound -Protocol TCP -LocalPort 1434 -Action allow
New-NetFirewallRule -DisplayName "SQL Database Management - UDP 1434" -Direction Inbound -Protocol UDP -LocalPort 1434 -Action allow
New-NetFirewallRule -DisplayName "SQL Service Broker - TCP 4022" -Direction Inbound -Protocol TCP -LocalPort 4022 -Action allow
New-NetFirewallRule -DisplayName "SQL Debugger-RPC - TCP 135" -Direction Inbound -Protocol TCP -LocalPort 135 -Action allow
New-NetFirewallRule -DisplayName "SQL Browser - TCP 2382" -Direction Inbound -Protocol TCP -LocalPort 2382 -Action allow
# this next rule may need to be updated if the port is changed
New-NetFirewallRule -DisplayName "SQL AAG - TCP 5022" -Direction Inbound -Protocol TCP -LocalPort 5022 -Action allow
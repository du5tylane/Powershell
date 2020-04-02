#requires -version 4
<#
    .SYNOPSIS
        Simple Script to install prerequisites for SQL AAG
    .DESCRIPTION
        This is the first script in a series of scripts
        that is intended for use in an automation sequence to 
        confiugre SQL Always On
    .NOTES
        Version:        1.0
        Author:         Dusty Lane
        Creation Date:  04/02/2020
        Purpose/Change: Initial script development
  
#>
#
# install pre-requirements for SQL always on
Add-WindowsFeature NET-FRAMEWORK-45-CORE,failover-clustering,rsat-clustering-powershell,rsat-clustering-cmdinterface -restart



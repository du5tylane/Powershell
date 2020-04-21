#
# hypervisor.cpuid.v0 = “FALSE”
# mce.enable = “TRUE”
# vhv.enable = “TRUE”
#


Install-WindowsFeature Failover-Clustering,Hyper-V,RSAT-Hyper-V-Tools -IncludeAllSubFeature -IncludeManagementTools -restart

New-VMSwitch -Name "ExternalSwitch" -NetAdapterName "Ethernet0" -AllowManagementOS

# Server-Gui-Shell, Server-Gui-Mgmt-Infra
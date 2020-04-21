
$working_path = (Resolve-Path .\).Path



# ----------- zabbix server download ----------- #
# this is a qcow2 file - for use with AHV\KVM.  Might need to provide a multiple choice solution.
Invoke-WebRequest -Uri https://cdn.zabbix.com/stable/4.4.7/zabbix_appliance-4.4.7-qcow2.tar.gz -OutFile $working_path\zabbix_appliance-4.4.7-qcow2.tar.gz

# -----  username and passwords here:
# cli:  root:zabbix   web:  Admin:zabbix  sql:  cat /root/.my.cnf 
# https://www.zabbix.com/documentation/current/manual/appliance

# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*  upload to nutanix and clone to VM

# ----------- zabbix template ----------- #
# ref:  https://github.com/JPangburn314/Zabbix3.4-MSSQL-2008-2016

Invoke-WebRequest -Uri https://github.com/sfuerte/zbx-mssql/archive/master.zip -Outfile $working_path\zabbix_template_sql.zip

# 1. import the template
# 2. go to site https://github.com/sfuerte/zbx-mssql - setup macros and expressions




#*************************************************************************************
#
#
#                  this section is client
#
#
#*************************************************************************************

# because we are grabbing snippets of this script, I want to set the working path again.
$working_path = (Resolve-Path .\).Path
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force
$zbxsvr = "172.16.2.172"  # Read-Host -Prompt "Enter IP\fgdn of Zabbix server"

# ----------- zabbix template ----------- #
# ref:  https://github.com/JPangburn314/Zabbix3.4-MSSQL-2008-2016

Invoke-WebRequest -Uri https://github.com/sfuerte/zbx-mssql/archive/master.zip -Outfile $working_path\zabbix_template_sql.zip

Expand-Archive -Path $working_path\zabbix_template_sql.zip -DestinationPath $working_path

# 1. import the template
# 2. go to site https://github.com/sfuerte/zbx-mssql - setup macros and expressions

# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*  upload template to zabbix server


# ----------- zabbix agent install ----------- #


Invoke-WebRequest -Uri https://www.zabbix.com/downloads/4.0.17/zabbix_agent-4.0.17-windows-amd64-openssl.msi -Outfile $working_path\zabbix_agent.msi 
Start-Process -FilePath msiexec.exe -ArgumentList "/I zabbix_agent.msi /qb SERVER=$($zbxsvr)" -Wait -Verb RunAs

# ----------- zabbix agent update configuration ----------- #
# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*  modify C:\Program Files\Zabbix Agent\zabbix_agentd.conf

if (!$zbxsvr)
{ 
    $zbxsvr = Read-Host -Prompt "Enter IP\fgdn of Zabbix server"
}

$Params = @"

Timeout=30  
ServerActive=$($zbxsvr)
Include=c:\Program Files\Zabbix Agent\conf.d* 
UnsafeUserParameters=1

"@

$Params | Out-File -FilePath "C:\Program Files\Zabbix Agent\zabbix_agentd.conf" -Append -Encoding ascii

$conf_file = @"
UserParameter=mssql.db.discovery,powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\Zabbix Agent\scripts\mssql_basename.ps1"
UserParameter=mssql.version,powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\Zabbix Agent\scripts\mssql_version.ps1"
"@

mkdir "c:\Program Files\Zabbix Agent\conf.d"
$conf_file | Out-File -FilePath "c:\Program Files\Zabbix Agent\conf.d\userparameter_mssql.conf" -Encoding ascii

Copy-Item -Path $working_path\zbx-mssql-master\scripts -Destination "C:\Program Files\Zabbix Agent\scripts" -Force -Recurse

get-service zab* | restart-service

# cleanup 
Remove-Item $working_path\zbx-mssql-master -Force -Recurse








#######  SNMP Monitoring for Nutanix - Prism Central
# https://blog.devarieux.net/2016/03/nutanix-template-for-zabbix.html
# https://github.com/aldevar/Zabbix_Nutanix_Template
# 

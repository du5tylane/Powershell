##################################
##  prepare SQL for SYSPREP     ##
##################################

# ref:  https://docs.microsoft.com/en-us/sql/database-engine/install-windows/install-sql-server-using-sysprep?view=sql-server-ver15

####  prerequisites
#  1.  sql binaries are on d:\sql2017

# set location
Set-Location C:\sql_2017_standard\customizations

# Install SQL with sysprep
Invoke-Command {
    c:\sql_2017_standard\setup.exe /qs /ACTION=PrepareImage /ConfigurationFile=c:\sql_2017_standard\customizations\imageprep_ConfigurationFile.INI /IACCEPTSQLSERVERLICENSETERMS
}

Write-Host "Ctrl+C to break the script or press ENTER to continue"
Pause

Invoke-Command {
    # run sysprep
    c:\windows\system32\sysprep\sysprep.exe /generalize /oobe
}

Write-Host "About to shutdown the server.  After the server is off, create image from server"
Write-Host "press ENTER key to continue"
Pause

Stop-computer -force

##################################
##  SQL Install post SYSPREP    ##
##################################

# ref:  https://docs.microsoft.com/en-us/sql/database-engine/install-windows/install-sql-server-using-sysprep?view=sql-server-ver15



# Complete the sql install after the server has been sysprep'd
Invoke-Command {
    c:\sql_2017_standard\Setup.exe /qs /SAPWD='MySecurePW123!' /ConfigurationFile=c:\sql_2017_standard\complete_ConfigurationFile.INI
}

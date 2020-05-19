# SQL Sysprep helper scripts
The purpose of these scripts and INI files are to help streamline the process of creating a Windows Server with SQL and sysprep.  This speeds up the final process of building a SQL server via cloning.

# Steps
0. Customize scripts and INI files to fit your needs
1. build Windows Image
2. copy the SQL installation binaries (and scripts) to the C:\ drive
3. execute the 'make_sql_image.ps1' PowerShell script (this will shutdown the VM after running SQL and Windows sysprep)
4. clone the VM, adding any additional drives that are defined by the INI files (D, M, L, T, etc)
5. using your favorite script or automation tool, call the Post_sql_image-install.ps1 script.  This will finalize the SQL build.  

# Reference
https://docs.microsoft.com/en-us/sql/database-engine/install-windows/install-sql-server-using-sysprep?view=sql-server-ver15




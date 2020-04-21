#Requires -Modules SQLServer

Param(
    [Parameter(Mandatory=$true)]\
    [string]$ComputerName
)

if (test-path c:\reports)
{

}else{
    mkdir c:\reports
}

$SQLInstance = $ComputerName

if (!$SQLInstance)
{
    $SQLInstance = Read-Host -Prompt "Enter SQL IP or FQDN:  "
}

$Query1 = @"
SELECT
    db.name AS DBName,
    type_desc AS FileType,
    Physical_Name AS Location
FROM
    sys.master_files mf
INNER JOIN 
    sys.databases db ON db.database_id = mf.database_id
"@

Invoke-SQLCMD -ServerInstance $SQLInstance -Query $Query1 | Out-File "c:\reports\$($SQLInstance)_SQLDBFile_Locations.txt" -Encoding ascii
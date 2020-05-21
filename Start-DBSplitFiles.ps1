<#
.SYNOPSIS
    Using a basic template, split an MDF into multiple files
.DESCRIPTION
    This script will use invoke-sqlcmd to connect to a SQL instance and split a database
    into multiple files.

    This uses DBCC and will fragment indexes.  Indexes should be rebuild after this is run.

.EXAMPLE
    PS C:\Scripts> Start-DBSplitFiles.ps1 -ComputerName <Some_VMName> -DBName <Some_DBName> -DriveLetters <M,N> -FolderPath <path> -NumberofFiles <4> 
.EXAMPLE
    Start-DBSplitFiles.ps1 -ComputerName <Some_VMName>

    PS C:\Scripts> Start-DBSplitFiles.ps1 -ComputerName SQLServer1 -DBName TestDB -DriveLetters M,N  -FolderPath "MSSQL\DATA" -NumberofFiles 4

.NOTES
    Author:  Dusty Lane
    Created:  05/21/2020
    Version:  0.5
#>

Param(
    [Parameter(Mandatory=$true)]
    [string]$ComputerName,
    [Parameter(Mandatory=$true)]
    [string]$DBName,
    [Parameter(Mandatory=$true)]
    [string[]]$DriveLetters,
    [Parameter(Mandatory=$true)]
    [string]$FolderPath,
    [Parameter(Mandatory=$true)]
    [ValidateSet(2,4,6,8)]
    [int]$NumberofFiles = "4"
)

$SQLInstance = $ComputerName

if (!$SQLInstance)
{
    $SQLInstance = Read-Host -Prompt "Enter SQL IP or FQDN:  "
}

# build a query to get the size of the database
$Query_GetDB = @"
SELECT [Database Name] = DB_NAME(database_id),
       [Type] = CASE WHEN Type_Desc = 'ROWS' THEN 'DataFile'
                     WHEN Type_Desc = 'LOG'  THEN 'LogFile'
                     ELSE Type_Desc END,
       [SizeinMB] = CAST( ((SUM(Size)* 8) / 1024.0) AS DECIMAL(18,0) )
FROM sys.master_files WHERE database_id = DB_ID('$($DBName)')
GROUP BY      GROUPING SETS
              (
                     (DB_NAME(database_id), Type_Desc),
                     (DB_NAME(database_id))
              )
ORDER BY      DB_NAME(database_id), Type_Desc DESC
GO
"@

# connect to the instance and put the size into a variable
[int]$DBSize = Invoke-SQLCMD -ServerInstance $SQLInstance -Query $Query_GetDB | Where-Object {$_.type -eq "datafile"} | Select-Object -ExpandProperty SizeinMB

# do a little math to get the size per file that we will be setting up
$FileSize = $DBSize/$NumberofFiles

# start of the query - but we are adding to it later based on the number of files and drive letters
$Query1 = @"

USE $($DBName);
GO

EXECUTE [$($DBName)].dbo.sp_changedbowner 'sa';
GO

ALTER DATABASE [$($DBName)] SET RECOVERY SIMPLE;
GO
"@

# do a little math.  then build the sql statements based on the number of files and drive letters.
[int]$FilesPerDrive = $NumberofFiles/$DriveLetters.count
$NumberIndex = 1
for ($FileIndex = 0; $FileIndex -lt $FilesPerDrive; $FileIndex++)
{
    for ( $index = 0; $index -lt $DriveLetters.count; $index++)
    {
        
        $Letter = $DriveLetters[$index]
        $Query1 +=  @"

ALTER DATABASE [$($DBName)] ADD FILE ( NAME = $($DBName)_$($NumberIndex), FILENAME = '$($Letter):\$($FolderPath)\$($DBName)_$($NumberIndex).ndf', SIZE = $($FileSize)MB, MAXSIZE = UNLIMITED, FILEGROWTH = 256MB ) TO FILEGROUP [PRIMARY];
"@
        $NumberIndex++

    }
}


$Query1 += @"

GO

DBCC SHRINKFILE ( '$($DBName)', EMPTYFILE )
GO

ALTER DATABASE [$($DBName)] MODIFY FILE (NAME = $($DBName), SIZE = $($FileSize)MB, MAXSIZE = UNLIMITED, FILEGROWTH = 256MB);
ALTER DATABASE [$($DBName)] SET RECOVERY FULL;
GO

"@


Write-host "This will restructure the sql database ($DBName).  This is intrusive and should not be done during production hours." -ForegroundColor Red
Write-host "Press any key to continue or Ctrl+C to break" -ForegroundColor Cyan
Pause


Invoke-SQLCMD -ServerInstance $SQLInstance -Query $Query1

#Requires -Modules FailoverClusters

Param(
    [Parameter(Mandatory=$false)]
    [string]$ComputerName
)

if (test-path c:\reports)
{
    Write-Output "Report folder already exists"
}else{
    mkdir c:\reports
}

If (!$ComputerName)
{
    $ComputerName = $env:computername
}


if (test-path c:\reports)
{

}else{
    mkdir c:\reports
}

$cluster_Name = get-cluster $ComputerName | select-object -expandproperty name
start-process powershell.exe -ArgumentList "Test-Cluster $Cluster_Name -ReportName Cluster_$($cluster_Name) -Ignore Storage" -Wait

Copy-Item "$($env:temp)\Cluster_$($cluster_Name).*" -Destination c:\reports


# Disk Partition Block size report

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

Get-WmiObject -ComputerName $ComputerName -Class Win32_Volume | 
  Select-Object DriveLetter, Label, BlockSize, Capacity, Freespace | 
  Format-Table -AutoSize | 
  Out-File "c:\reports\$($computername)_block_report.txt" -Force

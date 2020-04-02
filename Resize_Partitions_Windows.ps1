#requires -version 4
<#
    .SYNOPSIS
        Finds raw volumes, creates partitions.  Finds free space and allocates it to partitions.
    .DESCRIPTION
        This script is designed to find any offline disks, bring them
        online, initialize\format the partitions and assign the next available
        drive letter.

        For free space found on an existing disk, it will grow the partition
        utilizing all available free space.

    .NOTES
        Version:        1.0
        Author:         Dusty Lane
        Creation Date:  03/20/2020
        Purpose/Change: Initial script development
  
#>

# Get the disks

$Disks = Get-Disk

foreach ($Disk in $Disks) 
{
    # Bring all the drives online if they are offline....
    if ($disk.operationalstatus -eq "Offline")
    {
        $disk | set-disk -isoffline $false 
        $disk | set-disk -isReadOnly $false
    }

    # format any volumes that are 'raw'
    if ($disk.partitionstyle -eq 'RAW')
    {
        Initialize-Disk -Number $disk.DiskNumber -PartitionStyle GPT -PassThru -ErrorAction SilentlyContinue
        
        # need to get the drive letter that would be next in line....
        $findletter = ((get-volume | where-object {$_.driveletter -match '.'}).driveletter | Sort-Object)[-1]
        $letter = [byte]$findletter + 1
        $letter = [char]$letter
        New-Partition -DiskNumber $disk.DiskNumber -DriveLetter $letter -UseMaximumSize
        Format-Volume -DriveLetter $letter -FileSystem NTFS -Confirm:$false
    }
}

# Get volumes
$Volumes = get-volume | where-object {$_.driveletter -match '.'} | where-object {$_.DriveType -eq 'Fixed'}

# Get partitions on each volume
foreach ($Volume in $Volumes)
{

    if (($volume.Size - $volume.SizeRemaining) -gt 102400000)
    {
        # we need to get some variables to make this happen
        $Partition = Get-Partition -DriveLetter $Volume.DriveLetter
        $disk = Get-Disk | Where-Object {$_.path -eq $partition.diskid}
        # get the maximum the size the partition can be.
        $size = (Get-PartitionSupportedSize -DiskNumber $disk.number -PartitionNumber $Partition.PartitionNumber)
        Resize-Partition -DiskNumber $disk.number -PartitionNumber $Partition.PartitionNumber -Size $size.SizeMax -confirm:$false
    }
}
<# 
#  Purpose: Convert VMware OVA to Hyper-V VHD.
#  Ref:  https://support.purestorage.com/Solutions/Microsoft_Platform_Guide/Hyper-V_Role/*_Convert_VMware_OVA_to_Hyper-V_Virtual_Hard_Disk_VHD
#>
#Requires -Version 5


function Convert-OVAtoVHD 
{
    [Cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$SourceOVAPath,
        [Parameter(Mandatory=$true)]
        [string]$OVAName,
        [Parameter(Mandatory=$true)]
        [string]$DestinationVHDPath,
        [Parameter(Mandatory=$true)]
        [string]$VMName
    )

    # Set default variables.

    $working_path = (Resolve-Path .\).Path


# Note - windows 2012r2 TLS issue:   [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Import the Microsoft VM Converter Powershell Module.
    # Install from https://www.microsoft.com/en-us/download/details.aspx?id=42497
    if (test-path "C:\Program Files\Microsoft Virtual Machine Converter\MvmcCmdlet.psd1")
    {
        Write-Output "Commandlet already installed"
    }else{
        Invoke-WebRequest -Uri "https://download.microsoft.com/download/9/1/E/91E9F42C-3F1F-4AD9-92B7-8DD65DA3B0C2/mvmc_setup.msi" -UseBasicParsing -OutFile $working_path\mvmc_setup.msi
        Start-Process -FilePath msiexec.exe -ArgumentList "/I mvmc_setup.msi /qb" -Wait -Verb RunAs
    }

    Import-Module "C:\Program Files\Microsoft Virtual Machine Converter\MvmcCmdlet.psd1"

    # built in compression tool will not unzip ova's, so we need this.
    Import-Module -Name 7Zip4Powershell

    # Unzip the <Name>.ova file to specified directory. 
    #Copy-Item -Path $SourceOVAPath -Destination "$DestinationVHDPath\$VMName.zip"
    Expand-7Zip -ArchiveFileName "$SourceOVAPath\$OVAName" -TargetPath "$DestinationVHDPath\$VMName"


    # Find VMDK to convert to VHD.
    $VMDKName = (Get-ChildItem -Path "$DestinationVHDPath\$VMName" -Filter *.vmdk).Name
    $SourceVMDKPath = "$DestinationVHDPath\$VMName\$VMDKName"

    # Convert the .VMDK from the OVA to a Virtual Hard Disk (VHD) - Generation 1.
    # To understand Gen1 vs Gen2 read https://technet.microsoft.com/en-us/library/dn440675%28v=sc.12%29.aspx?f=255&MSPPError=-2147217396
    ConvertTo-MvmcVirtualHardDisk -SourceLiteralPath $SourceVMDKPath -DestinationLiteralPath "$DestinationVHDPath\$VMName.vhd" -VhdType FixedHardDisk -VhdFormat Vhd
}

# Create new virtual machine with specified parameters.
# New-VM -Name $VMName -MemoryStartupBytes 8GB -VHDPath "$DestinationVHDPath\$VMName" -Generation 1 -SwitchName "ExternalSwitch" | Set-VM -ProcessorCount 2 -Passthru | Start-VM
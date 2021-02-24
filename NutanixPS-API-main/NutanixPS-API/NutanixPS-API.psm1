
    function Add-NTNXSnapshot
    {
        <#
        .SYNOPSIS
            Creates a snapshot

        .DESCRIPTION
            This function creates a snapshot of a named VM, using the date as the snapshot name.

        .PARAMETER ElementIP
            The IP of the Prism Element API to store as a global variable.

        .PARAMETER Computername
            The Name of the VM to clone

        .EXAMPLE

            Add-NTNXSnapshot -Computername DCSVR1

        .EXAMPLE
            # In this example, we are using the Get-NTNXVM function to get the VM and 
            # pipping that into the Add-NTNXSnapshot function.

            (Get-NTNXVM -Computername DC).name | Add-NTNXSnapshot

        .EXAMPLE
            # In this example, we are getting multiple VMs

            (Get-NTNXVM | Where-Object {$_.name -like "DC*"}).name | Add-NTNXSnapshot

        .NOTES
            Author:  Dusty Lane
            Website: http://nutanix.com
            Date:  1/22/2021
        #>
        [CmdletBinding()]
        param
        (
            [Parameter(Mandatory=$false)]
            [string]$ElementIp = $Global:ElementIP,
            [Parameter(Mandatory=$True,Position=0,ValueFromPipeline)]
            [object[]]$Computername
        )
        BEGIN
        {
            ##Using the process feature to be able to use the pipeline capability
        }
        PROCESS
        {
            ## Because we want to accept objects on a pipeline, we need to change the 
            ## object into a string.  
            [string]$Name = $Computername
            
            Try
            {
                $VMUUID = (get-ntnxvm -Computername $Name | Select-Object -Property uuid).uuid
            }
            Catch
            {
                Write-Warning -Message "Failed to get VM from Prism.  Please review the computername and try again."
                break
            }

            $SnapName = Get-Date -F "yyyMMdd-HHmm"

            $Body = @"
            {
                "snapshot_specs": [
                  {
                    "snapshot_name": "$($SnapName)",
                    "vm_uuid": "$($VMUUID)"
                  }
                ]
              }
"@

            $Params = @{
                uri = "https://$($ElementIP):9440/PrismGateway/services/rest/v2.0/snapshots/"
                method = "POST"
            }

            Get-NTNXApiResponse -Body $Body @Params

        }
        END
        {
            ## This is the end of the Process block.
        }
    }
    
    function Connect-NTNX
    {
        <#
        .SYNOPSIS
            Creates credentials and variables to connect to a Prism Element Rest API

        .DESCRIPTION
            This function sets up PowerShell to be able to connect to the Nutnaix Rest API.
            It is designed to facilitate multiple connects and enable switching between
            Prism Element's.

        .PARAMETER IP
            The IP of the Prism Element API to store as a global variable.

        .PARAMETER DNSName
            The Name of the Prism Element API to store as a global variable.

        .PARAMETER CredentialFile
            Use this switch to use a pre-created credential file.  This is created 
            with teh Set-NTNXCredentials function.

        .PARAMETER CredentialObject
            An obect that is already been created in the shell.  
        
        .EXAMPLE
            Connect-NTNX -IP <IP_of_PE_or_PC>

            # you will be prompted to enter your credentials to connect.

        .EXAMPLE

            Connect-NTNX -DNSName <DNSName of PE/PC> -CredentialFile

            # This will connect to Prism using your credential file.

        .EXAMPLE

            $MyCred = get-credential

            Connect-NTNX -IP <IP_of_PE_or_PC> -CredentialObject $MyCred

            # This will connect to PE using the precreated credential object.

        .NOTES
            Author:  Dusty Lane
            Website: http://nutanix.com
            Date:  1/22/2021
        #>

        [CmdletBinding()]
        param
        (
            [Parameter(Mandatory=$false)]
            [string]$IP,

            [Parameter(Mandatory=$false)]
            [string]$DNSName,

            [Parameter(Mandatory=$false)]
            [Switch]$CredentialFile,

            [Parameter(Mandatory=$false)]
            [Object]$CredentialObject

        )
        
        if ($DNSName)
        {
            ## converting the name to an IP.  If there are multiple DNS entries, we will select the last
            try
            {
                $IP = (([System.Net.Dns]::GetHostAddresses("$($DNSName)")).ipaddresstostring)[-1]
            }
            catch
            {
                Write-Warning -Message "Could not resolve Name to IP in DNS."
                Break
            }          
        }

        ## comparing the variable and setting if not already set.
        $Test = Test-Connection $IP -count 1
        if ($PSVersionTable.PSVersion.Major -lt 6)
        {
            if ($test.statuscode -ne "0")
            {
                Write-Warning "IP or DNSName required`n  OR`n unable to connect to IP\DNSName."
                Break
            }
            else
            {
                if ($ElementIP -eq $IP)
                {

                }
                else
                {
                    ## Setting the global environment variable to the same as the IP variable.
                    $Global:ElementIP = $IP
                }
            }
        }
        else
        {
            if ($test.status -ne "Success")
            {
                Write-Warning "IP or DNSName required`n  OR`n unable to connect to IP\DNSName."
                Break
            }
            else
            {
                if ($ElementIP -eq $IP)
                {

                }
                else
                {
                    ## Setting the global environment variable to the same as the IP variable.
                    $Global:ElementIP = $IP
                }
            }
        }
        ## setting up the credentials to be able to be used globally.
        
        if ($CredentialFile)
        {
            # credential setup.ps1 check
            if (-not (Test-Path -Path ~\NutanixSetup.xml))
            {
                Write-Warning -Message "Credential file not found.  Please run Set-NTNXCredential and try again"
                Break
            }

            # ingest credential object
            $Credential = Import-CliXml -Path ~\NutanixSetup.xml
            $Global:ElementCredential = ($Credential | Where-Object { $_.Service -eq "NutanixApi"}).Credential
        }
        elseif ($CredentialObject)
        {
            
            $Global:ElementCredential = $CredentialObject

        }
        else
        {
            $Global:ElementCredential = Get-Credential -Message "Enter the username and password to connect to the Nutanix Prism API"
        }
        
        try
        {
            $ClusterCheck = Get-NtnxApiResponse -Uri "https://$($ElementIP):9440/PrismGateway/services/rest/v2.0/cluster/" -Method "Get"
            
            $Cluster = [PSCustomObject]@{
                Ip          = $ElementIp
                Name        = $ClusterCheck.name
                Status      = $ClusterCheck.operation_mode
                Type        = $ClusterCheck.Storage_Type
                Version     = $ClusterCheck.version
                Nodes       = $ClusterCheck.num_nodes
            }

            $Cluster | Format-Table Name,IP,Status,Type,Version,Nodes -autosize
        }
        catch
        {
            Write-Warning "Failed to connect to the Nutanix API.  Check IP, Name, and Credentials and try again `n"
            Clear-Variable ElementIP -Scope Global
            Clear-Variable ElementCredential -Scope Global
            Break
        }
        
    }

    function Convert-UsecToHuman
    {
        [CmdletBinding()]
        param (
            [Parameter(Position=0)]
            [int64]$USeconds
        )

        ((Get-Date 01.01.1970)+([System.TimeSpan]::FromMilliseconds($USeconds/1000)))+(Get-TimeZone).baseUtcOffset
    }

    function Copy-NTNXVirtualMachine
    {
        <#
        .SYNOPSIS
            Creates a clone\copy of a virtual machine.

        .DESCRIPTION
            This function creates a clone of a named VM and depending on the parameters
            used, it can sysprep, join AD, and protect the new cloned VM.

        .PARAMETER ElementIP
            The IP of the Prism Element API to store as a global variable.

        .PARAMETER SourceVM
            The Name of the VM to clone
        
        .PARAMETER DestinationName
            
            Name of the new Virtual Machine.  This can be an array of names and piped into the command.
        
        .PARAMETER VLAN

            Name of the VLAN to associate to the new VM.

        .PARAMETER Unattend

            Path to the json file containing the sysprep information

        .PARAMETER ADComputerPath

            Fully qualified path to OU in Active Directory to place the computer object.  This parameter is only used if the JoinDomain switch is enabled.

        .PARAMETER JoinDomain

            This switch indicates that the new VM should be joined to the AD domain.

        .PARAMETER PowerON

            Switch specifies that the clone should be powered on.

        .PARAMETER ProtectVM

            This is a switch to add the VM to a protection domain.  Use the ProtectionDomainName parameter to
            specifiy the name of the protection domain.  If the parameter 'ProtectionDomainName'
            is not used, then the function will add the VM to a PD with the lowest number of entities
            associated to it.

        .PARAMETER ProtectionDomainName
        
            The name of the protection domain that you want the VM added to.

        .EXAMPLE

            Copy-NTNXVirtualMachine -SourceVM Template_Win2016 -DestinationName MyCoolVM `
             -VLAN 1306_Facilities -Unattend <path to sysprep file> -JoinDomain `
             -ProtectVM -ProtectionDomainName <name of PD> -PowerON

             # In this example, we are specifying all parameters.  We are sysprepping
             # the VM, joining to the domain and adding to a specific PD.
             #
             # THIS REQUIRES A VALID UNATTEND\SYSPREP FILE.

        .EXAMPLE

            Copy-NTNXVirtualMachine -SourceVM Template_Win2016 -DestinationName MyCoolVM `
             -VLAN 1306_Facilities

            # In this example, we are cloning a VM without any sysprep, AD or Power configurations.

        .EXAMPLE

            Copy-NTNXVirtualMachine -SourceVM Template_Win2016 -DestinationName MyCoolVM `
             -VLAN 1306_Facilities -Unattend <path to sysprep file> -PowerON

            # In this example, we are cloning a VM and using the 'workgroup join' 
            # option.

        .NOTES
            Author:  Dusty Lane
            Website: http://nutanix.com
            Date:  1/22/2021
        #>
        [CmdletBinding()]
        [Alias("Clone-NTNXVirtualMachine")]
        param
        (
            [Parameter(Mandatory=$false)]
            [string]$ElementIp = $Global:ElementIP,
            [Parameter(Mandatory=$True,Position=0)]
            [ValidateScript({Get-NTNXVM -Computername $_})] 
            [string]$SourceVM,
            [Parameter(Mandatory=$True,ValueFromPipeline)]
            [object[]]$DestinationName,
            [Parameter(Mandatory=$True,Position=2)]
            [ValidateScript({Get-NTNXVLAN -VLAN $_})] 
            [string]$VLAN,
            [Parameter(Mandatory=$false)]
            [ValidateScript({Test-Path $_ -PathType 'leaf'})] 
            [string]$Unattend,
            [Parameter(Mandatory=$false)]
            [string]$ADComputerPath = "ou=Computers,DC=contoso,DC=local",
            [Parameter(Mandatory=$false)]
            [switch]$PowerON,
            [Parameter(Mandatory=$false)]
            [switch]$JoinDomain,
            [Parameter(Mandatory=$false)]
            [switch]$ProtectVM,
            [Parameter(Mandatory=$false)]
            [string]$ProtectionDomainName
        )
        BEGIN
        {}
        PROCESS
        {
            ## computername needs to be defined\verified....
            [string]$ComputerName = $DestinationName

            ## get the uuid of the vlan
            $TargetVLAN = Get-NTNXVLAN -VLAN $VLAN

            if ($Unattend)
            {
                if (Test-Path -Path ~\NutanixSetup.xml)
                {
                    # ingest credentials
                    $Credential = Import-CliXml -Path ~\NutanixSetup.xml
                    $WindowsCred = ($Credential | Where-Object { $_.Service -eq "WindowsPassword"}).Credential
                    $DomainCred = ($Credential | Where-Object { $_.Service -eq "ActiveDirectory"}).Credential

                }
                else
                {
                    Write-Host "Credential file not found, please run Set-NTNXCredentials.`n`n" -ForegroundColor Cyan
                }
                
                $WindowsPassword = ($WindowsCred.GetNetworkCredential() | Select-Object password).password

                ## prepare sysprep file with replacement and escape chars for api - assumes windows crlf endings
                $UnattendXml = (Get-Content $Unattend) -replace "`r`n", "\n"
                $UnattendXml = $UnattendXml -replace '"', '\"'
                $UnattendXml = $UnattendXml.Replace("ReplComputerName","$ComputerName")

                $UnattendXml = $UnattendXml.Replace("ReplWinPassword","$WindowsPassword")
                

                
                if ($JoinDomain)
                {
                    $DomainJoinUsername = ($DomainCred.GetNetworkCredential() | Select-Object UserName).username
                    $DomainJoinPassword = ($DomainCred.GetNetworkCredential() | Select-Object password).password
                    
                    $UnattendXml = $UnattendXml.Replace("ReplDomainName","$($env:USERDNSDOMAIN)")
                    $UnattendXml = $UnattendXml.Replace("ReplDomainJoinUsername","$DomainJoinUsername")

                    ## ensure reserved xml characters are escaped in password
                    $DomainJoinPasswordXmlSafe = $DomainJoinPassword.Replace('"',"&quot;").Replace("'","&apos;").Replace("<","&lt;").Replace(">","&gt;").Replace("&","&amp;")
                    $UnattendXml = $UnattendXml.Replace("ReplDomainJoinPassword","$DomainJoinPasswordXmlSafe")

                    ## validate computername in active directory
                    $ComputerTest = Get-ADComputer -Filter { Name -eq $ComputerName } -Server (Get-ADDomainController).Name -Credential $DomainCred
                    if ($ComputerTest)
                    {
                        Write-Warning "Expected no computer account exists for $ComputerName. Check computer name and try again."
                        Break
                    }
                    else
                    {
                        Write-NTNXLog -Message "Computer account does not exist for $ComputerName and will be pre-staged."
                    }                   
                }

                $Body = @"
                {
                    "spec_list": [
                    {
                        "name": "$ComputerName",
                        "override_network_config": true,
                        "vm_nics": [
                        {
                            "network_uuid": "$($TargetVLAN.Uuid)",
                            "is_connected": true
                        }
                        ]
                    }
                    ],
                    "vm_customization_config": {
                        "userdata": "$UnattendXml"
                    }
                }
"@
            }
            else
            {
                $Body = @"
                {
                    "spec_list": [
                    {
                        "name": "$ComputerName",
                        "override_network_config": true,
                        "vm_nics": [
                        {
                            "network_uuid": "$($TargetVLAN.Uuid)",
                            "is_connected": true
                        }
                        ]
                    }
                    ]
                }
"@            
            }

            $Source = Get-NTNXVM -Computername $SourceVM

            If (($Source | Measure-Object).count -gt 1)
            {
                Write-Warning "More than one sourceVM matches naming criteria."
                break
            }

            ## define the parameters for the cloning operation
            ## we will be passing these params to our custom function
            $Params = @{
                uri = "https://$($ElementIP):9440/PrismGateway/services/rest/v2.0/vms/$($Source.uuid)/clone"
                method = "POST"
            }

            ## begin the cloning operation, grab the task id so that we can watch it.
            $CreateTaskId = (Get-NtnxApiResponse -Body $Body @Params).task_uuid

            Write-NTNXLog -Message "Wait for cloning task $CreateTaskId to complete."
            ## Need to wait fo the task to complete
            try
            {
                while ($TaskStatus.percentage_complete -ne "100")
                {
                    $Params = @{
                        uri = "https://$($ElementIP):9440/PrismGateway/services/rest/v2.0/tasks/$CreateTaskId"
                        method = "GET"
                    }

                    $TaskStatus = Get-NtnxApiResponse @Params
                    Start-Sleep -Seconds 1
                }

                if ($TaskStatus.progress_status -ne "Succeeded")
                {
                    throw "Expected clone task status 'Succeeded' but was '$($TaskStatus.progress_status)' instead."
                }
            }
            Catch
            {
                Write-Warning "error getting task status for the cloning operation.  Check Prism for details"
                break
            }

            Write-NTNXLog -Message "Cloning task $CreateTaskId completed successfully."

            ## retrieve vm uuid from successful task
            $VmUuid = $TaskStatus.entity_list.entity_id
            Write-NTNXLog -Message "Cloning task created VM with uuid $VmUuid."

            if ($JoinDomain)
            {
                ## pre-stage computer account
                Write-NTNXLog -Message "Staging account for $ComputerName in Active Directory OU at $ADComputerPath."
                $Description = "Created by Copy-NTNXVirtualMachine Function (NutanixCustom)"
                New-ADComputer -Name $ComputerName -SAMAccountName $ComputerName -Path $ADComputerPath -Server (Get-ADDomainController).Name -Credential $DomainCred -Description $Description
            }

            ## If the switches to control adding the VM to a PD where used....
            if ($ProtectionDomainName)
            {
                Protect-NTNXVM -Computername $ComputerName -ProtectionDomain $ProtectionDomainName
            }
            elseif ($ProtectVM)
            {
                Protect-NTNXVM -Computername $ComputerName
            }


            if ($PowerON)
            {
                Start-Sleep -Seconds 60 

                ## Let's make sure that we can 'see' the VM and that we do not have any duplicate names.

                $count = 0
                While ($State -ne "on")
                {
                    
                    $VM = Get-NTNXVM -Computername $ComputerName -ErrorAction Continue
                    $State = $VM.power_state
                    Set-NTNXVMPowerState -Computername $VM.name -State ON
                    Start-Sleep -Seconds 10

                    if ($Count -eq 0)
                    {
                        Write-NTNXLog "Write-NTNXLog "Attempting to Power On $ComputerName""
                    }

                    if ($Count -eq 20)
                    {
                        Write-Warning "Encountered error attempting to power on $computername"
                        Break
                    }
                }

                ## wait until prism returns vm ip address
                Write-NTNXLog -Message "Waiting up to 15 minutes for IP address assignment."
                $Count = 0
                try
                {
                    while ($vm.vm_nics.ip_address -like "169.254.*" -or -not $vm.vm_nics.ip_address)
                    {
                        $Params = @{
                            uri = "https://$($ElementIP):9440/PrismGateway/services/rest/v2.0/vms/$($VmUuid)?include_vm_nic_config=true"
                            method = "GET"
                        }

                        $VM = Get-NtnxApiResponse @Params

                        Start-Sleep -Seconds 15
                        $Count++

                        if ($Count -eq 60)
                        {
                            Write-Warning "Wait for IP assignment exceeded 15 minutes, exiting."
                            Break
                        }
                    }
                }
                catch
                {
                    Write-Warning -Message "Error encountered trying to get IP for VM during after VM started."
                }
            }
        }
        END
        {}

    }

    function Get-NTNXAlert
    {
        <#
        .SYNOPSIS
            Returns VMs\VM from the Nutanix API

        .DESCRIPTION
            Uses the Nutanix API to get a list of VMs.  If a Computername is specified, a 
            single VM is returned.  If no Computername is specified, all VMs are returned.

            An array of custom Powershell objects are created from the VMs returned from the API.

        .PARAMETER ElementIP
            This paraeter can be the name or the IP of the Prism Element cluster.

        .PARAMETER Computername
            
            The name of the VM to retrieve.

        .EXAMPLE
            
            Get-NTNXAlert | ft Severity,Alert_title,Acknowledged,Last_Occurrence -AutoSize

        .NOTES
            Author:  Dusty Lane
            Website: http://nutanix.com
            Date:    1/22/2021
        #>
        [CmdletBinding()]
        param
        (
            [Parameter(Mandatory=$false)]
            [string]$ElementIp = $Global:ElementIP
        )

        $Params = @{
            uri = "https://$($ElementIp):9440/PrismGateway/services/rest/v2.0/alerts"
            method = "GET"
        }
    
        $Alerts = (Get-NtnxApiResponse @Params).entities

        foreach ($Alert in $Alerts)
        {
            [PSCustomObject]@{

                Acknowledged = $Alert.acknowledged
                Acknowledged_by_username = $Alert.acknowledged_by_username
                Acknowledged_time_stamp_in_usecs = Convert-UsecToHuman $($Alert.acknowledged_time_stamp_in_usecs)
                Affected_entities = $Alert.affected_entities
                Alert_details = $Alert.alert_details
                Alert_title = $Alert.alert_title
                Alert_type_uuid = $Alert.alert_type_uuid
                Auto_resolved = $Alert.auto_resolved
                Check_id = $Alert.check_id
                Classifications = $Alert.classifications
                Cluster_uuid = $Alert.cluster_uuid
                Context_types = $Alert.context_types
                Context_values = $Alert.context_values
                Created_Time = Convert-UsecToHuman $($Alert.created_time_stamp_in_usecs)
                Detailed_message = $Alert.detailed_message
                ID = $Alert.id
                Impact_types = $Alert.impact_types
                Last_Occurrence = Convert-UsecToHuman $($Alert.last_occurrence_time_stamp_in_usecs)
                Message = $Alert.message
                Node_uuid = $Alert.node_uuid
                Possible_causes = $Alert.possible_causes
                Resolved = $Alert.resolved
                Resolved_By = $Alert.resolved_by_username
                Resolved_Time = Convert-UsecToHuman $($Alert.resolved_time_stamp_in_usecs)
                Service_vmid = $Alert.service_vmid
                Severity = $Alert.severity
            } 
        }

    }

    function Get-NTNXApiResponse
    {
        
        <#
        .SYNOPSIS
            Wrapper to help with interfacing with the Nutanix API

        .DESCRIPTION
            This function ignores self-signed ssl certificates.  It
            allows for consistent formatting of the parameters to pass
            to the Nutanix REST API.

        .PARAMETER URI
            The uri for the API to connect to

        .PARAMETER Method
            GET, POST, DELETE, MODIFY are a few examples of the Methods that can be used
            with the Nutanix API.

        .EXAMPLE

            $Params = @{
            uri = "https://192.168.1.25:9440/PrismGateway/services/rest/v2.0/tasks/1962edba-61fc-4782-9d3d-3190658d763f"
            method = "GET"
            }

            Get-NtnxApiResponse @Params

        .EXAMPLE
            
            In this example, we are cloning a VM.
            
            we are using a 'here-string' to create the body of the request:

            $Computername = "MyComp1"

            $SourceVM = get-ntnxvm -Computername Template-Win10-1

            $TargetVLAN = Get-NTNXVLAN -VLAN 1306_ITTest

            $Body = @"
            {
                "spec_list": [
                {
                    "name": "$ComputerName",
                    "override_network_config": true,
                    "vm_nics": [
                    {
                        "network_uuid": "$($TargetVLAN.Uuid)",
                        "is_connected": true
                    }
                    ]
                }
                ]
            }
            "@

            define the parameters for the cloning operation

            $Params = @{
                uri = "https://192.168.1.25:9440/PrismGateway/services/rest/v2.0/vms/$($SourceVM.uuid)/clone"
                method = "POST"
            }

            Get-NtnxApiResponse -Body $Body @Params

        .NOTES
            Author:  Chris Kingsley and Dusty Lane
            Website: http://nutanix.com
            Date:  12/22/2020
            Modified:  1/22/2021
            Reason:  updated ssl configuration
            Version: 1.1
        #>

        [CmdletBinding()]
        param
        (
            [Parameter(Mandatory=$true)]
            [string]$Uri,

            [Parameter(Mandatory=$true)]
            [string]$Method,

            [Parameter(Mandatory=$false)]
            [string]$Body,

            [Parameter(Mandatory=$false)]
            [System.Management.Automation.PSCredential]$ElementCredential 

        )

        if ($Global:ElementCredential)
        {
            $ElementUsername = ($Global:ElementCredential.GetNetworkCredential() | Select-Object UserName).username
            $ElementPassword = ($Global:ElementCredential.GetNetworkCredential() | Select-Object password).password
        }
        else
        {
            Write-Warning -Message "Credential not found.  Please use Connect-NTNX to establish credentials to connect to the API."
            Break    
        }
        
        ## headers
        $Script:Headers = @{
            "Authorization" = "Basic "+[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($ElementUsername+":"+$ElementPassword ))
        }

        ## create a set of parameters that we pass to the invoke-restmethod PS function.
        $Params = @{
            Uri                     = $Uri
            Headers                 = $Headers
            ContentType             = "application/json"
            UseBasicParsing         = $true
        }

        ## This block is in here so that we can use the same function whether it is a post\get\delete\etc.
        if ($PSVersionTable.PSVersion.Major -lt 6)
        {
            ## set tls1.2 as default
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

            ## ignore untrusted certificate errors
            $IgnoreCertificateErrors = @"
            public class SSLHandler
            {
            public static System.Net.Security.RemoteCertificateValidationCallback GetSSLHandler()
            {
                return new System.Net.Security.RemoteCertificateValidationCallback((sender, certificate, chain, policyErrors) => { return true; });
            }
            }
"@
            ## getting an error when running the script multiple times.  Trying to 'hide' the error
            ## inside of a private object that is only executed each time the funtion is run, then
            ## it is dropped.
            $private:ssl = Add-Type -TypeDefinition $IgnoreCertificateErrors -ErrorAction SilentlyContinue -IgnoreWarnings -PassThru 
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = [SSLHandler]::GetSSLHandler()
            
            if ($Method -eq "GET")
            {
                Invoke-RestMethod @Params -Method $Method
            }
            else
            {
                Invoke-RestMethod @Params -Method $Method -Body $Body
            }
        }else{
            ## PS Version 6 added a more elegant way to handle SSL issues.
            if ($Method -eq "GET")
            {
                Invoke-RestMethod @Params -Method $Method -SkipCertificateCheck
            }
            else
            {
                Invoke-RestMethod @Params -Method $Method -Body $Body -SkipCertificateCheck
            }
        }
    }

    function GetNTNXClusterList
    {
        <#
        .SYNOPSIS
            Uses Prism Central to get a list of clusters

        .DESCRIPTION
            Uses Prism Central to get a list of clusters that we can build an
            array selection from.

        .PARAMETER ElementIP
            The IP of the Prism API to store as a global variable.

        .EXAMPLE

            tbd

        .NOTES
            Author:  Dusty Lane
            Website: http://nutanix.com
            Date:  1/22/2021
        #>
        [CmdletBinding()]
        param
        (
            [Parameter(Mandatory=$false)]
            [string]$PrismCentralIp = $Global:PrismCentralIP,

            [Parameter(Mandatory=$false)]
            [string]$DNSName

        )
        
        #if ({$DNSName -eq $null} -and {$PrismCentralIp -eq $null})
        #{
        #    Write-Warning -Message "PrismCentralIP or DNSName required"
        #    Break
        #}

        Write-host "This function is not ready for use" -ForegroundColor cyan
        Break

        if ($DNSName)
        {
            ## converting the name to an IP.  If there are multiple DNS entries, we will select the last
            try {
                $PrismCentralIP = (([System.Net.Dns]::GetHostAddresses("$($DNSName)")).ipaddresstostring)[-1]
            }
            catch {
                Write-Warning -Message "Could not resolve Name to IP in DNS."
                Break
            }
            
        }


        ## Here string for body
        $Body = @"
        {
            "kind": "cluster"
        }
"@

        $Params = @{
            uri = "https://$($PrismCentralIP):9440/api/nutanix/v3/clusters/list"
            method = "POST"
        }

        $Clusters = (Get-NTNXApiResponse -Body $Body @Params).Entities

        foreach ($Cluster in $Clusters)
        {
            [PSCustomObject]@{
                ElementIp   = $Cluster.status.resources.network.external_ip
                Name        = $Cluster.status.name
            }
        }

    }

    function Get-NTNXClusterStatus
    {
        <#
        .notes
            ##############################################################################
            #	 	 Nutanix Cluster Info Script
            #	 	 Filename			:	  NTNX_Get_Cluster_Info.ps1
            #	 	 Script Version	:	  1.1.15
            #        adapted to Function:  1/19/2021
            ##############################################################################

        .synopsis
            Generate 3 CSV files, 1 for cluster information, 1 for cluster resiliency and 1 for host information.
        
        .NOTES
            .Source  https://www.nutanix.dev/code_samples/nutanix-cluster-info-script/ 
            
            .prerequisites
            1. Powershell 5 or above ($psversiontable.psversion.major)
            2. Windows Vista or newer.
            3. Set the appropriate variables for your environment.
        
            .disclaimer
            This code is intended as a standalone example. Subject to licensing restrictions defined on nutanix.dev, this can be downloaded, copied and/or modified in any way you see fit.

            Please be aware that all public code samples provided by Nutanix are unofficial in nature, are provided as examples only, are unsupported and will need to be heavily scrutinized and potentially modified before they can be used in a production environment. All such code samples are provided on an as-is basis, and Nutanix expressly disclaims all warranties, express or implied.

            All code samples are copyright Nutanix, Inc., and are provided as-is under the MIT license. (https://opensource.org/licenses/MIT)

        .EXAMPLE

            Get-NTNXClusterStatus -ClusterIPs <IP1>, <IP2>, <IP3>

            # In this example, we get the status of of 3 clusters.

        #>
        [CmdletBinding()]
        param (
            [Parameter()]
            [STRING[]] $ClusterIPs,
            [string]$my_temperract = $ErrorActionPreference, # set error handling preferences
            [string]$my_ErrorActionPreference = "silentlycontinue" # set error handling preferences
        )
        $my_ClusterArrayIP = $ClusterIPs
        
        if (-not (Test-Path -Path ~\NutanixSetup.xml))
        {
            Write-Warning -Message "Credential file not found.  Please run Set-NTNXCredential and try again"
            Break
        }

        # ingest credential object
        $Credential = Import-CliXml -Path ~\NutanixSetup.xml
        $my_credentials = ($Credential | Where-Object { $_.Service -eq "NutanixApi"}).Credential

        $hashClusters = @{}
        function isonline([string]$my_testcomputer) {
            write-host "|" -NoNewline -ForeGroundColor DARKGRAY -BackGroundColor DARKGRAY;
            write-host "CLST: $($my_testcomputer) " -NoNewline -ForeGroundColor GRAY -BackGroundColor BLACK;
            $my_pingsuccess = $false
            try {
                $my_ping = new-object system.net.networkinformation.ping
                $my_pingtest = $my_ping.send($my_testcomputer)
            }
            catch{ }
            write-host "[" -NoNewline -ForeGroundColor GRAY -BackGroundColor BLACK;
            if ($my_pingtest.status.tostring() -eq "Success") {
                write-host "Online" -NoNewline -ForeGroundColor GREEN -BackGroundColor BLACK;
                $my_TmpString = "]"
                foreach ($i in 0..($my_SepLength-$my_testcomputer.length-17)) { $my_TmpString += -join " " }
                write-host ("{0}" -f $my_TmpString) -NoNewline -ForeGroundColor GRAY -BackGroundColor BLACK;
                write-host "|" -ForeGroundColor DARKGRAY -BackGroundColor DARKGRAY;
                return $true
            }
            else {
                write-host "Offline" -NoNewline -ForeGroundColor RED -BackGroundColor BLACK;
                $my_TmpString = "]"
                foreach ($i in 0..($my_SepLength-$my_testcomputer.length-18)) { $my_TmpString += -join " " }
                write-host ("{0}" -f $my_TmpString) -NoNewline -ForeGroundColor GRAY -BackGroundColor BLACK;
                write-host "|" -ForeGroundColor DARKGRAY -BackGroundColor DARKGRAY;
                return $false
            }
        }
        function format-size($size) {
            if ($size -gt 1tb) { [string]::format("{0:0.00} TiB", $size / 1tb) }
            elseif ($size -gt 1gb) { [string]::format("{0:0.00} GiB", $size / 1gb) }
            elseif ($size -gt 1mb) { [string]::format("{0:0.00} MB", $size / 1mb) }
            elseif ($size -gt 1kb) { [string]::format("{0:0.00} KB", $size / 1kb) }
            elseif ($size -gt 0)   { [string]::format("{0:0.00} B", $size) }
            else { "N/A" }
        }
        function mformat-string($string) {
            if (-not ([string]::IsNullOrEmpty($string))) {
                return [string]$string
            }
            return "N/A"
        }
        function collect_cluster_info($my_TargetIP) {
            ## Collect Cluster Info
            $my_TmpString1 = "..Parsing Cluster Data"
            write-host "|" -NoNewline -ForeGroundColor DARKGRAY -BackGroundColor DARKGRAY;
            write-host ("{0}" -f $my_TmpString1) -NoNewline -ForeGroundColor GRAY -BackGroundColor BLACK;
            try {
                $my_RestAPIUrl = "https://$($my_TargetIP):9440/PrismGateway/services/rest/v2.0/cluster/"
                $my_RestResponse = Invoke-RestMethod -Method Get -Uri $my_RestAPIUrl -Headers @{Authorization = "Basic $base64AuthInfo" } -Credential $my_Credential -ContentType "application/json"
                $my_ArrCluster = @()
                $my_TmpClusterObj = new-object psobject
                [int]$my_int = 0
                $my_RestResponse | % {
                    $myClusterName = $_.name
                    $my_Cluster_Name = mformat-string($_.name)
                    if (-not $my_ClusterHash.containskey($my_TargetIP)) { $my_ClusterHash.add($my_TargetIP,$my_Cluster_Name) }
                    write-progress -id 2 -parentid 1 -activity " " -status "Enumerating JSON values..." -percentcomplete ($my_int / @($my_RestResponse).count * 100)
                    $my_TmpClusterObj | Add-Member -MemberType NoteProperty -Name "Cluster Name" -value $my_Cluster_Name
                    $cluster_id = mformat-string($_.id)
                    $my_TmpClusterObj | Add-Member -MemberType NoteProperty -Name "Cluster ID" -value $cluster_id
                    $cluster_uuid = mformat-string($_.uuid)
                    $my_TmpClusterObj | Add-Member -MemberType NoteProperty -Name "Cluster UUID" -value $cluster_uuid
                    $cluster_incarnation_id = mformat-string($_.cluster_incarnation_id)
                    $my_TmpClusterObj | Add-Member -MemberType NoteProperty -Name "Cluster Incarnation ID" -value $cluster_incarnation_id
                    $cluster_external_ipaddress = mformat-string($_.cluster_external_ipaddress)
                    $my_TmpClusterObj | Add-Member -MemberType NoteProperty -Name "Cluster Virtual IP Address" -value $cluster_external_ipaddress.trim('{}')
                    $cluster_external_data_services_ipaddress = mformat-string($_.cluster_external_data_services_ipaddress)
                    $my_TmpClusterObj | Add-Member -MemberType NoteProperty -Name "Cluster iSCSI Data Services IP" -value $cluster_external_data_services_ipaddress.trim('{}')
                    $my_Hypervisor_Types = mformat-string($_.hypervisor_types)
                    $my_TmpClusterObj | Add-Member -MemberType NoteProperty -Name "Cluster Hypervisor" -value $my_Hypervisor_Types.trim('{k}')
                    $timezone = mformat-string($_.timezone)
                    $my_TmpClusterObj | Add-Member -MemberType NoteProperty -Name "Cluster Timezone" -value $timezone
                    $support_verbosity_type = mformat-string($_.support_verbosity_type)
                    $my_TmpClusterObj | Add-Member -MemberType NoteProperty -Name "Cluster Support Verbosity" -value $support_verbosity_type
                    $version = mformat-string($_.version)
                    $my_TmpClusterObj | Add-Member -MemberType NoteProperty -Name "Cluster AOS Version" -value $version
                    $full_version = mformat-string($_.full_version)
                    $my_TmpClusterObj | Add-Member -MemberType NoteProperty -Name "Cluster Full AOS Version" -value $full_version
                    $my_NCC_version = mformat-string($_.ncc_version)
                    $my_TmpClusterObj | Add-Member -MemberType NoteProperty -Name "Cluster NCC Version" -value $my_NCC_version
                    $i = 1
                    foreach ($nameserver in $_.name_servers) {
                        $my_TmpClusterObj | Add-Member -MemberType NoteProperty -Name "Cluster Name Server #$($i)" -value $nameserver.trim('{}')
                        $i++
                    }
                    $i = 1
                    foreach ($my_NTPServer in $_.ntp_servers) {
                        $my_TmpClusterObj | Add-Member -MemberType NoteProperty -Name "Cluster NTP Server #$($i)" -value $my_NTPServer.trim('{}')
                        $i++
                    }
                    $my_ArrCluster += $my_TmpClusterObj
                    $my_int++
                }
                $my_ArrCluster | export-csv $my_File_1 -append -notypeinformation -force
                write-host " [" -NoNewline -ForeGroundColor GRAY -BackGroundColor BLACK;
                write-host "OK" -NoNewline -ForeGroundColor GREEN -BackGroundColor BLACK;
                $my_TmpString = "]"
                foreach ($i in 0..($my_SepLength-29)) { $my_TmpString += -join " " }
                write-host ("{0}" -f $my_TmpString) -NoNewline -ForeGroundColor GRAY -BackGroundColor BLACK;
                write-host "|" -ForeGroundColor DARKGRAY -BackGroundColor DARKGRAY;
            }
            catch {
                write-host " [" -NoNewline -ForeGroundColor GRAY -BackGroundColor BLACK;
                if ($_ -like '*Password*failed*') {
                    write-host "Bad Password" -NoNewline -ForeGroundColor RED -BackGroundColor BLACK;
                    $my_TmpString = "]"
                    foreach ($i in 0..($my_SepLength-39)) { $my_TmpString += -join " " }
                    write-host ("{0}" -f $my_TmpString) -NoNewline -ForeGroundColor GRAY -BackGroundColor BLACK;
                    write-host "|" -ForeGroundColor DARKGRAY -BackGroundColor DARKGRAY;
                }
                elseif ($_ -like '*Bad*credentials*') {
                    write-host "Bad Credentials" -NoNewline -ForeGroundColor RED -BackGroundColor BLACK;
                    $my_TmpString = "]"
                    foreach ($i in 0..($my_SepLength-42)) { $my_TmpString += -join " " }
                    write-host ("{0}" -f $my_TmpString) -NoNewline -ForeGroundColor GRAY -BackGroundColor BLACK;
                    write-host "|" -ForeGroundColor DARKGRAY -BackGroundColor DARKGRAY;
                }
                else {
                    write-host "FAIL" -NoNewline -ForeGroundColor RED -BackGroundColor BLACK;
                    $my_TmpString = "]"
                    foreach ($i in 0..($my_SepLength-31)) { $my_TmpString += -join " " }
                    write-host ("{0}" -f $my_TmpString) -NoNewline -ForeGroundColor GRAY -BackGroundColor BLACK;
                    write-host "|" -ForeGroundColor DARKGRAY -BackGroundColor DARKGRAY;
                }
            }
            write-progress -id 2 -parentid 1 -activity " " -status "Enumerating JSON values..." -complete
            ## Collect Cluster Info
        }
        function collect_node_info($my_TargetIP) {
            ## Collect Disk Count
            $my_TmpString1 = "..Parsing Node Data"
            write-host "|" -NoNewline -ForeGroundColor DARKGRAY -BackGroundColor DARKGRAY;
            write-host ("{0}" -f $my_TmpString1) -NoNewline -ForeGroundColor GRAY -BackGroundColor BLACK;
            try {
                $my_RestAPIUrl = "https://$($my_TargetIP):9440/PrismGateway/services/rest/v2.0/disks/"
                $my_RestResponse = Invoke-RestMethod -Method Get -Uri $my_RestAPIUrl -Headers @{Authorization = "Basic $base64AuthInfo" } -Credential $my_Credential -ContentType "application/json"
                $my_DriveHash = @{}
                $my_TmpHash = @{}
                $my_TmpStorageHash = @{};$my_RestResponse.entities | get-member -membertype properties | foreach { $my_TmpStorageHash.add($_.name,$my_RestResponse.entities.($_.name)) }
                $i = 0
                $my_TmpStorageHash['cvm_ip_address'] | % {
                    $my_TmpIP = $_
                    $my_NodeIPId = $my_TmpIP.split('.')[3]
                    $driveType = $my_TmpStorageHash['storage_tier_name'][$i]
                    if (-not $my_TmpHash.containskey($my_NodeIPId)) { $my_TmpHash.add($my_NodeIPId,$driveType) }
                    else { $tmpVal = $my_TmpHash[$my_NodeIPId]; $my_TmpHash[$my_NodeIPId] += ",$($driveType)" }
                    $i++
                }
                foreach ($h in $my_TmpHash.getenumerator()) { $my_HDD = 1;$my_SSD = 1; $h.value.split(",") | foreach { switch($_) { "HDD" { $my_HDD++ }; "SSD" { $my_SSD++ } } }; if (-not $my_DriveHash.containskey($h.name)) { $my_DriveHash.add($h.name,"$($my_HDD)|$($my_SSD)") } }
                ## Collect Disk Count
                $my_RestAPIUrl = "https://$($my_TargetIP):9440/PrismGateway/services/rest/v2.0/hosts/"
                $my_RestResponse = Invoke-RestMethod -Method Get -Uri $my_RestAPIUrl -Headers @{Authorization = "Basic $base64AuthInfo" } -Credential $my_Credential -ContentType "application/json"
                $my_ArrNode = @()
                [int]$my_int = 0
                $my_RestResponse.entities | % {
                    write-progress -id 2 -parentid 1 -activity " " -status "Enumerating JSON values..." -percentcomplete ($my_int / @($my_RestResponse.entities).count * 100)
                    $my_Entities = $_
                    $my_TmpNodeObj = new-object psobject
                    $my_Cluster_Name = mformat-string($my_ClusterHash.Item($my_TargetIP))
                    $my_TmpNodeObj | Add-Member -MemberType NoteProperty -Name "Cluster Name" -value $my_Cluster_Name
                    $my_Node_Name = mformat-string($my_Entities.name)
                    $my_TmpNodeObj | Add-Member -MemberType NoteProperty -Name "Host Name" -value $my_Node_Name
                    $my_Hypervisor_Address = mformat-string($my_Entities.hypervisor_address)
                    $my_TmpNodeObj | Add-Member -MemberType NoteProperty -Name "Hypervisor IP" -value $my_Hypervisor_Address.trim('{}')
                    $my_Controller_Address = mformat-string($my_Entities.controller_vm_backplane_ip)
                    $my_TmpNodeObj | Add-Member -MemberType NoteProperty -Name "Controller VM IP" -value $my_Controller_Address.trim('{}')
                    $my_IPMI_Address = mformat-string($my_Entities.ipmi_address)
                    $my_TmpNodeObj | Add-Member -MemberType NoteProperty -Name "IPMI IP" -value $my_IPMI_Address.trim('{}')
                    $my_Node_Serial = mformat-string($my_Entities.serial)
                    $my_TmpNodeObj | Add-Member -MemberType NoteProperty -Name "Node Serial" -value $my_Node_Serial
                    $my_Block_Serial = mformat-string($my_Entities.block_serial)
                    $my_TmpNodeObj | Add-Member -MemberType NoteProperty -Name "Block Serial" -value $my_Block_Serial
                    $my_Block_Model = mformat-string($my_Entities.block_model_name)
                    $my_TmpNodeObj | Add-Member -MemberType NoteProperty -Name "Block Model" -value $my_Block_Model
                    $my_TmpStorageHash=@{}; $my_Entities.usage_stats | get-member -membertype properties | foreach { if ($my_Entities.usage_stats.($_.name) -ne '-1') { $my_TmpStorageHash.add($_.name,$my_Entities.usage_stats.($_.name)) } else { $my_TmpStorageHash.add($_.name,0) } }
                    $my_TmpNodeObj | Add-Member -MemberType NoteProperty -Name "Storage Capacity" -value "$(format-size($my_TmpStorageHash['storage.capacity_bytes']))"
                    $my_TmpNodeObj | Add-Member -MemberType NoteProperty -Name "Disks" -value "HDD: $($my_DriveHash[$my_Entities.controller_vm_backplane_ip.split('.')[3]].split('|')[0]) SSD: $($my_DriveHash[$my_Entities.controller_vm_backplane_ip.split('.')[3]].split('|')[1])"
                    $my_TmpNodeObj | Add-Member -MemberType NoteProperty -Name "Memory" -value  "$(format-size($my_Entities.memory_capacity_in_bytes))"
                    $my_CPU_Capacity = $_.cpu_capacity_in_hz / 1000000000; if ($my_CPU_Capacity -eq 0) { $my_CPU_Capacity = "N/A" } else { [string]$my_CPU_Capacity += " GHz" }
                    $my_TmpNodeObj | Add-Member -MemberType NoteProperty -Name "CPU Capacity" -value $my_CPU_Capacity
                    $my_CPU_Model = mformat-string($my_Entities.cpu_model)
                    $my_TmpNodeObj | Add-Member -MemberType NoteProperty -Name "CPU Model" -value $my_CPU_Model
                    $my_CPU_Cores = mformat-string($my_Entities.num_cpu_cores)
                    $my_TmpNodeObj | Add-Member -MemberType NoteProperty -Name "No. of CPU Cores" -value $my_CPU_Cores
                    $my_CPU_Cores = mformat-string($my_Entities.num_cpu_cores)
                    $my_TmpNodeObj | Add-Member -MemberType NoteProperty -Name "No. of Sockets" -value $my_Entities.num_cpu_sockets
                    $my_Num_VMs = mformat-string($my_Entities.num_vms)
                    $my_TmpNodeObj | Add-Member -MemberType NoteProperty -Name "No. of VMs" -value $my_Num_VMs
                    $my_Oplog_Disk_Pct = mformat-string($my_Entities.oplog_disk_pct)
                    $my_TmpNodeObj | Add-Member -MemberType NoteProperty -Name "Oplog Disk %" -value "$($my_Oplog_Disk_Pct)%"
                    $my_CPU_Cores = mformat-string($my_Entities.num_cpu_cores)
                    $my_TmpNodeObj | Add-Member -MemberType NoteProperty -Name "Oplog Disk Size" -value "$(format-size($my_Entities.oplog_disk_size))"
                    $my_Monitored = mformat-string($my_Entities.monitored)
                    $my_TmpNodeObj | Add-Member -MemberType NoteProperty -Name "Monitored" -value $my_Monitored
                    $my_Hypervisor_Full_Name = mformat-string($my_Entities.hypervisor_full_name)
                    $my_TmpNodeObj | Add-Member -MemberType NoteProperty -Name "Hypervisor" -value $my_Hypervisor_Full_Name
                    $my_ArrNode += $my_TmpNodeObj
                    $my_int++
                }
                $my_ArrNode | export-csv $my_File_3 -append -notypeinformation -force
                write-host " [" -NoNewline -ForeGroundColor GRAY -BackGroundColor BLACK;
                write-host "OK" -NoNewline -ForeGroundColor GREEN -BackGroundColor BLACK;
                $my_TmpString = "]"
                foreach ($i in 0..($my_SepLength-26)) { $my_TmpString += -join " " }
                write-host ("{0}" -f $my_TmpString) -NoNewline -ForeGroundColor GRAY -BackGroundColor BLACK;
                write-host "|" -ForeGroundColor DARKGRAY -BackGroundColor DARKGRAY;
            }
            catch {
                write-host " [" -NoNewline -ForeGroundColor GRAY -BackGroundColor BLACK;
                if ($_ -like '*Password*failed*') {
                    write-host "Bad Password" -NoNewline -ForeGroundColor RED -BackGroundColor BLACK;
                    $my_TmpString = "]"
                    foreach ($i in 0..($my_SepLength-36)) { $my_TmpString += -join " " }
                    write-host ("{0}" -f $my_TmpString) -NoNewline -ForeGroundColor GRAY -BackGroundColor BLACK;
                    write-host "|" -ForeGroundColor DARKGRAY -BackGroundColor DARKGRAY;
                }
                elseif ($_ -like '*Bad*credentials*') {
                    write-host "Bad Credentials" -NoNewline -ForeGroundColor RED -BackGroundColor BLACK;
                    $my_TmpString = "]"
                    foreach ($i in 0..($my_SepLength-39)) { $my_TmpString += -join " " }
                    write-host ("{0}" -f $my_TmpString) -NoNewline -ForeGroundColor GRAY -BackGroundColor BLACK;
                    write-host "|" -ForeGroundColor DARKGRAY -BackGroundColor DARKGRAY;
                }
                else {
                    write-host "FAIL" -NoNewline -ForeGroundColor RED -BackGroundColor BLACK;
                    $my_TmpString = "]"
                    foreach ($i in 0..($my_SepLength-28)) { $my_TmpString += -join " " }
                    write-host ("{0}" -f $my_TmpString) -NoNewline -ForeGroundColor GRAY -BackGroundColor BLACK;
                    write-host "|" -ForeGroundColor DARKGRAY -BackGroundColor DARKGRAY;
                }
            }
            write-progress -id 2 -parentid 1 -activity " " -status "Enumerating JSON values..." -complete
        }
        function collect_cluster_resiliency($my_TargetIP) {
            ## Collect Cluster Resiliency Info
            $my_TmpString1 = "..Parsing Cluster Resiliency"
            write-host "|" -NoNewline -ForeGroundColor DARKGRAY -BackGroundColor DARKGRAY;
            write-host ("{0}" -f $my_TmpString1) -NoNewline -ForeGroundColor GRAY -BackGroundColor BLACK;
            try {
                $my_RestAPIUrl = "https://$($my_TargetIP):9440/PrismGateway/services/rest/v2.0/cluster/domain_fault_tolerance_status/"
                $my_RestResponse = Invoke-RestMethod -Method Get -Uri $my_RestAPIUrl -Headers @{Authorization = "Basic $base64AuthInfo" } -Credential $my_Credential -ContentType "application/json"
                $my_ArrClusterResiliency = @()
                [int]$my_int = 0
                $my_Cluster_Name = mformat-string($my_ClusterHash.Item($my_TargetIP))
                $my_RestResponse | % {
                    write-progress -id 2 -parentid 1 -activity " " -status "Enumerating JSON values..." -percentcomplete ($my_int / @($my_RestResponse).count * 100)
                    $my_TmpClusterResiliencyObj = new-object psobject
                    $my_domain_type = $_.domain_type
                    $my_TmpClusterResiliencyObj | Add-Member -MemberType NoteProperty -Name "Cluster Name" -value $my_Cluster_Name
                    $my_TmpClusterResiliencyObj | Add-Member -MemberType NoteProperty -Name "Type" -value $my_domain_type
                    [int]$my_total = 0
                    if ($my_domain_type -eq "DISK") {
                        $_.component_fault_tolerance_status.psobject.properties | foreach-object { $my_total = $my_total + $_.value.number_of_failures_tolerable }
                        if ($my_total -eq 5) { $my_TmpClusterResiliencyObj | Add-Member -MemberType NoteProperty -Name "Resiliency" -value "Good" } else { $my_TmpClusterResiliencyObj | Add-Member -MemberType NoteProperty -Name "Resiliency" -value "Bad" }
                    }
                    $_.component_fault_tolerance_status.psobject.properties | foreach-object {
                        [string]$my_res_name = mformat-string($_.name)
                        [string]$my_res_status = $_.value.number_of_failures_tolerable
                        [string]$my_res_message = $_.value.details.message
                        if ([string]::IsNullOrEmpty($my_res_status)) { $my_res_status = "0" }
                        if ($my_res_name -eq "STATIC_CONFIGURATION") { $my_res_name = "Resiliency"; if ($my_res_status -eq "1") { $my_res_status = "Good" } else { if ([string]::IsNullOrEmpty($my_res_message)) { $my_res_status = "Bad" } } }
                        if (($my_domain_type -eq "RACKABLE_UNIT") -and ($my_res_status -eq "0")) { $my_res_status = $my_res_message }
                        if (($my_domain_type -eq "RACK") -and ($my_res_status -eq "0")) { $my_res_status = $my_res_message }
                        $my_TmpClusterResiliencyObj | Add-Member -MemberType NoteProperty -Name $my_res_name -value $my_res_status
                    }
                    $my_ArrClusterResiliency += $my_TmpClusterResiliencyObj
                }
                $my_ArrClusterResiliency | export-csv $my_File_2 -append -notypeinformation -force
                write-host " [" -NoNewline -ForeGroundColor GRAY -BackGroundColor BLACK;
                write-host "OK" -NoNewline -ForeGroundColor GREEN -BackGroundColor BLACK;
                $my_TmpString = "]"
                foreach ($i in 0..($my_SepLength-35)) { $my_TmpString += -join " " }
                write-host ("{0}" -f $my_TmpString) -NoNewline -ForeGroundColor GRAY -BackGroundColor BLACK;
                write-host "|" -ForeGroundColor DARKGRAY -BackGroundColor DARKGRAY;
            }
            catch {
                write-host " [" -NoNewline -ForeGroundColor GRAY -BackGroundColor BLACK;
                if ($_ -like '*Password*failed*') {
                    write-host "Bad Password" -NoNewline -ForeGroundColor RED -BackGroundColor BLACK;
                    $my_TmpString = "]"
                    foreach ($i in 0..($my_SepLength-45)) { $my_TmpString += -join " " }
                    write-host ("{0}" -f $my_TmpString) -NoNewline -ForeGroundColor GRAY -BackGroundColor BLACK;
                }
                elseif ($_ -like '*Bad*credentials*') {
                    write-host "Bad Credentials" -NoNewline -ForeGroundColor RED -BackGroundColor BLACK;
                    $my_TmpString = "]"
                    foreach ($i in 0..($my_SepLength-48)) { $my_TmpString += -join " " }
                    write-host ("{0}" -f $my_TmpString) -NoNewline -ForeGroundColor GRAY -BackGroundColor BLACK;
                }
                else {
                    write-host "FAIL" -NoNewline -ForeGroundColor RED -BackGroundColor BLACK;
                    $my_TmpString = "]"
                    foreach ($i in 0..($my_SepLength-37)) { $my_TmpString += -join " " }
                    write-host ("{0}" -f $my_TmpString) -NoNewline -ForeGroundColor GRAY -BackGroundColor BLACK;
                }
                write-host "|" -ForeGroundColor DARKGRAY -BackGroundColor DARKGRAY;
            }
            write-progress -id 2 -parentid 1 -activity " " -status "Enumerating JSON values..." -complete
            ## Collect Cluster Info
        }

        if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type) {
            $my_CertCallback = @"
                using System;
                using System.Net;
                using System.Net.Security;
                using System.Security.Cryptography.X509Certificates;
                public class ServerCertificateValidationCallback {
                    public static void Ignore() {
                        if (ServicePointManager.ServerCertificateValidationCallback ==null) { ServicePointManager.ServerCertificateValidationCallback += delegate ( Object obj, X509Certificate certificate, X509Chain chain, SslPolicyErrors errors )  { return true; }; }
                    }
                }
"@
            Add-Type $my_CertCallback
        }
        [ServerCertificateValidationCallback]::Ignore()
        [net.servicepointmanager]::securityprotocol = [net.securityprotocoltype]::tls12
        
        $my_WorkingDir = $env:Temp # split the execution full path from the filename to create a working directory variable.
        $my_File_1 = "$($my_WorkingDir)\Nutanix_Clusters_$((get-date -uformat '%m%d%Y')).csv"
        $my_File_2 = "$($my_WorkingDir)\Nutanix_Resiliency_$((get-date -uformat '%m%d%Y')).csv"
        $my_File_3 = "$($my_WorkingDir)\Nutanix_Nodes_$((get-date -uformat '%m%d%Y')).csv"
        [int]$my_int1 = 0
        if (test-path $my_File_1) { remove-item $my_File_1 }
        if (test-path $my_File_2) { remove-item $my_File_2 }
        if (test-path $my_File_3) { remove-item $my_File_3 }
        $my_SepLength = $my_File_2.length+10
        foreach ($i in 0..($my_SepLength)) { $my_LineDiv += "-" }
        write-host $my_LineDiv -ForeGroundColor BLACK -BackGroundColor DARKGRAY;
        write-host "Collecting " -NoNewline -ForeGroundColor BLACK -BackGroundColor DARKGRAY;
        write-host "NUTANI" -NoNewline -ForeGroundColor BLUE -BackGroundColor DARKGRAY;
        write-host "X" -NoNewline -ForeGroundColor GREEN -BackGroundColor DARKGRAY;
        $my_TmpString = " Cluster Information"
        foreach ($i in 0..($my_SepLength-38)) { $my_TmpString += -join " " }
        write-host ("{0}" -f $my_TmpString) -ForeGroundColor BLACK -BackGroundColor DARKGRAY;
        write-host $my_LineDiv -ForeGroundColor BLACK -BackGroundColor DARKGRAY;
        $my_ClusterHash = @{}
        foreach ($my_Cluster in $my_ClusterArrayIP) {
            if (isonline($my_Cluster.trim())) {
                write-progress -id 1 -Activity "Collecting data" -status "Parsing REST data for $($my_Cluster)" -percentcomplete ($my_int1 / $my_ClusterArrayIP.count * 100)
                if ($my_Credentials) {
                    $my_Credential = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $my_Credentials.username, $my_Credentials.password
                    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $my_Credentials.username,$my_Credentials.password)))
                    collect_cluster_info($my_Cluster)
                    collect_cluster_resiliency($my_Cluster)
                    collect_node_info($my_Cluster)
                }
                else {
                    $my_TmpString = "..No credentials!"
                    write-host "|" -NoNewline -ForeGroundColor DARKGRAY -BackGroundColor DARKGRAY;
                    foreach ($i in 0..($my_SepLength-19)) { $my_TmpString += -join " " }
                    write-host ("{0}" -f $my_TmpString) -NoNewline -ForeGroundColor RED -BackGroundColor BLACK;
                    write-host "|" -ForeGroundColor DARKGRAY -BackGroundColor DARKGRAY;
                }
                $my_int1++
            }
        }
        write-progress -id 1 -Activity "Collecting data" -status "Done..." -complete
        write-host $my_LineDiv -ForeGroundColor BLACK -BackGroundColor DARKGRAY;
        write-host "|" -NoNewline -ForeGroundColor DARKGRAY -BackGroundColor DARKGRAY;
        $my_TmpString = "Done!"
        foreach ($i in 0..($my_SepLength-7)) { $my_TmpString += -join " " }
        write-host ("{0}" -f $my_TmpString) -NoNewline -ForeGroundColor GRAY -BackGroundColor BLACK;
        write-host "|" -ForeGroundColor DARKGRAY -BackGroundColor DARKGRAY;
        if ((test-path $my_File_1) -or (test-path $my_File_2)) {
            write-host $my_LineDiv -ForeGroundColor BLACK -BackGroundColor DARKGRAY;
        }
        if (test-path $my_File_1) {
            write-host "|" -NoNewline -ForeGroundColor DARKGRAY -BackGroundColor DARKGRAY;
            $my_TmpString = "File 1: $($my_File_1)"
            foreach ($i in 0..(($my_SepLength-$my_TmpString.length)-2)) { $my_TmpString += -join " " }
            write-host ("{0}" -f $my_TmpString) -NoNewline -ForeGroundColor GRAY -BackGroundColor BLACK;
            write-host "|" -ForeGroundColor DARKGRAY -BackGroundColor DARKGRAY;
        }
        if (test-path $my_File_2) {
            write-host "|" -NoNewline -ForeGroundColor DARKGRAY -BackGroundColor DARKGRAY;
            $my_TmpString = "File 2: $($my_File_2)"
            foreach ($i in 0..(($my_SepLength-$my_TmpString.length)-2)) { $my_TmpString += -join " " }
            write-host ("{0}" -f $my_TmpString) -NoNewline -ForeGroundColor GRAY -BackGroundColor BLACK;
            write-host "|" -ForeGroundColor DARKGRAY -BackGroundColor DARKGRAY;
        }
        if (test-path $my_File_3) {
            write-host "|" -NoNewline -ForeGroundColor DARKGRAY -BackGroundColor DARKGRAY;
            $my_TmpString = "File 3: $($my_File_3)"
            foreach ($i in 0..(($my_SepLength-$my_TmpString.length)-2)) { $my_TmpString += -join " " }
            write-host ("{0}" -f $my_TmpString) -NoNewline -ForeGroundColor GRAY -BackGroundColor BLACK;
            write-host "|" -ForeGroundColor DARKGRAY -BackGroundColor DARKGRAY;
        }
        write-host $my_LineDiv -ForeGroundColor BLACK -BackGroundColor DARKGRAY;
        $ErrorActionPreference = $my_temperract

    }

    function Get-NTNXHost
    {
        <#
        .SYNOPSIS
            Returns Hosts\host from the Nutanix API
    
        .DESCRIPTION
            Uses the Nutanix API to get a list of VMs.  If a Name is specified, a 
            single VM is returned.  If no Name is specified, all VMs are returned.
    
            An array of custom Powershell objects are created from the VMs returned from the API.
    
        .PARAMETER ElementIP
            This paraeter can be the name or the IP of the Prism Element cluster.
    
        .PARAMETER Name
            The name of the host to retrieve.
    
        .EXAMPLE
            Get-NTNXHost
    
        .EXAMPLE
    
            Get-NTNXHost -Name <Name> -RawOutput
    
        .NOTES
            Author:  Dusty Lane
            Website: http://nutanix.com
            Date:    1/22/2021
        #>
    
        [CmdletBinding()]
        param
        (
            [Parameter(Mandatory=$false)]
            [string]$ElementIp = $Global:ElementIP,
            [Parameter(Mandatory=$false,Position=0)]
            [string]$Name,
            [switch]$RawOutput
        )
    
        $Params = @{
            uri = "https://$($ElementIp):9440/PrismGateway/services/rest/v2.0/hosts"
            method = "GET"
        }
    
        if ($Name)
        {
            $hosts = (Get-NtnxApiResponse @Params).entities | Where-Object -Property name -eq "$($Name)"
        }
        else
        {
            $hosts = (Get-NtnxApiResponse @Params).entities
        }
    
        if ($RawOutput)
        {
            $hosts
        }
        else
        {
            foreach ($h in $hosts)
            {
                [PSCustomObject]@{
                    Name      = $h.name
                    VMCount         = $h.num_vms
                    DegradedStatus  = $h.is_degraded
                    Memory  = $h.memory_capacity_in_bytes
                    MaintenanceMode = $h.host_in_maintenance_mode
                    oplogSize = $h.oplog_disk_size
    
                }
            }
        }
    }

    function Get-NTNXProtectionDomains
    {
        <#
        .SYNOPSIS
            Produces a list of current protection domains on a nutanix cluster.

        .DESCRIPTION
            This function is designed to enumerate the current protection domains on a cluster.
            This creates a custom powershell object with the Name, Entities (VMs), and counts the 
            VMs in each protection domain.

        .PARAMETER ElementIP
            This paraeter can be the name or the IP of the Prism Element cluster.

        .EXAMPLE
            Get-NTNXProtectionDomains -ElementIP 192.168.1.25

        .EXAMPLE
            Get-NTNXProtectionDomain | ft PDName, VMCount, Active

            PDName                      VMCount Active
            ------                      ------- ------
            PD1-LocalClus-RemoteClus       6     True
            PD2-RemoteClus-LocalClus       0     False

        .EXAMPLE
            (Get-NTNXProtectionDomains -Name PD1-LocalClus-RemoteClus -Rawoutput).vms.vm_name

            # in this example, we get a list of VMs protected by the PD.
        .NOTES
            Author:  Dusty Lane
            Website: http://nutanix.com
            Date:    1/22/2021
        #>

        [CmdletBinding()]
        [Alias("Get-NTNXProtectionDomain")]
        param
        (
            [Parameter(Mandatory=$false)]
            [string]$ElementIp = $Global:ElementIP,
            [Parameter(Mandatory=$false)]
            [string]$Name,
            [switch]$RawOutput            
        )
    
        $Params = @{
            uri = "https://$($ElementIp):9440/PrismGateway/services/rest/v2.0/protection_domains"
            method = "GET"
        }
    
        if ($name)
        {
            $PDs = (Get-NtnxApiResponse @Params).entities | Where-Object {$_.name -eq "$name"}
        }
        else
        {
            $PDs = (Get-NtnxApiResponse @Params).entities
            ## Write-Host "Protection Domains `n $($PDs)"
        }

        if ($RawOutput)
        {
            ## this is so that we are not testing on a negative.....
            $PDS
        }
        else
        {
            foreach ($PD in $PDs)
            {
                [PSCustomObject]@{
                    ElementIp   = $ElementIp
                    PDName      = $PD.name
                    VMCount     = ($PD.VMS | Measure-Object).count
                    Remotesite  = $PD.Remote_site_names
                    Active      = $PD.active
                    VMs         = $PD.vms

                }
            }
        }
    }

    function Get-NTNXProtectionDomainStatus
    {
        <#
        .SYNOPSIS
            Gets the status of the protection domains.

        .DESCRIPTION
            tbd

        .PARAMETER ElementIP
            This paraeter can be the name or the IP of the Prism Element cluster.

        .EXAMPLE
            Get-NTNXProtectionDomainStatus -ElementIP 192.168.1.25

        .NOTES
            Author:  Dusty Lane
            Website: http://nutanix.com
            Date:    1/22/2021
        #>

        [CmdletBinding()]
        param
        (
            [Parameter(Mandatory=$false)]
            [string]$ElementIp = $Global:ElementIP
        )
    
        $Params = @{
            uri = "https://$($ElementIp):9440/PrismGateway/services/rest/v2.0/protection_domains/status"
            method = "GET"
        }
    
        Get-NtnxApiResponse @Params

    }

    function Get-NTNXProtectionDomainRemoteSites
    {
               <#
        .SYNOPSIS
            Gets the list of remote sites for protection domains\async dr.

        .DESCRIPTION
            tbd

        .PARAMETER ElementIP
            This paraeter can be the name or the IP of the Prism Element cluster.

        .EXAMPLE
            Get-NTNXProtectionDomainRemoteSites -ElementIP 192.168.1.25

        .NOTES
            Author:  Dusty Lane
            Website: http://nutanix.com
            Date:    1/22/2021
        #>

        [CmdletBinding()]
        param
        (
            [Parameter(Mandatory=$false)]
            [string]$ElementIp = $Global:ElementIP
        )
    
        $Params = @{
            uri = "https://$($ElementIp):9440/PrismGateway/services/rest/v2.0/remote_sites"
            method = "GET"
        }
    
        $Sites = (Get-NtnxApiResponse @Params).Entities

        Foreach ($site in $Sites)
        {
            [PSCustomObject]@{
                Name    = $Site.name
                uuid    = $site.uuid
                RemoteIP  = $Site.remote_ip_ports
                Status  = $Site.status
            }
        }

    }

    function Get-NTNXSnapshot
    {
        <#
        .SYNOPSIS
            Gets snapshots of a specific VM

        .DESCRIPTION
            This function gets a list of snapshots for a named VM.

        .PARAMETER ElementIP
            The IP of the Prism Element API to store as a global variable.

        .PARAMETER Computername
            The Name of the VM.

        .EXAMPLE

            Get-NTNXSnapshot -Computername Server1

        .EXAMPLE

            (get-ntnxvm | Where-Object {$_.name -like "test*"}).name | Get-NTNXSnapshot

            uuid              : 87f5999b-acc1-4794-897a-5325deeb294f
            deleted           : False
            logical_timestamp : 1
            created_time      : 1610045008968380
            group_uuid        : c112d309-72b4-405b-b1bb-a818a25150a3
            vm_uuid           : 9ed3caab-2847-4db9-9ccc-7d74e56bb97d
            snapshot_name     : 20210107-1143
            vm_create_spec    : @{boot=; memory_mb=2048; name=Test124; num_cores_per_vcpu=1; num_vcpus=1; vm_disks=System.Object[]; vm_logical_timestamp=-1; vm_nics=System.Object[]}

        .NOTES
            Author:  Dusty Lane
            Website: http://nutanix.com
            Date:  1/22/2021
        #>
        [CmdletBinding()]
        param
        (
            [Parameter(Mandatory=$false)]
            [string]$ElementIp = $Global:ElementIP,
            [Parameter(Mandatory=$True,Position=0,ValueFromPipeline)]
            [object[]]$Computername
        )
        BEGIN
        {
            ##Using the process feature to be able to use the pipeline capability
        }
        PROCESS
        {
            ## Because we want to accept objects on a pipeline, we need to change the 
            ## object into a string.  
            [string]$Name = $Computername
            
            Try
            {
                $VMUUID = (get-ntnxvm -Computername $Name | Select-Object -Property uuid).uuid
            }
            Catch
            {
                Write-Warning -Message "Failed to get VM from Prism.  Please review the computername and try again."
                break
            }

            $Params = @{
                uri = "https://$($ElementIP):9440/PrismGateway/services/rest/v2.0/snapshots/?vm_uuid=$($VMUUID)"
                method = "GET"
            }

            $snaps = (Get-NTNXApiResponse @Params).Entities

            foreach ($snap in $snaps)
            {
                [PSCustomObject]@{
                    uuid    = $snap.uuid
                    Created = Convert-UsecToHuman $($snap.created_time)
                    Snapshot_Name = $snap.snapshot_name
                    vm_create_spec = $snap.vm_create_spec
                    vm_uuid = $snap.vm_uuid
                }
            }

        }
        END
        {
            ## This is the end of the Process block.
        }
    }
    
    function Get-NTNXUnprotectedVMs
    {
        <#
        .SYNOPSIS
            creates an array of unprotected VMs.

        .DESCRIPTION
            Connects to the Nutanix API, obtaining unprotected VMs.  The function creates
            a custom powershell object with keys for VM Name and VM uuid.

        .PARAMETER ElementIP
            This paraeter can be the name or the IP of the Prism Element cluster.

        .EXAMPLE
            
            Get-NTNXUnprotectedVMs -ElementIP 192.168.1.25

            ElementIp   Name             uuid
            ---------   ----             ----
            192.168.1.25 HOST3-PC         1962edba-61fc-4782-9d3d-3190658d763f
            192.168.1.25 Template-Win2016 be34480b-a171-410e-8757-6d0ab0d92d48

        .NOTES
            Author:  Dusty Lane
            Website: http://nutanix.com
            Date:    1/22/2021
        #>

        [CmdletBinding()]
        param
        (
            [Parameter(Mandatory=$false)]
            [string]$ElementIp = $Global:ElementIP
        )
    
        $Params = @{
            uri = "https://$($ElementIp):9440/PrismGateway/services/rest/v2.0/protection_domains/unprotected_vms"
            method = "GET"
        }
    
        $VMs = (Get-NtnxApiResponse @Params).entities
        ## Write-Host "Protection Domains `n $($PDs)"
        
        foreach ($VM in $VMs)
        {
            [PSCustomObject]@{
                ElementIp   = $ElementIp
                Name    = $vm.vm_name
                uuid    = $vm.uuid
            }
        }
    }
    
    function Get-NTNXVLAN
    {
        <#
        .SYNOPSIS
            Gets a list of VLANs from Prism Element

        .DESCRIPTION
            Connects to the Nutanix API, getting a list of VLANs.  The function
            creates a custom powershell object with Kys for VLAN Name and VLAN uuid.

        .PARAMETER ElementIP
            This paraeter can be the name or the IP of the Prism Element cluster.
        
        .PARAMETER VLAN
            This parameter is used to filter the output to a specific VLAN.

        .EXAMPLE
            
            Get-NTNXVLAN -ElementIP 192.168.1.25

            ElementIp   Name            Uuid                                 VlanId
            ---------   ----            ----                                 ------
            192.168.1.25 IT_88          3111d23c-9c50-4dac-b2fc-dbdd585be7a5     88
            192.168.1.25 Fin_21         3609e538-9f84-4d02-8e8d-a0f17154c96a     21
            192.168.1.25 Net_1          4868e5c0-831f-4177-9d6d-b5e7dafd614e      1
            192.168.1.25 Eng_22         5f576c71-6d19-4384-9a17-3bf3311f4580     22
            192.168.1.25 Native_0       6f7bb9d4-e61e-4f4b-80c4-3193105a5e53      0
            192.168.1.25 PRIVATE_999    b2fa2662-b17e-48ff-9f32-5e4d5ca17fb1    999

        .EXAMPLE
            
            Get-NTNXVLAN -ElementIP 192.168.1.25 -VLAN 88


            ElementIp   Name            Uuid                                 VlanId
            ---------   ----            ----                                 ------
            192.168.1.25 IT_88          3111d23c-9c50-4dac-b2fc-dbdd585be7a5     88

       
        .NOTES
            Author:  Dusty Lane
            Website: http://nutanix.com
            Date:    1/22/2021
        #>

        [CmdletBinding()]
        param
        (
            [Parameter(Mandatory=$false)]
            [string]$ElementIp = $Global:ElementIP,
            [Parameter(Mandatory=$false)]
            [string]$VLAN,
            [Parameter(Mandatory=$false)]
            [string]$UUID
        )
        
        $Params = @{
            uri = "https://$($ElementIp):9440/PrismGateway/services/rest/v2.0/networks"
            method = "GET"
        }

        
        if ($VLAN)
        {
            ## Filtering networks....
            $Networks = (Get-NtnxApiResponse @params).entities | Where-Object { $_.name -eq "$vlan" } 
        }
        elseif ($UUID)
        {
            write-output "here"
            ## Filtering networks....
            $Networks = (Get-NtnxApiResponse @params).entities | Where-Object { $_.uuid -eq "$($UUID)" } 
        }
        else
        {
            $Networks = (Get-NtnxApiResponse @params).entities | Sort-Object -Property "vlan_id"
        }

        foreach ($Network in $Networks)
        {
            [PSCustomObject]@{
                ElementIp   = $ElementIp
                Name        = $Network.name
                Uuid        = $Network.uuid
                VlanId      = $Network.vlan_id
            }
        }
    }

    function Get-NTNXVM
    {
        <#
        .SYNOPSIS
            Returns VMs\VM from the Nutanix API

        .DESCRIPTION
            Uses the Nutanix API to get a list of VMs.  If a Computername is specified, a 
            single VM is returned.  If no Computername is specified, all VMs are returned.

            An array of custom Powershell objects are created from the VMs returned from the API.

        .PARAMETER ElementIP
            This paraeter can be the name or the IP of the Prism Element cluster.

        .PARAMETER Computername
            The name of the VM to retrieve.

        .EXAMPLE
            GetNTNXVM -ElementIP 192.168.1.25 -Computername HOST3-PC

            allow_live_migrate   : True
            gpus_assigned        : False
            description          : NutanixPrismCentral
            ha_priority          : 0
            host_uuid            : 82076ec5-2338-4a27-a226-a6ba8cb40648
            memory_mb            : 30720
            name                 : HOST3-PC
            num_cores_per_vcpu   : 1
            num_vcpus            : 6
            power_state          : on
            timezone             : UTC
            uuid                 : 1962edba-61fc-4782-9d3d-3190658d763f
            vm_features          : @{VGA_CONSOLE=True; AGENT_VM=False}
            vm_logical_timestamp : 5
            machine_type         : pc

        .EXAMPLE
            GetNTNXVM -ElementIP 192.168.1.25 -Computername HOST3-PC | Format-Table Name, Memory_mb, Num_vcpus, Power_state -autosize

            name     memory_mb num_vcpus power_state
            ----     --------- --------- -----------
            HOST3-PC     30720         6 on

        .EXAMPLE
            GetNTNXVM -ElementIP 192.168.1.25 | Format-Table Name, Memory_mb, Num_vcpus, Power_state -autosize

            name             memory_mb num_vcpus power_state
            ----             --------- --------- -----------
            Server1               30720        6 on
            Template-Win10-1      2048         1 off
            Template-Win7-1       2048         1 off
            Template-Win2016      30720        4 off

        .EXAMPLE
            # In this example, we grab the name, ip and vlan name of all VMs.

            GetNTNXVM -ElementIP 192.168.1.25 | Format-Table Name, @{Label="ip"; Expression= {$_.vm_nics.ip_address}}, @{Label="vlan";Expression ={(Get-NTNXVlan -UUID $_.vm_nics.network_uuid).name}} -autosize


        .NOTES
            Author:  Dusty Lane
            Website: http://nutanix.com
            Date:    1/22/2021
        #>

        [CmdletBinding()]
        param
        (
            [Parameter(Mandatory=$false)]
            [string]$ElementIp = $Global:ElementIP,
            [Parameter(Mandatory=$false,Position=0)]
            [string]$Computername
        )
    
        $Params = @{
            uri = "https://$($ElementIp):9440/PrismGateway/services/rest/v2.0/vms?include_vm_nic_config=true&include_vm_disk_config=true"
            method = "GET"
        }
    
        if ($Computername)
        {
            (Get-NtnxApiResponse @Params).entities | Where-Object -Property name -eq "$($computername)"
        }
        else
        {
            (Get-NtnxApiResponse @Params).entities
        }
    }

    function Get-NTNXVMNIC
    {
        <#
        .SYNOPSIS
            Gets a NIC(s) for a given VM

        .DESCRIPTION
            Gets a NIC(s) for a given VM

        .PARAMETER ElementIP
            This paraeter can be the name or the IP of the Prism Element cluster.
        
        .PARAMETER VMUUID
            

        .EXAMPLE
            
            tbd

        .NOTES
            Author:  Dusty Lane
            Website: http://nutanix.com
            Date:    1/22/2021
        #>

        [CmdletBinding()]
        param
        (
            [Parameter(Mandatory=$false)]
            [string]$ElementIp = $Global:ElementIP,
            [Parameter(Mandatory=$false)]
            [string]$VMUUID
        )
        
        Break
        ##  this function is not ready yet

        $Params = @{
            uri = "https://$($ElementIp):9440/PrismGateway/services/rest/v2.0/vms/$($VMUUID)/nics"
            method = "GET"
        }

        if ($VLAN)
        {
            ## Filtering networks....
            $Networks = (Get-NtnxApiResponse @params).entities | Where-Object { $_.name -like "*$vlan*" } 
        }
        else
        {
            $Networks = (Get-NtnxApiResponse @params).entities | Sort-Object -Property "vlan_id"
        }
        foreach ($Network in $Networks)
        {
            [PSCustomObject]@{
                ElementIp   = $ElementIp
                Name        = $Network.name
                Uuid        = $Network.uuid
                VlanId      = $Network.vlan_id
            }
        }
    }

    function New-NTNXVLANAHV
    {
        <#
        .SYNOPSIS
            Add VLAN to an AHV cluster

        .DESCRIPTION
            This function is designed to add a VLAN to an AHV cluster with the Name and the VLAN ID\number.

        .PARAMETER ElementIP
            This paraeter can be the name or the IP of the Prism Element cluster.
            
        .PARAMETER NAME
            This paraeter is the name of the vlan.  

        .PARAMETER ID
            This is the VLAN ID\tag.  It can only be a number.

        .EXAMPLE
            New-NTNXVLAN-AHV -ElementIP 192.168.1.25 -Name 1308_MyCoolVlan -ID 1308

        .EXAMPLE
            # Create a hashtable of the vlans. 

            $vlans = @{vlan21 = 21; vlan22 = 22}
            
            # Loop through each key in the hashtable, mapping it to a variable.  Then call the function passing
            # the variables

            $vlans.keys | ForEach-Object {
                $Name = $_
                $ID = $vlans[$_]
                write-output "$Name $ID"
                New-NTNXVLAN-AHV -Name $Name -ID $ID
            }

        .EXAMPLE
            # Create a csv file with Name, ID as the header and then followup with vlans
            $VLANS = Import-Csv ./vlans.csv

            # Loop through the PSCustomObject and call the function

            foreach ($vlan in $vlans)
            {
                New-NTNXVLAN-AHV -Name $Name -ID $ID
            }

        .NOTES
            Author:  Dusty Lane
            Website: http://nutanix.com
            Date:    1/22/2021
        #>

        [CmdletBinding()]
        param
        (
            [Parameter(Mandatory=$false)]
            [string]$ElementIp = $Global:ElementIP,
            [Parameter(Mandatory=$true)]
            [string]$Name,
            [Parameter(Mandatory=$true)]
            [Int32]$ID
        )
       
        $Body = @"
        {
            "annotation": "Created by New-NTNXVLAN-AHV",
            "name": "$($Name)",
            "vlan_id": $($ID)
          }
"@

        ## specify the url to create the new vlan via the API
        $Params = @{
            uri = "https://$($ElementIp):9440/PrismGateway/services/rest/v2.0/networks"
            method = "POST"
        }

        ## capture the creation via the object CreateTaskID
        try
        {
            Write-Verbose "Attempting to provision the vlan"
            Get-NtnxApiResponse -Body $Body @params
            Write-NTNXLog -Message "`nVLAN ($($ID)) provisioning task completed successfully."
        }
        catch
        {
            Write-NTNXLog -Message "Encountered error adding VLAN to cluster ($($error[0]))"
        }


    }
    
    function Protect-NTNXVM
    {
        <#
        .SYNOPSIS
            Adds an entity to a protection domain.

        .DESCRIPTION
            Uses the Nutanix API to add a VM to a protection domain (PD).

            The protection domains are gathered from the list of PDs on the cluster
            and sorted by their VM count.  The Computername is then added to the PD
            with the least number of entities associated to it.

        .PARAMETER ElementIP
            This paraeter can be the name or the IP of the Prism Element cluster.

        .PARAMETER Computername
            Name of a VM hosted a nutanix cluster.

        .PARAMETER ProtectionDomain
            Name of the protection domain you want to add the VM to.  If the PD is 
            not named, the VM will be added to the PD with the lowest count.

        .EXAMPLE
            Protect-NTNXVM -ElementIP 192.168.1.25 -Computername Server1

        .NOTES
            Author:  Dusty Lane
            Website: http://nutanix.com
            Date:    1/22/2021
        #>

        [CmdletBinding()]
        param
        (
            [Parameter(Mandatory=$false)]
            [string]$ElementIp = $Global:ElementIP,
            [Parameter(Mandatory=$true,ValueFromPipeline)]
            [object[]]$Computername,
            [Parameter(Mandatory=$false)]
            [ValidateScript({(Get-NTNXProtectionDomains | select-object -property pdname | where-object -property pdname -eq $_).pdname})]
            [string]$ProtectionDomain,
            [Parameter(Mandatory=$false)]
            [string]$ExcludeProtectionDomains
        )
        BEGIN
        {
        }
        PROCESS
        {
            #find the protection domain with the lowest VM count
            
            $ClusterCheck = Get-NtnxApiResponse -Uri "https://$($ElementIP):9440/PrismGateway/services/rest/v2.0/cluster/" -Method "Get"
            
            If ($ProtectionDomain)
            {
                $PD = Get-NTNXProtectionDomains | where-object -property pdname -eq $ProtectionDomain
            }
            else
            {
                $PDs = Get-NTNXProtectionDomains | Where-Object {$_.active -eq $true}
                
                If ($ExcludeProtectionDomains)
                {
                    $PDS = $PDS | where-object -property pdname -NotLike *$ExcludeProtectionDomains*
                }
                
                $PD = ($PDS | Sort-Object -Property vmcount)[0]

            }
              
            $Params = @{
                uri = "https://$($ElementIp):9440/PrismGateway/services/rest/v2.0/protection_domains/$($PD.pdname)/protect_vms"
                method = "POST"
            }

            ## Because we want to accept objects on a pipeline, we need to change the 
            ## object into a string.  
            [string]$Name = $Computername
            $VM = Get-NTNXVM -Computername $Name

            ## here-string required for the body of the restmethod post.
            $Body = @"
            {
                "uuids": [
                    "$($vm.uuid)"
                ]
            }
"@
        
            ## Make the call to the Nutanix API.  The Params variable is declared in the BEGIN block.

            $HideValue = Get-NtnxApiResponse -Body $Body @Params

            Write-NTNXLog -Message "Adding $($Name) to $($PD.pdname) protection domain."
        }
        END
        {
        }
    }

    function Remove-NTNXSnapshot
    {
        <#
        .SYNOPSIS
            Gets snapshots of a specific VM

        .DESCRIPTION
            This function gets a list of snapshots for a named VM.

        .PARAMETER ElementIP
            The IP of the Prism Element API to store as a global variable.

        .PARAMETER Computername
            The Name of the VM.

        .PARAMETER SnapshotUUID
            The UUID of the snapshot.  Can be obtained with Get-NTNXSnapshot.

        .EXAMPLE

            $uuid = Get-NTNXSnapshot -Computername TestVM126 | Where-Object {$_.snapshot_name -like "20210119*"}

            Remove-NTNXSnapshot -Computername TestVM126 -SnapshotUUID $uuid -Confirm:$false

        .NOTES
            Author:  Dusty Lane
            Website: http://nutanix.com
            Date:    1/22/2021
        #>
        [CmdletBinding(
            SupportsShouldProcess = $true,
            ConfirmImpact = 'High')]
        param
        (
            [Parameter(Mandatory=$false)]
            [string]$ElementIp = $Global:ElementIP,
            [Parameter(Mandatory=$True,Position=0)]
            [string]$Computername,
            [Parameter(Mandatory=$True,Position=1)]
            [string]$SnapshotUUID
        )

        if ($PSCmdlet.ShouldProcess($Computername))
        {
            [string]$Name = $Computername
                
            Try
            {
                $Snapshot = Get-NTNXSnapshot -Computername $Name | Where-Object {$_.uuid -eq "$SnapshotUUID"}
                if ($null -eq $Snapshot)
                {
                    Write-Warning -Message "Snapshot not found"
                    Break
                }
            }
            Catch
            {
                Write-Warning -Message "Failed to get snapshot UUID from Prism.  Please review the computername\snapshot and try again."
                break
            }

            $Params = @{
                uri = "https://$($ElementIP):9440/PrismGateway/services/rest/v2.0/snapshots/$($Snapshot.uuid)"
                method = "DELETE"
            }

            Get-NTNXApiResponse @Params
            Write-NTNXLog -Message "Issued delete command to Nutanix API to remove snapshot ($($Snapshot.snapshot_name)) from $Computername"
        }

    }
    
    function Remove-NTNXVM
    {
        <#
        .SYNOPSIS
            Deletes a VM from a Nutanix Cluster

        .DESCRIPTION
            This function will cleanup a VM by removing it from a protection domain and
            deleting it from a cluster.

            Must use the 'confirm' switch with this function.

        .PARAMETER ElementIP
            This paraeter can be the name or the IP of the Prism Element cluster.

        .PARAMETER Computername
            The name of the VM to retrieve.

        .EXAMPLE
            Remove-NTNXVM -ElementIP 192.168.1.25 -Computername Server1 -Confirm:$false

        .NOTES
            Author:  Dusty Lane
            Website: http://nutanix.com
            Date:    1/22/2021
        #>

        [CmdletBinding(
            SupportsShouldProcess = $true,
            ConfirmImpact = 'High')]
        param
        (
            [Parameter(Mandatory=$false)]
            [string]$ElementIp = $Global:ElementIP,
            [Parameter(Mandatory=$true,ValueFromPipeline)]
            [object[]]$Computername
        )
        BEGIN
        {}
        PROCESS
        {
            if ($PSCmdlet.ShouldProcess($Computername))
            {
                [string]$Name = $Computername
                ## Grab the VM as an object
                $VM = Get-NTNXVM -ElementIp $ElementIp -Computername $name

                if (($vm | Measure-Object).count -gt 1)
                {
                    Write-Warning "removing more than one VM at a time is not supported."
                    Break
                }

                ##  Remove from PD if it exists.
                Unprotect-NTNXVM -ElementIp $ElementIp -Computername $name

                $Params = @{
                    uri = "https://$($ElementIP):9440/PrismGateway/services/rest/v2.0/vms/$($VM.uuid)"
                    method = "DELETE"
                }

                Get-NtnxApiResponse @Params

                Write-NTNXLog -Message "Removing $($Computername) from Prism Element ($($ElementIP))"
            }
        }
        END
        {}

    }

    function Remove-NTNXVLANAHV
    {
        <#
        .SYNOPSIS
            Remove VLAN from an AHV cluster

        .DESCRIPTION
            This function is designed to remove a VLAN from an AHV cluster using the name.

        .PARAMETER ElementIP
            This paraeter can be the name or the IP of the Prism Element cluster.
            
        .PARAMETER NAME
            This paraeter is the name of the vlan.  

        .EXAMPLE
            Remove-NTNXVLANAHV -Name 9988_TestVLAN1 -Confirm:$false


        .NOTES
            Author:  Dusty Lane
            Website: http://nutanix.com
            Date:    1/22/2021
        #>

        [CmdletBinding(
            SupportsShouldProcess = $true,
            ConfirmImpact = 'High')]
        param
        (
            [Parameter(Mandatory=$false)]
            [string]$ElementIp = $Global:ElementIP,
            [Parameter(Mandatory=$true)]
            [string]$Name
        )
        if ($PSCmdlet.ShouldProcess($Name))
        {
            Try
            {
                $VLANUUID = (Get-NTNXVLAN -VLAN $Name | Select-Object -Property uuid).uuid
            }
            Catch
            {
                Write-Warning -Message "Failed to get VLAN from Prism.  Please review the Name and try again."
                break
            }

            $Params = @{
                uri = "https://$($ElementIp):9440/PrismGateway/services/rest/v2.0/networks/$($VLANUUID)"
                method = "DELETE"
            }

            Try
            {
                Get-NTNXApiResponse @Params
            }
            Catch
            {
                Write-Warning "Encountered an error attempting to Delete VLAN `n"
                $error[0]
                break
            }

            Write-NTNXLog -Message "Issued request to the API to delete VLAN $Name"

        }
    }
   
    function Set-NTNXCredentials
    {
        <#

        .SYNOPSIS
            Basic script to prestage credential objects.

        .DESCRIPTION
            This is required to use the connect-ntnx with the Credential file switch

        
        .EXAMPLE
            
            Set-NTNXCredentials

            # Follow the onscreen prompts to enter the credentials.


        .NOTES
            Author:  Dusty Lane
            Website: http://nutanix.com
            Date:    1/22/2021
            
        #>

        $Credentials = @()

        $ActiveDirectory = Get-Credential -Message "Enter the username and password for Active Directory."

        $Credentials += [PSCustomObject]@{
            Service  = "ActiveDirectory"
            Credential = $ActiveDirectory
        }

        $NutanixApi = Get-Credential -Message "Enter the username and password for the Nutanix API."

        $Credentials += [PSCustomObject]@{
            Service  = "NutanixApi"
            Credential = $NutanixApi
        }

        $WindowsPassword = Get-Credential -Message "Enter the username and password for the standard Windows Administrator username and password - used for new installs."

        $Credentials += [PSCustomObject]@{
            Service  = "WindowsPassword"
            Credential = $WindowsPassword
        }

        $Credentials | Export-CliXml -Path ~\NutanixSetup.xml -Force
    }

    function Set-NTNXProtectionDomainStatus
    {
        <#
        .SYNOPSIS
            Sets the status of the protection domains.

        .DESCRIPTION
            tbd

        .PARAMETER ElementIP
            This paraeter can be the name or the IP of the Prism Element cluster.

        .PARAMETER ProtectionDomain

        .EXAMPLE
            
            Set-NTNXProtectionDomainStatus -ProtectionDomain PD1-Cluster1-DRCluster1 -Action migrate

            # In this example, we run the command on the local site, migrating the local PD to the remote site.
        
        .EXAMPLE
            
            Set-NTNXProtectionDomainStatus -ProtectionDomain PD1-Cluster1-DRCluster1 -Action activate -confirm:$false

            # in this example, we run the command from the DR site, 'activating' the PDs.  This should ONLY be used in the event
            # that the primary site hosting the protection domains is inaccessible.

        .EXAMPLE
            $PDS = (Get-NTNXProtectionDomains | where-object {$_.active -eq $true}).name

            foreach ($PD in $PDS){Set-NTNXProtectionDomainStatus -ProtectionDomain $PD -Action activate -confirm:$false}

            # in this example, we run the command from the DR site, 'activating' the PDs.  This should ONLY be used in the event
            # that the primary site hosting the protection domains is inaccessible.

        .NOTES
            Author:  Dusty Lane
            Website: http://nutanix.com
            Date:    1/22/2021
        #>

        [CmdletBinding(
            SupportsShouldProcess = $true,
            ConfirmImpact = 'High')]
        param
        (
            [Parameter(Mandatory=$false)]
            [string]$ElementIp = $Global:ElementIP,
            [Parameter(Mandatory=$false)]
            [ValidateScript({(Get-NTNXProtectionDomains | select-object -property pdname | where-object -property pdname -eq $_).pdname})]
            [string]$ProtectionDomain,
            [Parameter(Mandatory=$false)]
            [ValidateSet("activate","migrate","deactivate")]
            [string]$Action,
            [Parameter(Mandatory=$false)]
            [string]$RemoteSite
        )
        if ($PSCmdlet.ShouldProcess($Name))
        {
            $Action = $Action.ToLower()

            $PDInfo = Get-NTNXProtectionDomains | where-object -property pdname -eq $ProtectionDomain

            $PDVMCount = ($PDInfo.VMS | Measure-Object).count

            If ($PDVMCount -lt 1)
            {
                Write-Warning "Possibly connected to secondary site.  Confirm connection to Prism and retry operation `n"
                Break
            }

            $PD = $PDInfo.PDName

            ## Let's check to make sure we are connected to the correct site to migrate


            ## error handling
            If ($Action -eq "migrate")
            {
                if (!($RemoteSite))
                {
                    try
                    {
                        $RemoteSite = (Get-NTNXProtectionDomainRemoteSites).Name
                        Write-Verbose "Remote Site Name:  $RemoteSite"
                    }
                    catch
                    {
                        Write-Warning -Message "Error getting remote site.  A single remote site must be configured and\or specified. `n"
                        break
                    }
                    
                    $Count = ($RemoteSite | Measure-Object).count

                    If ($count -gt 1)
                    {
                        Write-Warning "To migrate from Primary Site to failover site, a single Remote Site must be specified as a parameter. `n "
                        break
                    }
                    elseif ($count -eq 0)
                    {
                        Write-Warning "To migrate from Primary Site to failover site, a single Remote Site must be specified. `n "
                        break
                    }

                    $Body = @"
                    {
                        "value": "$($RemoteSite)"
                    }
"@
                }
            }

            # PrismGateway/services/rest/v2.0/protection_domains/PD1/activate
            $Params = @{
                uri = "https://$($ElementIp):9440/PrismGateway/services/rest/v2.0/protection_domains/$($PD)/$($action)"
                method = "POST"
            }
            
            try
            {
                
                if ($Body)
                {
                    Write-Verbose "Attempting to migrate $PD"
                    Get-NtnxApiResponse -Body $Body @Params
                }
                else
                {
                    Get-NtnxApiResponse @Params
                }
            }
            catch
            {
                Write-Warning "Error encountered attempting to $action $PD `n"
                $error[0]
            }
        }
    }

    function Set-NTNXVMPowerState
    {
        <#
        .SYNOPSIS
            Sets the powerstate of the VM

        .DESCRIPTION
            Uses the Nutanix API to set the powerstate of the VM, either ON or OFF.

        .PARAMETER ElementIP
            This paraeter can be the name or the IP of the Prism Element cluster.

        .PARAMETER Computername
            The name of the VM to retrieve.

        .PARAMETER State
            The state of the VM - ON or OFF

        .EXAMPLE
            Set-NTNXVMPowerState -Computername Server1 -State ON

        .NOTES
            Author:  Dusty Lane
            Website: http://nutanix.com
            Date:    1/22/2021
        #>

        [CmdletBinding()]
        param
        (
            [Parameter(Mandatory=$false)]
            [string]$ElementIp = $Global:ElementIP,
            [Parameter(Mandatory=$true)]
            [ValidateScript({Get-NTNXVM -Computername $_})]
            [string]$Computername,
            [Parameter(Mandatory=$true)]
            [ValidateSet("ON","OFF")] 
            [string]$State

        )

        $VmUuid = (Get-NTNXVM -Computername $Computername).uuid

        $count = ($VmUuid | Measure-Object).Count

        if ($Count -gt 1)
        {
            Write-Warning -Message "More than one computer found.  Exiting."
            break
        }

        ## power on vm
        Write-NTNXLog -Message "Attemping to power $state VM with uuid $VmUuid."
        $Body = @"
        {
            "transition": "$State",
            "uuid": "$VmUuid"
        }
"@

        $Params = @{
            uri = "https://$($ElementIP):9440/PrismGateway/services/rest/v2.0/vms/$VmUuid/set_power_state"
            method = "POST"
        }

        $PowerTaskId = Get-NtnxApiResponse -Body $Body @Params

        ## get result of power task
        Write-NTNXLog -Message "Wait for power $state task $($PowerTaskId.task_uuid) to complete."
        while ($TaskStatus.percentage_complete -ne "100")
        {
            $Params = @{
                uri = "https://$($ElementIP):9440/PrismGateway/services/rest/v2.0/tasks/$($PowerTaskId.task_uuid)"
                method = "GET"
            }

            $TaskStatus = Get-NtnxApiResponse @Params
            Start-Sleep -Seconds 1
        }

        if ($TaskStatus.progress_status -ne "Succeeded")
        {
            throw "Expected power $state task status 'Succeeded' but was '$($TaskStatus.progress_status)' instead."
        }
        Write-NTNXLog -Message "Successfully powered $state $ComputerName."
    }

    function Start-NTNXVMProvisionAHV
    {
        <#
        .SYNOPSIS
            This is a wrapper function for 'Copy-NTNXVirtualMachine'

        .DESCRIPTION
            This is meant to dynamically allow the 'caller' to select from
            multiple choice menus, creating script scope objects and feeding
            them into the command.

        .EXAMPLE
            Start-NTNXVMProvisionAHV

        .NOTES
            Author:  Dusty Lane
            Website: http://nutanix.com
            Date:    1/22/2021
        #>
        
        #region InternalFunctions

        function Show-TemplateSelection
        {
            <#
            .SYNOPSIS
                This is a private function designed to be used in a script or other function.

            .DESCRIPTION
                This function will provide a multiple choice selector for VMs that have the name
                template in them.

            .PARAMETER Templates
                This parameter accepts multiple objects.

            .NOTES
                Author:  Dusty Lane
                Website: http://nutanix.com
                Date:    1/22/2021
            #>

            [CmdletBinding()]
            param
            (
                [Parameter(Mandatory=$true)]
                [object[]]$Templates
            )
            
            $count = 0
            ## loop through the OUs, outputting to screen. 
            foreach ($template in $Templates)
            {
                Write-Host "     $Count - $($template.name)"
                $count = $count + 1
            }
            
            ## set the maximum count of OUs.  Since we start at zero, we substract 1.
            [int]$max = ($Templates | Measure-Object).count
            
            ## error checking to ensure that a valid integer is chosen
            do
            {
                $Selection = Read-Host 'Enter the Template to clone. '
            }
            while(0..$max -notcontains $Selection)

            $Templates[$Selection]
        }

        function Show-VLANSelection
        {
            <#
            .SYNOPSIS
                This is a private function designed to be used in a script or other function.

            .DESCRIPTION
                This function will provide a multiple choice selector for VLANs.

            .PARAMETER VLANS
                This parameter accepts multiple objects.

            .NOTES
                Author:  Dusty Lane
                Website: http://nutanix.com
                Date:    1/22/2021
            #>


            [CmdletBinding()]
            param
            (
                [Parameter(Mandatory=$true)]
                [object[]]$VLANS
            )
            
            $count = 0
            ## loop through the OUs, outputting to screen. 
            foreach ($vlan in $VLANS)
            {
                Write-Host "     $Count - $($vlan.name)"
                $count = $count + 1
            }
            
            ## set the maximum count of OUs.  Since we start at zero, we substract 1.
            [int]$max = ($VLANS | Measure-Object).count
            
            ## error checking to ensure that a valid integer is chosen
            do
            {
                $Selection = Read-Host 'Enter the VLAN for the VM. '
            }
            while(0..$max -notcontains $Selection)

            $VLANS[$Selection]
        }

        function show-yesorno
        {
            [CmdletBinding()]
            param (
                [Parameter()]
                [string]$Message
            )
            do
            { 
                $Input = (Read-Host "$($Message) (Y/N)").ToLower() 
            }
            while ($Input -notin @('y','n'))
            $Input
        }

        #endregion

        ## generate the objects for source vm and target vlan.  Multiple choice via input from script.
        $SourceVM = (Show-TemplateSelection -Templates (Get-NTNXVM | where-object {$_.name -like "*Template*"})).name
        $TargetVLAN = (Show-VLANSelection -VLANS (Get-NTNXVLAN)).name
        
        $UnattendAnswer = show-yesorno -Message "Join to Domain? Y/N: "
        if ($UnattendAnswer -eq 'y')
        {
            $Upath = Read-host "Enter the full path to the sysprep\unattend file"
            
            if (-not (Test-Path -Path $upath))
            {
                Write-Warning -Message "unattend\sysprep file not found."
                Break
            }
            
            $UnattendCMD = "-Unattend $($upath) -JoinDomain "

        }
        else {
            $Upath = Read-host "Enter the full path to the WORKGROUP sysprep\unattend file"
            
            if (-not (Test-Path -Path $upath))
            {
                Write-Warning -Message "unattend\sysprep file not found."
                Break
            }
            
            $UnattendCMD = "-Unattend $($upath) "
        }

        $PDAnswer = show-yesorno -Message "Add to proection domain? Y/N: "

        if ($PDAnswer -eq 'y')
        {
            $ProtectVM = "-ProtectVM "
        }

        $ComputerName = Read-host "Enter the name of the new computer:  "

        Invoke-Expression -Command "Clone-NTNXVirtualMachine -SourceVM $SourceVM -VLAN $TargetVLAN -PowerON -DestinationName $ComputerName $UnattendCMD $protectVM"

    }

    function Unprotect-NTNXVM
    {
        <#
        .SYNOPSIS
            Removes an Entity from a protection domain.

        .DESCRIPTION
            This function is designed to remove a VM from a protection domain, leveraging the
            Nutanix API.

            This is typically used in conjunction with a VM cleanup process.

        .PARAMETER ElementIP
            This paraeter can be the name or the IP of the Prism Element cluster.

        .PARAMETER Computername
            Name of the computer\VM.

        .EXAMPLE
            Unprotect-NTNXVM -ElementIP 192.168.1.25 -Computername Server1

        .NOTES
            Author:  Dusty Lane
            Website: http://nutanix.com
            Date:    1/22/2021
        #>

        [CmdletBinding()]
        param
        (
            [Parameter(Mandatory=$false)]
            [string]$ElementIp = $Global:ElementIP,
            [Parameter(Mandatory=$true)]
            [string]$Computername
        )
    
        $PD = (Get-NTNXProtectionDomains | where-object {$_.vms -like "*$($Computername)*"}).PDName

        $VM = (Get-NTNXVM -Computername $Computername).name 
        $Computername = $VM

        $Params = @{
            uri = "https://$($ElementIP):9440/PrismGateway/services/rest/v2.0/protection_domains/$($PD)/unprotect_vms"
            method = "POST"
        }

        $Body = @"
        ["$($computername)"]
"@
        
        if ($PD)
        {
            Write-NTNXLog -Message "$($Computername) found in $($PD) Protection Domain, unprotecting VM"
            Get-NtnxApiResponse -Body $Body @Params
        }
        else
        {
            Write-Output "$($Computername) not found in any Protection Domain"
        }
    }

    function Write-NTNXLog
    {
        <#
        .SYNOPSIS
            Formats the log output to screen

        .DESCRIPTION
            This function is designed to help add a date\timestamp to verbose messages
            that are written to screen.  objects\variables can be enumerated in the message
            that is passed to this function.

        .PARAMETER Message
            This parameter accepts strings values.

        .EXAMPLE
            Write-NTNXLog -Message "Cloning task completed successfully."

            Example output:

            [09:55:26] Cloning task completed successfully..

        .NOTES
            Author:  Chris Kingsley and Dusty Lane
            Website: http://nutanix.com
            Date:    1/22/2021
        #>

        [CmdletBinding()]
        param
        (
            [Parameter(Mandatory=$true)]
            $Message
        )

        Write-Output "[$(Get-Date -Format hh:mm:ss)] $Message"
    }
    

    Export-ModuleMember -Function *-*


# Code sample for Solarwinds IPAM
# requires solarwinds module - https://www.powershellgallery.com/packages/SwisPowerShell

# Create
$swis = Connect-Swis -Hostname $swhost -Username $swuser -Password $swpassword
$IP_ADDRESS = Invoke-SwisVerb $swis IPAM.SubnetManagement StartIpReservation @("$NETWORK", "$CIDR", "300") -Verbose | select -expand '#text'
Invoke-SwisVerb -SwisConnection $swis -EntityName IPAM.SubnetManagement -Verb ChangeIpStatus @($IP_ADDRESS, "Blocked") -Verbose
Invoke-SwisVerb -SwisConnection $swis -EntityName IPAM.SubnetManagement -Verb FinishIpReservation @($IP_ADDRESS, "Reserved") -Verbose
Write-Host "IP_ADDRESS=$IP_ADDRESS"


#Delete

 
# Code sample for Solarwinds IPAM
# requires solarwinds module - https://www.powershellgallery.com/packages/SwisPowerShell [powershellgallery.com]
# the solarwinds rest api is not well documented, so the best solution
# is to use the powershell commandlets and execute them from the
# IPAM server.
#
# Note - An active directory account can not be used with the solarwinds API
#        It must be a solarwinds 'sql' account.
#

$ErrorActionPreference = "Stop"
 
#$network = "@@{network}@@"
#$swhost = "@@{ipam_host}@@"
#$swuser = "@@{ipam.username}@@"
#$swpasswd = "@@{ipam.secret}@@"
$reservetime = "240" # in minutes

# create 
$swis = Connect-Swis -Hostname $swhost -UserName $swuser -Password $swpasswd

# to minimize the amount of user input, we need to define
# the network, mask, cidr and gateway variables.
# We will need to define this for every network that we want to be able to provision 
# virtual machines to.

switch ($NETWORK)
{
    10.10.128.0
    {
        $cidr = "23"
        $mask = "255.255.254.0"
        $gateway = "10.10.128.1"
    }
    10.10.130.0
    {
        $cidr = "23"
        $mask = "255.255.254.0"
        $gateway = "10.10.130.1"
    }
}

#------------------ no changes below here -----------#
$Test = $true
while ($test -eq $true)
{
    # let's do some checks (ping and nslookup) to make sure that the IPs are truly available
    $ip_address = Invoke-SwisVerb $swis IPAM.SubnetManagement StartIpReservation @("$network", "$cidr", "$reservetime") -Verbose | Select-Object -expand '#text'
    # test-netconnection is really just a ping.
    $Test = Test-NetConnection -InformationLevel Quiet $ip_address -ErrorAction Continue
    # if the ping fails, we need to check dns...
    if ($test -eq $false)
    {
        try
        {
            # now let's check DNS with resolve-dns.  if this command errors, drop to catch.
            # if it resolves successfully, let's reset the $test variable back to true 
            # and try again.
            Resolve-DnsName -Name $ip_address
            $Test = $true
        }
        catch
        {
            $test = $false
            # we need to clear the error from the resolve-dnsname command so that calm
            # will not fail due to the error.
            $error.Clear()
        }
    }
}

try
{
    # we are putting this in a try catch - just because....
    $capture_ipam1 = Invoke-SwisVerb -SwisConnection $swis -EntityName IPAM.SubnetManagement -Verb ChangeIpStatus @($ip_address, "Blocked") -Verbose
    $capture_ipam2 = Invoke-SwisVerb -SwisConnection $swis -EntityName IPAM.SubnetManagement -Verb FinishIpReservation @($ip_address, "Reserved") -Verbose     
}
catch
{
    # now let's print the error from the try block...  even though....
    $_ 
}

Write-Host "ip_address=$ip_address"
Write-Host "mask=$mask"
Write-Host "default_gateway=$gateway"
Write-Host "cidr=$cidr"
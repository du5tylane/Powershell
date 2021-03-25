
# we need to check if the machine is joined to AD (possibly failed previously)
if ((Get-WmiObject -Class win32_computersystem).partofdomain -eq $true)
{
    #converting password to something we can use
    $adminpassword = ConvertTo-SecureString -asPlainText -Force -String "@@{active_directory.secret}@@"
    #creating the credentials object based on the Calm variables
    $credential = New-Object System.Management.Automation.PSCredential("@@{active_directory.username}@@",$adminpassword)
    #unjoining the domain
    try
    {
        ## lets hide the results of the command in a variable (that we will not use)
        $result = remove-computer -UnjoinDomainCredential ($credential) -Force -PassThru -ErrorAction Stop -Verbose
    }
    catch
    {
        throw "Could not unjoin Active Directory domain : $($_.Exception.Message)"
    }
    
    write-host "Successfully unjoined Active Directory domain" -ForegroundColor Green

}

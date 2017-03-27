param (
    [Parameter(Mandatory=$True)]
    [string]$domainnetbiosname,
 
    [Parameter(Mandatory=$True)]
    [string]$username,

    [Parameter(Mandatory=$True)]
    [string]$password
)

$secpassword = $password | ConvertTo-SecureString -asPlainText -Force
$qualusername = "$domainnetbiosname\$username" 
$credential = New-Object System.Management.Automation.PSCredential($qualusername,$secpassword)
Add-Computer -DomainName $domainnetbiosname -Credential $credential
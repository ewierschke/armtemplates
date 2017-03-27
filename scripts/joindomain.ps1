param (
    [Parameter(Mandatory=$True)]
    [string]$domaindnsname,
 
    [Parameter(Mandatory=$True)]
    [string]$username,

    [Parameter(Mandatory=$True)]
    [string]$password
)

$secpassword = $password | ConvertTo-SecureString -asPlainText -Force
$qualusername = "$domaindnsname\$username" 
$credential = New-Object System.Management.Automation.PSCredential($qualusername,$secpassword)
Add-Computer -DomainName $domaindnsname -Credential $credential
#Get Parameters
param (
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)]
    [String]$LclAdminDeployName,

    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)]
    [String]$LclAdminDeployPass
)

# Define System variables
$credspath = "${env:SystemDrive}\buildscripts"
$domainrdshstoredeploypassDir = "${env:SystemDrive}\buildscripts\1-domainrdshstoredeploypass"
$nextscript = "firstrdsh"

# Begin Script
# Create the domainrdshstoredeploypass log directory
New-Item -Path $domainrdshstoredeploypassDir -ItemType "directory" -Force 2>&1 > $null

# Get the next script
Invoke-Webrequest "https://raw.githubusercontent.com/ewierschke/armtemplates/runwincustdata/scripts/${nextscript}.ps1" -Outfile "${domainrdshstoredeploypassDir}\${nextscript}.ps1";

# Do the work
$LclAdminNameFilePath = "${credspath}\lcladminname.txt"
$LclAdminCredsFilePath = "${credspath}\lcladminpass.txt"
$LclAdminKeyFilePath = "${credspath}\lcladminkey.txt"
Set-Content $LclAdminNameFilePath $LclAdminDeployName
$LclAdminSecurePwd = $LclAdminDeployPass | ConvertTo-SecureString -AsPlainText -Force
$LclAdminKey = New-Object Byte[] 32
[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($LclAdminKey)
Set-Content $LclAdminKeyFilePath $LclAdminKey
$LclAdminPass = $LclAdminSecurePwd | ConvertFrom-SecureString -Key $LclAdminKey
Add-Content $LclAdminCredsFilePath $LclAdminPass

# Create an atlogon scheduled task to run next script
$taskname = "RunNextScript"
if ($PSVersionTable.psversion.major -ge 4) {
    $A = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass ${domainrdshstoredeploypassDir}\${nextscript}.ps1"
    $T = New-ScheduledTaskTrigger -AtStartup
    $P = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -RunLevel "Highest" -LogonType "ServiceAccount"
    $S = New-ScheduledTaskSettingsSet
    $D = New-ScheduledTask -Action $A -Principal $P -Trigger $T -Settings $S
    Register-ScheduledTask -TaskName $taskname -InputObject $D 2>&1 
} else {
    invoke-expression "& $env:systemroot\system32\schtasks.exe /create /SC ONLOGON /RL HIGHEST /NP /V1 /RU SYSTEM /F /TR `"msg * /SERVER:%computername% ${msg}`" /TN `"${taskname}`"" 2>&1 | log -LogTag ${ScriptName}
}
#Commenting out reboot bc domainjoin extension reboots
#powershell.exe "Restart-Computer -Force -Verbose";
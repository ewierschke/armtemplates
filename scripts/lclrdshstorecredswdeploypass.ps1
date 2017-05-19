#Get Parameters
param (
    [Parameter(Mandatory=$True,ValueFromPipelineByPropertyName=$true)]
    [String]$SvcPrincipal,

    [Parameter(Mandatory=$True,ValueFromPipelineByPropertyName=$true)]
    [String]$SvcPrincipalPass,

    [Parameter(Mandatory=$True,ValueFromPipelineByPropertyName=$true)]
    [String]$AZADTenantID,

    [Parameter(Mandatory=$True,ValueFromPipelineByPropertyName=$true)]
    [String]$KeyVaultName,

    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)]
    [String]$AZEnv,

    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)]
    [String]$LclAdminDeployName,

    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)]
    [String]$LclAdminDeployPass
)

# Define System variables
$credspath = "${env:SystemDrive}\buildscripts"
$lclrdshstorecredsDir = "${env:SystemDrive}\buildscripts\0-lclrdshstorecreds"
$nextscript = "prepforlclusersfromkv"

# Begin Script
# Create the lclrdshstorecreds log directory
New-Item -Path $lclrdshstorecredsDir -ItemType "directory" -Force 2>&1 > $null

# Get the next script
Invoke-Webrequest "https://raw.githubusercontent.com/ewierschke/armtemplates/runwincustdata/scripts/${nextscript}.ps1" -Outfile "${lclrdshstorecredsDir}\${nextscript}.ps1";

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

$CredsFilePath = "${credspath}\pass.txt"
$KeyFilePath = "${credspath}\key.txt"
$SecurePwd = $SvcPrincipalPass | ConvertTo-SecureString -AsPlainText -Force
$Key = New-Object Byte[] 32
[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($Key)
Set-Content $KeyFilePath $Key
$Pass = $SecurePwd | ConvertFrom-SecureString -Key $Key
Add-Content $CredsFilePath $Pass

# Create an atlogon scheduled task to run next script
$taskname = "RunNextScript"
if ($PSVersionTable.psversion.major -ge 4) {
    $A = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass ${lclrdshstorecredsDir}\${nextscript}.ps1 ${SvcPrincipal} ${AZADTenantID} ${KeyVaultName} ${AZEnv}"
    $T = New-ScheduledTaskTrigger -AtStartup
    $P = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -RunLevel "Highest" -LogonType "ServiceAccount"
    $S = New-ScheduledTaskSettingsSet
    $D = New-ScheduledTask -Action $A -Principal $P -Trigger $T -Settings $S
    Register-ScheduledTask -TaskName $taskname -InputObject $D 2>&1 
} else {
    invoke-expression "& $env:systemroot\system32\schtasks.exe /create /SC ONLOGON /RL HIGHEST /NP /V1 /RU SYSTEM /F /TR `"msg * /SERVER:%computername% ${msg}`" /TN `"${taskname}`"" 2>&1 | log -LogTag ${ScriptName}
}

powershell.exe "Restart-Computer -Force -Verbose";
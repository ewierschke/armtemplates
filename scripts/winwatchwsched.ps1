#variable for next script
$nextscript = "configure-rdsh"
$FirstRDSHDir = "${env:SystemDrive}\buildscripts\2-FirstRDSH"

# Get the next script
Invoke-Webrequest "https://raw.githubusercontent.com/ewierschke/armtemplates/runwincustdata/scripts/${nextscript}.ps1" -Outfile "${FirstRDSHDir}\${nextscript}.ps1";

# Remove previous scheduled task
Unregister-ScheduledTask -TaskName "RunNextScript" -Confirm:$false;

#Create an atlogon scheduled task to run next script
$msg = "Please upgrade Powershell and try again."

$taskname = "RunNextScript"
if ($PSVersionTable.psversion.major -ge 4) {
    $A = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass ${FirstRDSHDir}\${nextscript}.ps1"
    $T = New-ScheduledTaskTrigger -AtStartup
    $P = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -RunLevel "Highest" -LogonType "ServiceAccount"
    $S = New-ScheduledTaskSettingsSet
    $D = New-ScheduledTask -Action $A -Principal $P -Trigger $T -Settings $S
    Register-ScheduledTask -TaskName $taskname -InputObject $D 2>&1 
} else {
    invoke-expression "& $env:systemroot\system32\schtasks.exe /create /SC ONLOGON /RL HIGHEST /NP /V1 /RU SYSTEM /F /TR `"msg * /SERVER:%computername% ${msg}`" /TN `"${taskname}`"" 2>&1 | log -LogTag ${ScriptName}
}

#Watchmaker section
$BootstrapUrl = "https://raw.githubusercontent.com/plus3it/watchmaker/master/docs/files/bootstrap/watchmaker-bootstrap.ps1"
$PythonUrl = "https://www.python.org/ftp/python/3.6.0/python-3.6.0-amd64.exe"
$PypiUrl = "https://pypi.org/simple"

# Get the host
$PypiHost="$(([System.Uri]$PypiUrl).Host)"

# Download bootstrap file
$BootstrapFile = "${Env:Temp}\$(${BootstrapUrl}.split('/')[-1])"
(New-Object System.Net.WebClient).DownloadFile("$BootstrapUrl", "$BootstrapFile")

# Install python
& "$BootstrapFile" -PythonUrl "$PythonUrl" -Verbose -ErrorAction Stop

# Install watchmaker
pip install --index-url="$PypiUrl" --trusted-host="$PypiHost" --allow-all-external --upgrade pip setuptools watchmaker

# Run watchmaker
watchmaker -vv --log-dir=C:\Watchmaker\Logs

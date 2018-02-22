# Define System variables
$ScheduleNextScriptDir = "${env:SystemDrive}\buildscripts\1-ScheduleNextScript"
$nextscript = "firstrdsh"

# Begin Script
# Create the ScheduleNextScript log directory
New-Item -Path $ScheduleNextScriptDir -ItemType "directory" -Force 2>&1 > $null

# Get the next script
$Stoploop = $false
[int]$Retrycount = "0"
do {
    try {
        Invoke-Webrequest "https://raw.githubusercontent.com/ewierschke/armtemplates/runwincustdata/scripts/${nextscript}.ps1" -Outfile "${ScheduleNextScriptDir}\${nextscript}.ps1";
        Write-Host "Downloaded next script"
        $Stoploop = $true
        }
    catch {
        if ($Retrycount -gt 3){
            Write-Host "Could not download next script after 3 retrys."
            $Stoploop = $true
        }
        else {
            Write-Host "Could not download next script retrying in 30 seconds..."
            Start-Sleep -Seconds 30
            $Retrycount = $Retrycount + 1
        }
    }
}
While ($Stoploop -eq $false)

#Create an atlogon scheduled task to run next script
$taskname = "RunNextScript"
if ($PSVersionTable.psversion.major -ge 4) {
    $A = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass ${ScheduleNextScriptDir}\${nextscript}.ps1"
    $T = New-ScheduledTaskTrigger -AtStartup
    $P = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -RunLevel "Highest" -LogonType "ServiceAccount"
    $S = New-ScheduledTaskSettingsSet
    $D = New-ScheduledTask -Action $A -Principal $P -Trigger $T -Settings $S
    Register-ScheduledTask -TaskName $taskname -InputObject $D 2>&1 
} else {
    invoke-expression "& $env:systemroot\system32\schtasks.exe /create /SC ONLOGON /RL HIGHEST /NP /V1 /RU SYSTEM /F /TR `"msg * /SERVER:%computername% ${msg}`" /TN `"${taskname}`"" 2>&1
}


# Define System variables
$schedwinwatchDir = "${env:SystemDrive}\buildscripts\1-schedwinwatch"
$schedwinwatchLogDir = "${schedwinwatchDir}\Logs"
$LogSource = "schedwinwatch"
$DateTime = $(get-date -format "yyyyMMdd_HHmm_ss")
$schedwinwatchLogFile = "${schedwinwatchLogDir}\schedwinwatch-log_${DateTime}.txt"
$ScriptName = $MyInvocation.mycommand.name
$ErrorActionPreference = "Stop"
$credspath = "${env:SystemDrive}\buildscripts"
$nextscript = "winwatchwcleanup"
$DcComputerName = ${env:COMPUTERNAME}


# Define Functions
function log {
    [CmdLetBinding()]
    Param(
        [Parameter(Mandatory=$false,Position=0,ValueFromPipeLine=$true)] [string[]]
        $LogMessage,
        [Parameter(Mandatory=$false,Position=1)] [string]
        $EntryType="Information",
        [Parameter(Mandatory=$false,Position=2)] [string]
        $LogTag="${ScriptName}"
    )
    PROCESS {
        foreach ($message in $LogMessage) {
            $date = get-date -format "yyyyMMdd.HHmm.ss"
            Manage-Output -EntryType $EntryType "${date}: ${LogTag}: $message"
        }
    }
}

function die($Msg) {
    log -EntryType "Error" -LogMessage $Msg; Stop-Transcript; throw
}

function Manage-Output {
    [CmdLetBinding()]
    Param(
        [Parameter(Mandatory=$false,Position=0,ValueFromPipeLine=$true)] [string[]]
        $Output,
        [Parameter(Mandatory=$false,Position=1)] [string]
        $EntryType="Information"
    )
    PROCESS {
        foreach ($str in $Output) {
            #Write to the event log
            Write-EventLog -LogName Application -Source "${LogSource}" -EventId 1 -EntryType $EntryType -Message "${str}"
            #Write to the default stream (this way we don't clobber the output stream, and the output will be captured by Start-Transcript)
            "${str}" | Out-Default
        }
    }
}

function Set-RegistryValue($Key,$Name,$Value,$Type=[Microsoft.win32.registryvaluekind]::DWord) {
    $Parent=split-path $Key -parent
    $Parent=get-item $Parent
    $Key=get-item $Key
    $Keyh=$Parent.opensubkey($Key.name.split("\")[-1],$true)
    $Keyh.setvalue($Name,$Value,$Type)
    $Keyh.close()
}

function Set-OutputBuffer($Width=10000) {
    $keys=("hkcu:\console\%SystemRoot%_System32_WindowsPowerShell_v1.0_powershell.exe",
           "hkcu:\console\%SystemRoot%_SysWOW64_WindowsPowerShell_v1.0_powershell.exe")
    # other titles are ignored
    foreach ($key in $keys) {
        md $key -verbose -force
        Set-RegistryValue $key FontSize 0x00050000
        Set-RegistryValue $key ScreenBufferSize 0x02000200
        Set-RegistryValue $key WindowSize 0x00200200
        Set-RegistryValue $key FontFamily 0x00000036
        Set-RegistryValue $key FontWeight 0x00000190
        Set-ItemProperty $key FaceName "Lucida Console"

        $bufferSize=$host.ui.rawui.bufferSize
        $bufferSize.width=$Width
        $host.ui.rawui.BufferSize=$BufferSize
        $maxSize=$host.ui.rawui.MaxWindowSize
        $windowSize=$host.ui.rawui.WindowSize
        $windowSize.width=$maxSize.width
        $host.ui.rawui.WindowSize=$windowSize
    }
}

#SCRIPT
# Create the schedwinwatch log directory
New-Item -Path $schedwinwatchDir -ItemType "directory" -Force 2>&1 > $null
New-Item -Path $schedwinwatchLogDir -ItemType "directory" -Force 2>&1 > $null
# Increase the screen width to avoid line wraps in the log file
Set-OutputBuffer -Width 10000
# Start a transcript to record script output
Start-Transcript $schedwinwatchLogFile

# Create a "schedwinwatch" event log source
try {
    New-EventLog -LogName Application -Source "${LogSource}"
} catch {
    if ($_.Exception.GetType().FullName -eq "System.InvalidOperationException") {
        # Event log already exists, log a message but don't force an exit
        log "Event log source, ${LogSource}, already exists. Continuing..."
    } else {
        # Unhandled exception, log an error and exit!
        "$(get-date -format "yyyyMMdd.HHmm.ss"): ${ScriptName}: ERROR: Encountered a problem creating the event log source." | Out-Default
        Stop-Transcript
        throw
    }
}

# Get the next script
log -LogTag ${ScriptName} "Downloading ${nextscript}.ps1"
$Stoploop = $false
[int]$Retrycount = "0"

do {
    try {
       Invoke-Webrequest "https://raw.githubusercontent.com/ewierschke/armtemplates/runwincustdata/scripts/${nextscript}.ps1" -Outfile "${schedwinwatchDir}\${nextscript}.ps1";
       $Stoploop = $true
       }
    catch {
        if ($Retrycount -gt 5){
           "$(get-date -format "yyyyMMdd.HHmm.ss"): ${ScriptName}: ERROR: Encountered a problem creating the event log source." | Out-Default
           Stop-Transcript
           $Stoploop = $true
           throw
        }
		else {
		    log -LogTag ${ScriptName} "Script download Attempt ${Retrycount}"
			Start-Sleep -Seconds 30
		    $Retrycount = $Retrycount + 1
		}
	}
}
While ($Stoploop -eq $false)


# Remove previous scheduled task
log -LogTag ${ScriptName} "UnRegistering previous scheduled task"
Unregister-ScheduledTask -TaskName "RunNextScript" -Confirm:$false;

#Create an atlogon scheduled task to run next script
log -LogTag ${ScriptName} "Registering a scheduled task at startup to run the next script"
$msg = "Please upgrade Powershell and try again."

$taskname = "RunNextScript"
if ($PSVersionTable.psversion.major -ge 4) {
    $A = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass ${schedwinwatchDir}\${nextscript}.ps1"
    $T = New-ScheduledTaskTrigger -AtStartup
    $P = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -RunLevel "Highest" -LogonType "ServiceAccount"
    $S = New-ScheduledTaskSettingsSet
    $D = New-ScheduledTask -Action $A -Principal $P -Trigger $T -Settings $S
    Register-ScheduledTask -TaskName $taskname -InputObject $D 2>&1 | log -LogTag ${ScriptName}
} else {
    invoke-expression "& $env:systemroot\system32\schtasks.exe /create /SC ONLOGON /RL HIGHEST /NP /V1 /RU SYSTEM /F /TR `"msg * /SERVER:%computername% ${msg}`" /TN `"${taskname}`"" 2>&1 | log -LogTag ${ScriptName}
}
#$Computer = $env:COMPUTERNAME;
$DomainnameFilePath = "${credspath}\domainname.txt";
$UsernameFilePath = "${credspath}\lcladminname.txt";
$Username = Get-Content ${UsernameFilePath};
$Domain = Get-Content ${DomainnameFilePath};
$LclAdminCredsFilePath = "${credspath}\lcladminpass.txt";
$LclAdminKeyFilePath = "${credspath}\lcladminkey.txt";
$LclAdminKey = Get-Content ${LclAdminKeyFilePath};
$LclAdminPass = Get-Content ${LclAdminCredsFilePath};
$SecPassword = $LclAdminPass | ConvertTo-SecureString -Key ${LclAdminKey};
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR(${SecPassword});
$adminpass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(${BSTR});
#only continue if task scheduled as user
try {
    Set-ScheduledTask -User "${Domain}\${Username}" -Password ${adminpass} -TaskName ${taskname};
}
catch {
    "$(get-date -format "yyyyMMdd.HHmm.ss"): ${ScriptName}: ERROR: Encountered a problem setting scheduled task to run as ${Username}." | Out-Default
    Stop-Transcript
    throw
}
log -LogTag ${ScriptName} "deleting creds"
Remove-Item "${credspath}\lcladminpass.txt" -Force -Recurse;
Remove-Item "${credspath}\lcladminkey.txt" -Force -Recurse;
Remove-Item "${credspath}\lcladminname.txt" -Force -Recurse;
Remove-Item "${credspath}\domainname.txt" -Force -Recurse;

log -LogTag ${ScriptName} "Rebooting"
powershell.exe "Restart-Computer -Force -Verbose";
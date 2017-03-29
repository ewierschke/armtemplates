# Define System variables
$FirstRDSHDir = "${env:SystemDrive}\FirstRDSH"
$FirstRDSHLogDir = "${FirstRDSHDir}\Logs"
$LogSource = "FirstRDSH"
$DateTime = $(get-date -format "yyyyMMdd_HHmm_ss")
$JoinDomainLogFile = "${FirstRDSHLogDir}\firstrdsh-log_${DateTime}.txt"
$ScriptName = $MyInvocation.mycommand.name
$ErrorActionPreference = "Stop"
$nextscript = "configure-rdsh"

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

# Begin Script
# Create the FirstRDSH log directory
New-Item -Path $FirstRDSHDir -ItemType "directory" -Force 2>&1 > $null
New-Item -Path $FirstRDSHLogDir -ItemType "directory" -Force 2>&1 > $null
# Increase the screen width to avoid line wraps in the log file
Set-OutputBuffer -Width 10000
# Start a transcript to record script output
Start-Transcript $FirstRDSHLogFile

# Create a "FirstRDSH" event log source
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
log -LogTag ${ScriptName} "Downloading configure-rdsh.ps1"
Invoke-Webrequest https://raw.githubusercontent.com/plus3it/cfn/master/scripts/configure-rdsh.ps1 -Outfile ${FirstRDSHDir}\configure-rdsh.ps1;
log -LogTag ${ScriptName} "Installing RDSH features"
powershell.exe "Install-WindowsFeature RDS-RD-Server,RDS-Licensing -Verbose";
log -LogTag ${ScriptName} "UnRegistering previous scheduled task"
Unregister-ScheduledTask -TaskName "RunNextScript" -Confirm:$false;

#Create an atlogon scheduled task to run next script
log -LogTag ${ScriptName} "Registering a scheduled task at logon to run the next script"
$msg = "Please upgrade Powershell and try again."

$taskname = "RunNextScript"
if ($PSVersionTable.psversion.major -ge 4) {
    $A = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass ${FirstRDSHDir}\${nextscript}.ps1"
    $T = New-ScheduledTaskTrigger -AtLogon
    $P = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -RunLevel "Highest" -LogonType "ServiceAccount"
    $S = New-ScheduledTaskSettingsSet
    $D = New-ScheduledTask -Action $A -Principal $P -Trigger $T -Settings $S
    Register-ScheduledTask -TaskName $taskname -InputObject $D 2>&1 | log -LogTag ${ScriptName}
} else {
    invoke-expression "& $env:systemroot\system32\schtasks.exe /create /SC ONLOGON /RL HIGHEST /NP /V1 /RU SYSTEM /F /TR `"msg * /SERVER:%computername% ${msg}`" /TN `"${taskname}`"" 2>&1 | log -LogTag ${ScriptName}
}

powershell.exe "Restart-Computer -Force -Verbose";
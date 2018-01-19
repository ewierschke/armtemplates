#Get Parameters
param (
    [Parameter(Mandatory=$True,ValueFromPipelineByPropertyName=$true)]
    [String]$ADDomainAdminUsername,

    [Parameter(Mandatory=$True,ValueFromPipelineByPropertyName=$true)]
    [String]$ADDomainAdminPw,

    [Parameter(Mandatory=$True,ValueFromPipelineByPropertyName=$true)]
    [String]$ADRestoreModePw,

    [Parameter(Mandatory=$True,ValueFromPipelineByPropertyName=$true)]
    [String]$ADDomainDNSName,

    [Parameter(Mandatory=$True,ValueFromPipelineByPropertyName=$true)]
    [ValidateSet("Primary DC","Replica DC")]
    [string]$DcRole
)

# Define System variables
$createDCDir = "${env:SystemDrive}\buildscripts\0-createdc"
$createDCLogDir = "${createDCDir}\Logs"
$LogSource = "createDC"
$DateTime = $(get-date -format "yyyyMMdd_HHmm_ss")
$createDCLogFile = "${createDCLogDir}\createDC-log_${DateTime}.txt"
$ScriptName = $MyInvocation.mycommand.name
$ErrorActionPreference = "Stop"
$credspath = "${env:SystemDrive}\buildscripts"
$nextscript = "schedwinwatch"
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
# Create the createDC log directory
New-Item -Path $createDCDir -ItemType "directory" -Force 2>&1 > $null
New-Item -Path $createDCLogDir -ItemType "directory" -Force 2>&1 > $null
# Increase the screen width to avoid line wraps in the log file
Set-OutputBuffer -Width 10000
# Start a transcript to record script output
Start-Transcript $createDCLogFile

# Create a "createDC" event log source
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
Invoke-Webrequest "https://raw.githubusercontent.com/ewierschke/armtemplates/runwincustdata/scripts/${nextscript}.ps1" -Outfile "${createDCDir}\${nextscript}.ps1";

# Write Creds to disk
log -LogTag ${ScriptName} "writing creds"
$LclAdminNameFilePath = "${credspath}\lcladminname.txt"
$LclAdminCredsFilePath = "${credspath}\lcladminpass.txt"
$LclAdminKeyFilePath = "${credspath}\lcladminkey.txt"
Set-Content $LclAdminNameFilePath $ADDomainAdminUsername
$LclAdminSecurePwd = $ADDomainAdminPw | ConvertTo-SecureString -AsPlainText -Force
$LclAdminKey = New-Object Byte[] 32
[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($LclAdminKey)
Set-Content $LclAdminKeyFilePath $LclAdminKey
$LclAdminPass = $LclAdminSecurePwd | ConvertFrom-SecureString -Key $LclAdminKey
Add-Content $LclAdminCredsFilePath $LclAdminPass
$DomainnameFilePath = "${credspath}\domainname.txt"
Set-Content $DomainnameFilePath $ADDomainDNSName

log -LogTag ${ScriptName} "Downloading DSC resources"
#-setup-
Invoke-WebRequest "https://raw.githubusercontent.com/ewierschke/armtemplates/runwincustdata/scripts/set-staticip.ps1" -OutFile "${createDCDir}\set-staticip.ps1"
Invoke-WebRequest "https://raw.githubusercontent.com/plus3it/cfn/master/scripts/assert-computername.ps1" -OutFile "${createDCDir}\assert-computername.ps1"
Invoke-WebRequest "https://raw.githubusercontent.com/ewierschke/armtemplates/runwincustdata/scripts/assert-hadc.ps1" -OutFile "${createDCDir}\assert-hadc.ps1"
Invoke-WebRequest "https://raw.githubusercontent.com/plus3it/cfn/master/scripts/xcomputermanagement-1.3.0.zip" -OutFile "${createDCDir}\xcomputermanagement-1.3.0.zip"
Invoke-WebRequest "https://raw.githubusercontent.com/plus3it/cfn/master/scripts/xactivedirectory-2.4.0.0.zip" -OutFile "${createDCDir}\xactivedirectory-2.4.0.0.zip"
Invoke-WebRequest "https://raw.githubusercontent.com/plus3it/cfn/master/scripts/xnetworking-2.2.0.0.zip" -OutFile "${createDCDir}\xnetworking-2.2.0.0.zip"
Invoke-WebRequest "https://raw.githubusercontent.com/plus3it/cfn/master/scripts/unzip-archive.ps1" -OutFile "${createDCDir}\unzip-archive.ps1"
powershell.exe -Command "Get-NetFirewallProfile | Set-NetFirewallProfile -Enabled False"
#powershell.exe -command Set-ExecutionPolicy RemoteSigned -Force
powershell.exe -command ${createDCDir}\unzip-archive.ps1 -Source ${createDCDir}\xactivedirectory-2.4.0.0.zip -Destination '${env:ProgramFiles}\WindowsPowerShell\Modules'
powershell.exe -command ${createDCDir}\unzip-archive.ps1 -Source ${createDCDir}\xnetworking-2.2.0.0.zip -Destination '${env:ProgramFiles}\WindowsPowerShell\Modules'
powershell.exe -command ${createDCDir}\unzip-archive.ps1 -Source ${createDCDir}\xcomputermanagement-1.3.0.zip -Destination '${env:ProgramFiles}\WindowsPowerShell\Modules'

log -LogTag ${ScriptName} "Setting Static IP"
#-init-
powershell.exe -ExecutionPolicy RemoteSigned -Command "${createDCDir}\set-staticip.ps1"
#powershell.exe -ExecutionPolicy RemoteSigned -Command "${createDCDir}\assert-computername.ps1 -ComputerName ${DcComputerName}"

#If RunNextScript task exists, remove it
$schedule = new-object -com Schedule.Service 
$schedule.connect() 
$tasks = $schedule.getfolder("\").gettasks(0)
foreach ($task in ($tasks | select Name)) {
   if($($task.name).equals("RunNextScript")) {
      Unregister-ScheduledTask -TaskName "RunNextScript" -Confirm:$false;
      break
   }
}

#Create an atstartup scheduled task to run next script
log -LogTag ${ScriptName} "Registering a scheduled task at startup to run the next script"
$msg = "Please upgrade Powershell and try again."

$taskname = "RunNextScript"
if ($PSVersionTable.psversion.major -ge 4) {
    $A = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass ${createDCDir}\${nextscript}.ps1"
    $T = New-ScheduledTaskTrigger -AtStartup
    $P = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -RunLevel "Highest" -LogonType "ServiceAccount"
    $S = New-ScheduledTaskSettingsSet
    $D = New-ScheduledTask -Action $A -Principal $P -Trigger $T -Settings $S
    Register-ScheduledTask -TaskName $taskname -InputObject $D 2>&1 | log -LogTag ${ScriptName}
} else {
    invoke-expression "& $env:systemroot\system32\schtasks.exe /create /SC ONLOGON /RL HIGHEST /NP /V1 /RU SYSTEM /F /TR `"msg * /SERVER:%computername% ${msg}`" /TN `"${taskname}`"" 2>&1 | log -LogTag ${ScriptName}
}

log -LogTag ${ScriptName} "Promoting to DC"
#-installADDS-
powershell.exe -Command "Install-WindowsFeature rsat-adds -IncludeAllSubFeature"
powershell.exe -ExecutionPolicy RemoteSigned -Command "${createDCDir}\assert-hadc.ps1 -DomainAdminUsername '${ADDomainAdminUsername}' -DomainAdminPw '${ADDomainAdminPw}' -RestoreModePw '${ADRestoreModePw}' -DomainDnsName '${ADDomainDNSName}' -DcRole '${DcRole}' -Verbose"




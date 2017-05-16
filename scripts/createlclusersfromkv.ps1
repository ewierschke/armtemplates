#Get Parameters
param (
    [Parameter(Mandatory=$True,ValueFromPipelineByPropertyName=$true)]
    [String]$SvcPrincipal,

    [Parameter(Mandatory=$True,ValueFromPipelineByPropertyName=$true)]
    [String]$AZADTenantID,

    [Parameter(Mandatory=$True,ValueFromPipelineByPropertyName=$true)]
    [String]$KeyVaultName,

    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)]
    [String]$AZEnv
)

# Define System variables
$CreateLclUsersfromKVDir = "${env:SystemDrive}\buildscripts\1b-CreateLclUsersfromKV"
$CreateLclUsersfromKVLogDir = "${CreateLclUsersfromKVDir}\Logs"
$LogSource = "CreateLclUsersfromKV"
$DateTime = $(get-date -format "yyyyMMdd_HHmm_ss")
$CreateLclUsersfromKVLogFile = "${CreateLclUsersfromKVLogDir}\CreateLclUsersfromKV-log_${DateTime}.txt"
$ScriptName = $MyInvocation.mycommand.name
$ErrorActionPreference = "Stop"
$nextscript = "firstrdsh"
$jqfolder = "${env:SystemDrive}\jqtemp"
$credspath = "${env:SystemDrive}\buildscripts"

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

# Begin Script
# Create the CreateLclUsersfromKV log directory
New-Item -Path $CreateLclUsersfromKVDir -ItemType "directory" -Force 2>&1 > $null
New-Item -Path $CreateLclUsersfromKVLogDir -ItemType "directory" -Force 2>&1 > $null
New-Item -Path $jqfolder -ItemType "directory" -Force 2>&1 > $null
# Increase the screen width to avoid line wraps in the log file
Set-OutputBuffer -Width 10000
# Start a transcript to record script output
Start-Transcript $CreateLclUsersfromKVLogFile

# Create a "CreateLclUsersfromKV" event log source
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
Invoke-Webrequest "https://raw.githubusercontent.com/ewierschke/armtemplates/runwincustdata/scripts/${nextscript}.ps1" -Outfile "${CreateLclUsersfromKVDir}\${nextscript}.ps1";

# Do the work
#Download jq
log -LogTag ${ScriptName} "Downloading jq"
Import-Module BitsTransfer
Start-BitsTransfer -Source "https://s3.amazonaws.com/app-chemistry/files/jq-win64.exe" -Destination "${jqfolder}\jq-win64.exe";
#Install Azure Powershell
#Update-Help;
log -LogTag ${ScriptName} "Installing AzureRM PowerShell Module"
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force;
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted;
Install-Module AzureRM;
Import-Module AzureRM;
New-Item -path "$env:APPDATA\Windows Azure Powershell" -type directory | Out-Null
Set-Content -path "$env:APPDATA\Windows Azure Powershell\AzureDataCollectionProfile.json" -value '{"enableAzureDataCollection":false}';
#Disable-AzureDataCollection;
#Login to Azure using ServicePrincipal
log -LogTag ${ScriptName} "Logging into Azure"
$CredsFilePath = "${credspath}\pass.txt"
$KeyFilePath = "${credspath}\key.txt"
$Key = Get-Content $KeyFilePath
$Pass = Get-Content $CredsFilePath
$SecPassword = $Pass | ConvertTo-SecureString -Key $Key
#$secpassword = ConvertTo-SecureString ${SvcPrincipalPass} -AsPlainText -Force;
$pscredential = New-Object System.Management.Automation.PSCredential (${SvcPrincipal}, $SecPassword);
Login-AzureRMAccount -ServicePrincipal -Credential $pscredential -TenantId ${AZADTenantID} -Environment ${AZEnv};
#Get usernames from list of Secrets
Set-Location -Path ${jqfolder};
$secrets = Get-AzureKeyVaultSecret -vaultname ${KeyVaultName} | ConvertTo-Json | .\jq-win64.exe -r '.[] | .Name';
$count=$secrets.Count;
#Loop through secrets/usernames to create and add to local Administrators group
$v=0;
For ($c=1; $c -le $count; $c++) {
    $pass = Get-AzureKeyVaultSecret -VaultName ${KeyVaultName} -Name $secrets[$v]
    $thispass = ConvertTo-SecureString $pass.SecretValueText -AsPlainText -Force
    try {
        New-LocalUser -Name $secrets[$v] -Password $thispass
    } catch {
        if ($_.Exception.GetType().FullName -eq "Microsoft.PowerShell.Commands.InvalidPasswordException") {
            #Password is not complex, disable account but don't force an exists
            $name = $secrets[$v]
            log "Password for $name did not meet complexity or history requirements, disabling"
            Disable-LocalUser -Name $secrets[$v];
        } else {
            # Unhandled exception, log an error and exit!
            "$(get-date -format "yyyyMMdd.HHmm.ss"): ${ScriptName}: ERROR: Encountered an unhandled exception creating accounts..." | Out-Default
            Stop-Transcript
            throw
        }
    }
    #New-LocalUser -Name $secrets[$v] -Password $thispass
    $Computer = $env:COMPUTERNAME
    $ADSI = [ADSI]("WinNT://$Computer")
    $User = $ADSI.Children.Find($secrets[$v], 'user')
    $AdminGroup = [ADSI]"WinNT://$Computer/Administrators,group"
    $AdminGroup.Add($User.Path)
    $v=($v+1)
}

# Remove previous scheduled task
log -LogTag ${ScriptName} "UnRegistering previous scheduled task"
Unregister-ScheduledTask -TaskName "RunNextScript" -Confirm:$false;

# Create an atlogon scheduled task to run next script
log -LogTag ${ScriptName} "Registering a scheduled task at startup to run the next script"
$msg = "Please upgrade Powershell and try again."

$taskname = "RunNextScript"
if ($PSVersionTable.psversion.major -ge 4) {
    $A = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass ${CreateLclUsersfromKVDir}\${nextscript}.ps1"
    $T = New-ScheduledTaskTrigger -AtStartup
    $P = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -RunLevel "Highest" -LogonType "ServiceAccount"
    $S = New-ScheduledTaskSettingsSet
    $D = New-ScheduledTask -Action $A -Principal $P -Trigger $T -Settings $S
    Register-ScheduledTask -TaskName $taskname -InputObject $D 2>&1 | log -LogTag ${ScriptName}
} else {
    invoke-expression "& $env:systemroot\system32\schtasks.exe /create /SC ONLOGON /RL HIGHEST /NP /V1 /RU SYSTEM /F /TR `"msg * /SERVER:%computername% ${msg}`" /TN `"${taskname}`"" 2>&1 | log -LogTag ${ScriptName}
}
log -LogTag ${ScriptName} "deleting jq"
Set-Location -Path $CreateLclUsersfromKVDir;
Remove-Item ${jqfolder} -Force -Recurse
log -LogTag ${ScriptName} "deleting creds"
Remove-Item "${credspath}\pass.txt" -Force -Recurse
Remove-Item "${credspath}\key.txt" -Force -Recurse
log -LogTag ${ScriptName} "Rebooting"
powershell.exe "Restart-Computer -Force -Verbose";
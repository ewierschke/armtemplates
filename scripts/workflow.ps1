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

workflow Resume_Workflow
{
    New-Item c:\temp -type directory
    Invoke-Webrequest https://raw.githubusercontent.com/plus3it/cfn/master/scripts/configure-rdsh.ps1 -Outfile c:\temp\configure-rdsh.ps1;
    Add-Computer -DomainName $domaindnsname -Credential $credential
    Restart-Computer -Wait
    Install-WindowsFeature RDS-RD-Server,RDS-Licensing -Verbose
    Restart-Computer -Wait
    powershell.exe -ExecutionPolicy Bypass C:\temp\configure-rdsh.ps1
}
# Create the scheduled job properties
$options = New-ScheduledJobOption -RunElevated -ContinueIfGoingOnBattery -StartIfOnBattery
$AtStartup = New-JobTrigger -AtStartup

# Register the scheduled job
Register-ScheduledJob -Name Resume_Workflow_Job -Trigger $AtStartup -ScriptBlock ({[System.Management.Automation.Remoting.PSSessionConfigurationData]::IsServerManager = $true; Import-Module PSWorkflow; Resume-Job -Name new_resume_workflow_job -Wait}) -ScheduledJobOption $options
# Execute the workflow as a new job
Resume_Workflow -AsJob -JobName new_resume_workflow_job

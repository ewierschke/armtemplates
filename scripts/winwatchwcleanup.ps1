#Get Parameters
param (
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)]
    [String]$WatchmakerParam,

    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)]
    [String]$WatchmakerParam2
)

# Remove previous scheduled task
Unregister-ScheduledTask -TaskName "RunNextScript" -Confirm:$false;

#Install Windows Updates
try {
    #Verify if PowerShellGet module is installed. If not install
    if (!(Get-Module -Name PowerShellGet)){
        Invoke-WebRequest 'https://download.microsoft.com/download/C/4/1/C41378D4-7F41-4BBE-9D0D-0E4F98585C61/PackageManagement_x64.msi' -OutFile $($env:temp +'\PackageManagement_x64.msi')
        Start-Process $($env:temp +'\PackageManagement_x64.msi') -ArgumentList "/qn" -Wait
    }
    #Verify if PSWindowsUpdate PowerShell Module is installed. If not install.
    if (!(Get-Module -Name PSWindowsUpdate -List)){
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
        Install-Module -Name PSWindowsUpdate -Scope AllUsers -Confirm:$false -Force
    }
    #module updated need to test approach using new cmdlets
    #Get-WUInstall -WindowsUpdate -AcceptAll -AutoReboot -Confirm:$FALSE -ErrorAction stop
    Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot
}
catch {
    Write-Output "Oops. Something failed when installing patches"
}

#open IE to initialize cert
$ie = new-object -com "InternetExplorer.Application"
$ie.navigate("http://s3.amazonaws.com/app-chemistry/files/")

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
pip install --index-url="$PypiUrl" --trusted-host="$PypiHost" --upgrade pip setuptools watchmaker

# Run watchmaker
watchmaker --no-reboot --log-level debug --log-dir=C:\Watchmaker\Logs ${WatchmakerParam} ${WatchmakerParam2}

gpupdate /force

powershell.exe "Restart-Computer -Force -Verbose";

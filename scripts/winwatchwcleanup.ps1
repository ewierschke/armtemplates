#Get Parameters
param (
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)]
    [String]$WatchmakerParam,

    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)]
    [String]$WatchmakerParam2
)

# Remove previous scheduled task
$taskName = "RunNextScript";
$taskExists = Get-ScheduledTask | Where-Object {$_.TaskName -like $taskName}
if ($taskExists) {
    Unregister-ScheduledTask -TaskName ${taskName} -Confirm:$false;
}

#Install Updates
. { iwr -useb http://boxstarter.org/bootstrapper.ps1 } | iex; get-boxstarter -Force
Enable-MicrosoftUpdate
Install-WindowsUpdate -SuppressReboots -AcceptEula

#open IE to initialize cert
$ie = new-object -com "InternetExplorer.Application"
$ie.navigate("http://s3.amazonaws.com/app-chemistry/files/")

$BootstrapUrl = "https://raw.githubusercontent.com/plus3it/watchmaker/master/docs/files/bootstrap/watchmaker-bootstrap.ps1"
$PythonUrl = "https://www.python.org/ftp/python/3.6.3/python-3.6.3-amd64.exe"
$PypiUrl = "https://pypi.org/simple"

# Download bootstrap file
$BootstrapFile = "${Env:Temp}\$(${BootstrapUrl}.split('/')[-1])"
(New-Object System.Net.WebClient).DownloadFile("$BootstrapUrl", "$BootstrapFile")

# Install python
& "$BootstrapFile" -PythonUrl "$PythonUrl" -Verbose -ErrorAction Stop

# Install watchmaker
pip install --index-url="$PypiUrl" --upgrade pip setuptools watchmaker

# Run watchmaker
watchmaker --no-reboot --log-level debug --log-dir=C:\Watchmaker\Logs ${WatchmakerParam} ${WatchmakerParam2}

gpupdate /force

powershell.exe "Restart-Computer -Force -Verbose";

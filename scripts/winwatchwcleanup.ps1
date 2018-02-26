#Get Parameters
param (
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)]
    [String]$WatchmakerParam,

    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)]
    [String]$WatchmakerParam2
)

$Logfile = "${Env:Temp}\$(gc env:computername).log"

Function LogWrite
{
   Param ([string]$logstring)

   Add-content $Logfile -value $logstring
}

#Install Updates
#. { iwr -useb http://boxstarter.org/bootstrapper.ps1 } | iex; get-boxstarter -Force
#Enable-MicrosoftUpdate
#Install-WindowsUpdate -SuppressReboots -AcceptEula
LogWrite "Pre bootstrap download"
#open IE to initialize cert
#$ie = new-object -com "InternetExplorer.Application"
#$ie.navigate("http://s3.amazonaws.com/app-chemistry/files/")

$BootstrapUrl = "https://raw.githubusercontent.com/ewierschke/watchmaker/bootstrap/docs/files/bootstrap/watchmaker-bootstrap.ps1"
$PythonUrl = "https://www.python.org/ftp/python/3.6.4/python-3.6.4-amd64.exe"
$PypiUrl = "https://pypi.org/simple"

# Download bootstrap file
$BootstrapFile = "${Env:Temp}\$(${BootstrapUrl}.split('/')[-1])"
(New-Object System.Net.WebClient).DownloadFile("$BootstrapUrl", "$BootstrapFile")

# Install python
& "$BootstrapFile" -PythonUrl "$PythonUrl" -Verbose -ErrorAction Stop
#$params = "`"$BootstrapFile`" -PythonUrl `"$PythonUrl`" -Verbose -ErrorAction Stop"
#Start-Process powershell -Argument $params -NoNewWindow -Wait
#$env:Path = "$env:Path;$env:ProgramFiles\Python36\Scripts\;$env:ProgramFiles\Python36\"

# Install watchmaker
pip install --build "${Env:Temp}" --index-url="$PypiUrl" --upgrade pip setuptools watchmaker

# Run watchmaker
watchmaker --no-reboot --log-level debug --log-dir=C:\Watchmaker\Logs ${WatchmakerParam} ${WatchmakerParam2}

# Download bootstrap file
#$BootstrapFile = "${Env:Temp}\$(${BootstrapUrl}.split('/')[-1])"
#(New-Object System.Net.WebClient).DownloadFile("$BootstrapUrl", "$BootstrapFile")
#LogWrite "Post bootstrap download"
## Install python
#$params = "`"$BootstrapFile`" -PythonUrl `"$PythonUrl`" -Verbose -ErrorAction Stop"
#Start-Process powershell -Argument $params -NoNewWindow -Wait
##& "$BootstrapFile" -PythonUrl "$PythonUrl" -Verbose -ErrorAction Stop

## Install watchmaker
#pip install --index-url="$PypiUrl" --upgrade pip setuptools watchmaker
#LogWrite "Post pip install"
## Run watchmaker
#watchmaker --no-reboot --log-level debug --log-dir=C:\Watchmaker\Logs ${WatchmakerParam} ${WatchmakerParam2}
#LogWrite "Post wam execute"
gpupdate /force

# Remove previous scheduled task
$taskName = "RunNextScript";
$taskExists = Get-ScheduledTask | Where-Object {$_.TaskName -like $taskName}
if ($taskExists) {
    Unregister-ScheduledTask -TaskName ${taskName} -Confirm:$false;
}

powershell.exe "Restart-Computer -Force -Verbose";

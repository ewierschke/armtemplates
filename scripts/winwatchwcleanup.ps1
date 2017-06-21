# Remove previous scheduled task
Unregister-ScheduledTask -TaskName "RunNextScript" -Confirm:$false;
#Download jq to initialize cert
Import-Module BitsTransfer;
Start-BitsTransfer -Source "https://s3.amazonaws.com/app-chemistry/files/jq-win64.exe" -Destination "${Env:Temp}\jq-win64.exe";

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
watchmaker --log-level debug --log-dir=C:\Watchmaker\Logs

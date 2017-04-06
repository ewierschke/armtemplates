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
pip install --index-url="$PypiUrl" --trusted-host="$PypiHost" --allow-all-external --upgrade pip setuptools watchmaker

# Run watchmaker
watchmaker -vv --log-dir=C:\Watchmaker\Logs

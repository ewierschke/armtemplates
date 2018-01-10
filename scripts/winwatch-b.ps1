$BootstrapUrl = "https://raw.githubusercontent.com/plus3it/watchmaker/master/docs/files/bootstrap/watchmaker-bootstrap.ps1"
$PythonUrl = "https://www.python.org/ftp/python/3.6.3/python-3.6.3-amd64.exe"
$PypiUrl = "https://pypi.org/simple"

# Download bootstrap file
$BootstrapFile = "${Env:Temp}\$(${BootstrapUrl}.split('/')[-1])"
(New-Object System.Net.WebClient).DownloadFile("$BootstrapUrl", "$BootstrapFile")

# Install python
$params = "`"$BootstrapFile`" -PythonUrl `"$PythonUrl`" -Verbose -ErrorAction Stop"
Start-Process powershell -Argument $params -NoNewWindow -Wait
$env:Path = "$env:Path;$env:ProgramFiles\Python36\Scripts\;$env:ProgramFiles\Python36\"

# Install watchmaker
pip install --index-url="$PypiUrl" --upgrade pip setuptools boto3
pip download --dest $env:windir\Temp watchmaker
pip install --no-index --find-links=$env:windir\Temp watchmaker

# Run watchmaker
watchmaker --log-level debug --log-dir=C:\Watchmaker\Logs

$BootstrapUrl = "https://raw.githubusercontent.com/plus3it/watchmaker/master/docs/files/bootstrap/watchmaker-bootstrap.ps1"
$PythonUrl = "https://www.python.org/ftp/python/3.6.3/python-3.6.3-amd64.exe"
$PypiUrl = "https://pypi.org/simple"

# Download bootstrap file
#$BootstrapFile = "${Env:Temp}\$(${BootstrapUrl}.split('/')[-1])"
$BootstrapFile = "$env:windir\Temp\$(${BootstrapUrl}.split('/')[-1])"
(New-Object System.Net.WebClient).DownloadFile("$BootstrapUrl", "$BootstrapFile")

# Install python
#& "$BootstrapFile" -PythonUrl "$PythonUrl" -Verbose -ErrorAction Stop
$params = "`"$BootstrapFile`" -PythonUrl `"$PythonUrl`" -Verbose -ErrorAction Stop"
Start-Process powershell -Argument $params -NoNewWindow -Wait
Get-ChildItem env: | Format-List | Out-File $env:windir\Temp\LocalSystemEnv1.log
$env:Path = "$env:Path;C:\Program Files\Python36\Scripts\;C:\Program Files\Python36\"
Get-ChildItem env: | Format-List | Out-File $env:windir\Temp\LocalSystemEnv3.log

# Install watchmaker
pip install --index-url="$PypiUrl" --upgrade pip setuptools boto3 --log $env:windir\Temp\pip1.log
pip download --dest $env:windir\Temp watchmaker --log $env:windir\Temp\pip2.log
pip install --no-index --find-links=$env:windir\Temp watchmaker --log $env:windir\Temp\pip3.log

# Run watchmaker
watchmaker --log-level debug --log-dir=C:\Watchmaker\Logs
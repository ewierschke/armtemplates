$BootstrapUrl = "https://raw.githubusercontent.com/ewierschke/watchmaker/bootstrap/docs/files/bootstrap/watchmaker-bootstrap.ps1"
$PythonUrl = "https://www.python.org/ftp/python/3.6.3/python-3.6.3-amd64.exe"
$PypiUrl = "https://pypi.org/simple"

# Download bootstrap file
$BootstrapFile = "${Env:Temp}\$(${BootstrapUrl}.split('/')[-1])"
(New-Object System.Net.WebClient).DownloadFile("$BootstrapUrl", "$BootstrapFile")

# Install python
Get-ChildItem env: | Format-List | Out-File $env:windir\Temp\Beforebootstrap.log
& "$BootstrapFile" -PythonUrl "$PythonUrl" -Verbose -ErrorAction Stop
Get-ChildItem env: | Format-List | Out-File $env:windir\Temp\Afterbootstrap.log
# Install watchmaker
pip install --build "${Env:windir}\Temp" --index-url="$PypiUrl" --upgrade pip setuptools watchmaker

# Run watchmaker
$env:Temp = "${Env:windir}\Temp"
$env:Tmp = "${Env:windir}\Temp"
Get-ChildItem env: | Format-List | Out-File $env:windir\Temp\prewam.log
watchmaker --log-level debug --log-dir=C:\Watchmaker\Logs


$BootstrapUrl = "https://raw.githubusercontent.com/ewierschke/watchmaker/develop/docs/files/bootstrap/watchmaker-bootstrap.ps1"
$PythonUrl = "https://www.python.org/ftp/python/3.6.3/python-3.6.3-amd64.exe"
$PypiUrl = "https://pypi.org/simple"

# Download bootstrap file
$BootstrapFile = "${Env:Temp}\$(${BootstrapUrl}.split('/')[-1])"
(New-Object System.Net.WebClient).DownloadFile("$BootstrapUrl", "$BootstrapFile")

# Install python
Get-ChildItem env: | Format-List | Out-File $env:windir\Temp\Beforebootstrap.log
$params = "`"$BootstrapFile`" -PythonUrl `"$PythonUrl`" -Verbose -ErrorAction Stop"
Start-Process powershell -Argument $params -NoNewWindow -Wait
Get-ChildItem env: | Format-List | Out-File $env:windir\Temp\Afterbootstrap.log
#$env:Path = "$env:Path;$env:ProgramFiles\Python36\Scripts\;$env:ProgramFiles\Python36\"

# Install watchmaker
pip install --index-url="$PypiUrl" --upgrade pip setuptools watchmaker

# Run watchmaker
watchmaker --log-level debug --log-dir=C:\Watchmaker\Logs



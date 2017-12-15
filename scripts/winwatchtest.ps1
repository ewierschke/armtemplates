$BootstrapUrl = "https://raw.githubusercontent.com/plus3it/watchmaker/master/docs/files/bootstrap/watchmaker-bootstrap.ps1"
$PythonUrl = "https://www.python.org/ftp/python/3.6.3/python-3.6.3-amd64.exe"
$PypiUrl = "https://pypi.org/simple"

# Download bootstrap file
$BootstrapFile = "${Env:Temp}\$(${BootstrapUrl}.split('/')[-1])"
(New-Object System.Net.WebClient).DownloadFile("$BootstrapUrl", "$BootstrapFile")

# Install python
& "$BootstrapFile" -PythonUrl "$PythonUrl" -Verbose -ErrorAction Stop

# Install watchmaker
$WinWatchDir = "${env:SystemDrive}\winwatch"
New-Item -Path $WinWatchDir -ItemType "directory" -Force 2>&1 > $null
cd $WinWatchDir
pip install --index-url="$PypiUrl" --upgrade pip setuptools watchmaker

# Run watchmaker
watchmaker -n -s none --log-level debug --log-dir=C:\Watchmaker\Logs
C:\Salt\salt-call.bat --local --retcode-passthrough --no-color --log-file C:\Watchmaker\Logs\salt_call.debug.log --log-file-level debug --log-level error --out quiet --return local state.highstate
exit $LASTEXITCODE
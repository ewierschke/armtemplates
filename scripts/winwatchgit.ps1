$GitRepo = "https://github.com/plus3it/watchmaker.git"
#$GitBranch = "<your-branch>"

$BootstrapUrl = "https://raw.githubusercontent.com/plus3it/watchmaker/master/docs/files/bootstrap/watchmaker-bootstrap.ps1"
$PythonUrl = "https://www.python.org/ftp/python/3.6.0/python-3.6.0-amd64.exe"
$GitUrl = "https://github.com/git-for-windows/git/releases/download/v2.12.2.windows.2/Git-2.12.2.2-64-bit.exe"
$PypiUrl = "https://pypi.org/simple"

# Download bootstrap file
$BootstrapFile = "${Env:Temp}\$(${BootstrapUrl}.split("/")[-1])"
(New-Object System.Net.WebClient).DownloadFile($BootstrapUrl, $BootstrapFile)

# Install python and git
& "$BootstrapFile" `
    -PythonUrl "$PythonUrl" `
    -GitUrl "$GitUrl" `
    -Verbose -ErrorAction Stop

# Upgrade pip and setuptools
pip install --index-url="$PypiUrl" --upgrade pip setuptools

# Clone watchmaker
mkdir C:\Sources; git clone "$GitRepo" --recursive C:\Sources\watchmaker

# Install watchmaker
Set-Location -Path C:\Sources\watchmaker
#cd watchmaker
pip install --index-url "$PypiUrl" --editable .

# Run watchmaker
watchmaker --log-level debug --log-dir=C:\Watchmaker\Logs
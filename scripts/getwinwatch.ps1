$GetWinWatchDir = "${env:SystemDrive}\winwatch"

New-Item -Path $GetWinWatchDir -ItemType "directory" -Force 2>&1 > $null

Invoke-Webrequest "https://raw.githubusercontent.com/ewierschke/armtemplates/runwincustdata/scripts/winwatch.ps1" -Outfile "${GetWinWatchDir}\winwatch.ps1";

powershell.exe -ExecutionPolicy Unrestricted -File "${GetWinWatchDir}\winwatch.ps1"

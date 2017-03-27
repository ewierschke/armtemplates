Invoke-Webrequest https://raw.githubusercontent.com/plus3it/cfn/master/scripts/configure-rdsh.ps1 -Outfile c:\temp\configure-rdsh.ps1;
powershell.exe "Install-WindowsFeature RDS-RD-Server,RDS-Licensing -Verbose";
powershell.exe "Restart-Computer -Force -Verbose";
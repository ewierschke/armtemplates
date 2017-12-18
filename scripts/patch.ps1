#Install Windows Updates
try {
    #Verify if PowerShellGet module is installed. If not install
    if (!(Get-Module -Name PowerShellGet)){
        Invoke-WebRequest 'https://download.microsoft.com/download/C/4/1/C41378D4-7F41-4BBE-9D0D-0E4F98585C61/PackageManagement_x64.msi' -OutFile $($env:temp +'\PackageManagement_x64.msi')
        Start-Process $($env:temp +'\PackageManagement_x64.msi') -ArgumentList "/qn" -Wait
    }
    #Verify if PSWindowsUpdate PowerShell Module is installed. If not install.
    if (!(Get-Module -Name PSWindowsUpdate -List)){
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
        Install-Module -Name PSWindowsUpdate -Scope AllUsers -Confirm:$false -Force
    }
    #module updated need to test approach using new cmdlets
    #Get-WUInstall -WindowsUpdate -AcceptAll -AutoReboot -Confirm:$FALSE -ErrorAction stop
    Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot
}
catch {
    Write-Host "Oops. Something failed when installing patches"
}

#or

. { iwr -useb http://boxstarter.org/bootstrapper.ps1 } | iex; get-boxstarter -Force
Install-WindowsUpdate -SuppressReboots
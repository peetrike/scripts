$WinLogonKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'

    # Set PowerShell as default shell
Set-ItemProperty -Path $WinLogonKey -Name Shell -Value 'PowerShell.exe -NoExit'

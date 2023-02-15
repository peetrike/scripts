[CmdletBinding(
    SupportsShouldProcess
)]
param (
        [ValidateSet(
            'cmd',
            'explorer',
            'powershell'
        )]
    $Shell = 'powershell'
)

$WinLogonKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'

$CommandLine = @{
    'cmd'        = 'cmd.exe /k'
    'explorer'   = 'explorer.exe'
    'powershell' = 'PowerShell.exe -NoExit'
}
    # Set PowerShell as default shell
Set-ItemProperty -Path $WinLogonKey -Name Shell -Value $CommandLine.$Shell

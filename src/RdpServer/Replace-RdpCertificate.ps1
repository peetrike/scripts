#Requires -Modules CimCmdlets

<#
    .SYNOPSIS
        Replace the RDP certificate.
    .DESCRIPTION
        This script replaces the RDP certificate with the one that matches the specified criteria.
    .LINK
        https://learn.microsoft.com/windows/win32/termserv/win32-tsgeneralsetting
    .LINK
        https://learn.microsoft.com/troubleshoot/windows-server/remote/remote-desktop-listener-certificate-configurations
#>

[CmdletBinding()]
param (
        [string]
    $ComputerFqdn = ([Net.Dns]::GetHostEntry('')).HostName
)

$ThumbPrint = @(
    Get-ChildItem -Path Cert:\LocalMachine\my -DnsName $ComputerFqdn -SSLServerAuthentication |
        Sort-Object NotAfter -Descending
)[0].Thumbprint

$getCimInstanceSplat = @{
    ClassName = 'Win32_TSGeneralSetting'
    Namespace = 'root\CIMv2\TerminalServices'
    Filter    = 'TerminalName = "RDP-Tcp"'
}

Get-CimInstance @getCimInstanceSplat |
    Set-CimInstance -Property @{
        SSLCertificateSHA1Hash = $ThumbPrint
    }

Get-Service -Name 'TermService' | Restart-Service -Force

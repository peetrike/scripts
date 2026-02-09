<#
.SYNOPSIS
    Replace the RDP certificate.
.DESCRIPTION
    This script replaces the RDP certificate with the one that uses the specified FQDN.
#>

[CmdletBinding()]
param (
        [string]
    $ComputerFqdn = ([Net.Dns]::GetHostEntry('')).HostName
)

$ThumbPrint = @(
    Get-ChildItem -Path Cert:\LocalMachine\my |
        Where-Object DnsNameList -like $ComputerFqdn |
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

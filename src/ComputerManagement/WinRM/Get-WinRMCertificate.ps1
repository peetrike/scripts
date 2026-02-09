#Requires -Modules pki, Microsoft.WSMan.Management
#Requires -RunAsAdministrator
<#
    .SYNOPSIS
        Export WinRM over HTTPS certificate
    .DESCRIPTION
        Export WinRM over HTTPS certificate
    .EXAMPLE
        .\Get-WinRMCertificate.ps1 -ComputerFqdn 'myserver.domain.com'

        This example configures HTTPS remoting using specified FQDN
#>
[CmdletBinding()]
param (
        [string]
        # Specifies certificate FQDN to use for HTTPS remoting
    $ComputerFqdn = ([Net.Dns]::GetHostEntry('')).HostName,
        [Alias('CertPath', 'Path')]
        [string]
    $CertificatePath = $PWD
)

$SelectorSplat = @{
    ResourceURI = 'winrm/config/listener'
    SelectorSet = @{ Address = '*'; Transport = 'https' }
}
$Listener = Get-WSManInstance @SelectorSplat -ErrorAction Stop | Select-Object -First 1

$thumbPrint = $Listener.CertificateThumbprint
$filename = Join-Path -Path $CertificatePath -ChildPath ('{0}.cer' -f $Listener.HostName)
Get-Item -Path Cert:\LocalMachine\my\$Thumbprint | Export-Certificate -Type CERT -FilePath $filename

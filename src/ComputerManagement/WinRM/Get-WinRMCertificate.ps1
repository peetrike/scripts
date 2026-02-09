#Requires -Modules pki, Microsoft.WSMan.Management
#Requires -RunAsAdministrator
<#
    .SYNOPSIS
        Export WinRM over HTTPS certificate
    .DESCRIPTION
        Export WinRM over HTTPS certificate
    .EXAMPLE
        .\Get-WinRMCertificate.ps1

        This example exports Winrm over HTTPS remoting certificate
#>
[CmdletBinding()]
param (
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

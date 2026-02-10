#Requires -Modules PKI
#Requires -RunAsAdministrator

<#
    .SYNOPSIS
        Creates certificate for WinRM over HTTPS
    .LINK
        https://learn.microsoft.com/powershell/module/pki/new-selfsignedcertificate
    .LINK
        https://learn.microsoft.com/powershell/module/pki/export-pfxcertificate
#>

[CmdletBinding()]
param (
        [Parameter(ValueFromPipeline)]
        [PSDefaultValue(Help = 'computer FQDN and HostName')]
        [Alias('DnsName', 'Fqdn')]
        [string[]]
        # Specifies certificate Subject Alternate Names to use for HTTPS remoting
    $ComputerFqdn = (
        @(
            [Net.Dns]::GetHostEntry('').HostName
            [Net.Dns]::GetHostName()
        ) | Select-Object -Unique
    ),
        [PSDefaultValue(Help = 'Current location')]
        [Alias('CertPath', 'Path')]
        [string]
        # Specifies certificate export path
    $CertificatePath = $PWD,
        [switch]
        # Specifies that certificate and private key should be exported
    $Export
)

end {
    $CertLocation = 'Cert:\LocalMachine\My'

    $NewCertProps = @{
        FriendlyName      = 'WinRM self-signed'
        DnsName           = $ComputerFqdn
        CertStoreLocation = $CertLocation
        KeyExportPolicy   = if ($Export) { 'Exportable' } else { 'NonExportable' }
        KeySpec           = 'Signature' #[Microsoft.CertificateServices.Commands.KeySpec]::Signature
        TextExtension     = '2.5.29.37={text}1.3.6.1.5.5.7.3.1'     # server authentication
        KeyLength         = 4096
        HashAlgorithm     = 'SHA256'
    }

    $NewCertificate = New-SelfSignedCertificate @NewCertProps

    $FilePath = Join-Path -Path $CertificatePath -ChildPath ('{0} self-signed.cer' -f $ComputerFqdn[0])
    $NewCertificate | Export-Certificate -Type CERT -FilePath $FilePath

    if ($Export) {
        $FilePath = Join-Path -Path $CertificatePath -ChildPath ('{0} self-signed.pfx' -f $ComputerFqdn[0])
        $Password = Get-RandomString -Length 15
        $SecurePassword = ConvertTo-SecureString -AsPlainText -Force -String $Password
        $NewCertificate | Export-PfxCertificate -FilePath $FilePath -Password $SecurePassword
        $NewCertificate | Remove-Item #-DeleteKey
        Write-Warning -Message ('Write it down: {0}' -f $Password)
        $null = Import-PfxCertificate -FilePath $FilePath -Password $SecurePassword -CertStoreLocation $CertLocation
    }
}

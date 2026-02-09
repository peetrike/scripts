#Requires -Modules PKI

<#
    .SYNOPSIS
        Generate certificate for application-based authentication in Azure
    .LINK
        https://docs.microsoft.com/azure/active-directory/develop/howto-create-self-signed-certificate
    .LINK
        https://docs.microsoft.com/powershell/module/pki/new-selfsignedcertificate
#>

[CmdletBinding()]
param (
        [Alias('Fqdn')]
        [string[]]
    $ComputerFqdn = @(
            ([Net.Dns]::GetHostEntry('')).HostName
            [Net.Dns]::GetHostName()
        ),
        [Alias('CertPath', 'Path')]
        [string]
    $CertificatePath = $PWD,
        [switch]
    $Export
)

if ([Environment]::OSVersion.Version -notlike '10.*') {
    throw 'This script requires Windows 10/Server 2016 to function'
}

$KeyExportPolicy = if ($Export.IsPresent) {
    'Exportable'
} else { 'NonExportable' }

$NewCertProps = @{
    FriendlyName      = 'Computer self-signed {0}' -f $ComputerFqdn[0]
    #Subject           = $ComputerFqdn
    DnsName           = $ComputerFqdn
    CertStoreLocation = 'Cert:\LocalMachine\My'
    KeyExportPolicy   = $KeyExportPolicy
    KeySpec           = 'Signature' #[Microsoft.CertificateServices.Commands.KeySpec]::Signature
    KeyLength         = 4096
    HashAlgorithm     = 'SHA256'
}

$FilePath = Join-Path -Path $CertificatePath -ChildPath ($FriendlyName + '.cer')

$NewCertificate = New-SelfSignedCertificate @NewCertProps

$NewCertificate | Export-Certificate -Type CERT -FilePath $FilePath

if ($Export.IsPresent) {
    $FilePath = Join-Path -Path $CertificatePath -ChildPath ($FriendlyName + '.pfx')
    $Password = Get-RandomString
    $SecurePassword = ConvertTo-SecureString -AsPlainText -Force -String $Password
    $NewCertificate | Export-PfxCertificate -FilePath $FilePath -Password $SecurePassword
    Write-Warning -Message ('Write it down: {0}' -f $Password)
    $NewCertificate | Remove-Item -DeleteKey
}

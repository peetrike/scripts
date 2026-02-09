<#
    .SYNOPSIS
        Configure HTTPS remoting
    .DESCRIPTION
        Configure WinRM to use HTTPS remoting
    .EXAMPLE
        .\set-HttpsRemoting.ps1 -ComputerFqdn 'myserver.domain.com'

        This example configures HTTPS remoting using specified FQDN
#>
[CmdletBinding()]
param (
        [string]
        # Specifies certificate FQDN to use for HTTPS remoting
    $ComputerFqdn = ([Net.Dns]::GetHostEntry('')).HostName
)

$ThumbPrint = @(
    Get-ChildItem -Path Cert:\LocalMachine\my |
        Where-Object DnsNameList -like $ComputerFqdn |
        Sort-Object NotAfter -Descending
)[0].Thumbprint

$ValueSet = @{
    CertificateThumbprint = $ThumbPrint
}
$SelectorSplat = @{
    ResourceURI = 'winrm/config/listener'
    SelectorSet = @{ Address = '*'; Transport = 'https' }
}
if (Get-WSManInstance @SelectorSplat -ErrorAction SilentlyContinue) {
    Write-Verbose -Message 'Replacing Cert thumbprint in existing listener'
    Set-WSManInstance @SelectorSplat -ValueSet $ValueSet
} else {
    Write-Verbose -Message 'Creating new listener'
    $ValueSet.Hostname = $ComputerFqdn
    New-WSManInstance @SelectorSplat -ValueSet $ValueSet
}

$RuleSplat = @{
    Name        = 'WINRM-HTTPS-In-TCP'
    DisplayName = 'Windows Remote Management (HTTPS-In)'
    Group       = '@FirewallAPI.dll,-30267'
    Direction   = 'Inbound'
    Protocol    = 'TCP'
    LocalPort   = 5986
    Action      = 'Allow'
}
try {
    Get-NetFirewallRule -Name $RuleSplat.Name -ErrorAction Stop | Set-NetFirewallRule -Enabled True
} catch {
    Write-Verbose -Message 'Creating new firewall rule'
    New-NetFirewallRule @RuleSplat
}

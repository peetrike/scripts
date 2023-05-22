#Requires -Version 7
# Requires -Modules Devolutions.PowerShell

<#PSScriptInfo
    .VERSION 1.0.2
    .GUID ff04c0b0-014a-4aaf-aa61-c022cf028259

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2019.  All rights reserved.

    .TAGS rdm, network, hopper
    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES RemoteDesktopManager
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.0.2] - 2021.11.19 - Use UTF-8 with BOM encoding when exporting .CSV file
        [1.0.1] - 2019.11.22 - Update RDM module requirement
        [1.0.0] - 2019.11.22 - Initial release

    .PRIVATEDATA
#>

<#
    .DESCRIPTION
        Export RDP session list that use specified hopper (RD Gateway) from RDM
        data source
    .EXAMPLE
        Export-RdmHopper.ps1 -Group MyFolder

        Export sessions with RDP Gateway information from specific folder.
    .EXAMPLE
        Export-RdmHopper.ps1 -Gateway my.gateway -Path gateway.csv

        Export sessions with specific RDP Gateway.
        Have the result exported as .csv file.
    .EXAMPLE
        Export-RdmHopper.ps1 -DataSource MyServer -Vault myVault -Force

        Export sessions from specified Vault in specified data source.
        Don't ask permission to export all connections in Vault.
#>

[CmdletBinding()]
param (
        [string]
        # Path to .csv file to be written
    $Path,
        [SupportsWildcards()]
        [Alias('Hopper')]
        [string]
        # RD Gateway server to look for
    $Gateway = '*',
        [string]
        # RDM folder name to scan
    $Group,
        [ValidateScript( {
            Get-RDMDataSource -Name $_
        })]
        [string]
        # RDM Data Source to be used
    $DataSource,
        [string]
        # Vault name to process
    $Vault,
        [switch]
        # Don't ask permission to do full vault export
    $Force
)

if ($DataSource) {
    Get-RDMDataSource -Name $DataSource | Set-RDMCurrentDataSource
} else {
    $CurrentDataSource = Get-RDMCurrentDataSource
    $DataSource = $CurrentDataSource.Name
}
Write-Verbose -Message ('Operating with datasource {0}' -f $DataSource)

if ($Vault) {
    $Repository = Get-RDMRepository -Name $Vault
    Set-RDMCurrentRepository -Repository $Repository
} else {
    $currentVault = Get-RDMCurrentRepository
    $Vault = $currentVault.Name
}
Write-Verbose -Message ('Working with vault: {0}' -f $Vault)

$SessionParams = @{
    IncludeSubfolders = $true
}
if ($Group) {
    Write-Verbose -Message ('searching for customer: {0}' -f $Group)
    $SessionParams.GroupName = $Group
} elseif (-not ($Force -or $PSCmdlet.ShouldContinue('Do you really want to scan whole Vault?', 'Full scan'))) {
    exit
}

$sessionList = Get-RDMSession @SessionParams |
    Where-Object ConnectionType -Like 'RDPConfigured' |
    Where-Object { $_.RDP.GatewayHostname -like $Gateway } |
    # Sort-Object -Property Host -Unique |
    ForEach-Object {
        Write-Verbose -Message ('Processing session: {0}' -f $_.Name)
        $ObjectProperties = [ordered]@{
            Folder       = $_.Group.split('\')[-1]
            ComputerName = $_.Name
            Hostname     = $_.Host
            IP           = $_.Host
            Port         = $_.HostPort
            Gateway      = $_.RDP.GatewayHostname
        }
        $Resolved = Resolve-DnsName $_.Host -ErrorAction SilentlyContinue -Verbose:$false
        if (($_.Host -as [ipaddress]) -and $Resolved.NameHost) {
            $ObjectProperties.HostName = $Resolved.NameHost
        } elseif ($Resolved.IPAddress) {
            $ObjectProperties.IP = $Resolved.IPAddress
        }
        if ($ObjectProperties.Port -eq -1) { $ObjectProperties.Port = 3389 }
        [PSCustomObject] $ObjectProperties
    }

if ($Path) {
    $ExportProps = @{
        Encoding = 'UTF8'
        Path     = $Path
    }
    if ($PSVersionTable.PSVersion.Major -gt 5) {
        $ExportProps.Encoding = 'utf8BOM'
    } else {
        $ExportProps.NoTypeInformation = $true
    }
    $sessionList |
        Export-Csv @ExportProps -UseCulture
} else {
    $sessionList
}

#Requires -Version 5.1
#Requires -Modules RemoteDesktopManager

<#PSScriptInfo
    .VERSION 1.1.2
    .GUID 444d1e61-3fde-40f8-ac43-11a1b88c2c5c

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2019.  All rights reserved.

    .TAGS rdm, report, network, port
    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://bitbucket.atlassian.teliacompany.net/projects/PWSH/repos/scripts/
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES RemoteDesktopManager
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES
    .RELEASENOTES
        [1.0.0] - 2019.09.30 - Initial release
        [1.0.1] - 2019.09.30 - added example
                               added confirmation for full vault scan
        [1.1.0] - 2019.09.30 - added support to scan RDM Session port
        [1.1.1] - 2019.09.30 - if -port is not specified then -TestRdmPort is assumed
        [1.1.2] - 2021.10.06 - update RDM module requirement

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Test RDM sessions for open ports

    .DESCRIPTION
        This script checks RDM sessions for open ports.

    .EXAMPLE
        Test-RdmSession -Group MyCustomer -Port 3389

        Tests all RDP sessions in folder MyCustomer for open port tcp/3389

    .NOTES
        Remote Desktop manager must be installed on computer where script is being used.
#>

[CmdletBinding()]
param (
        [uint16]
        # port to be tested
    $Port,
        [switch]
        # scan port saved in RDM session
    $TestRdmPort,
        [string]
        # RDM folder name to scan
    $Group,
        [ValidateScript({
            Get-RDMDataSource -Name $_
        })]
        [string]
        # RDM Data Source to be used
    $DataSource,
        [string]
        # Vault name to process
    $Vault,
        [switch]
    $Force
)

if ($DataSource) {
    Get-RDMDataSource -Name $DataSource | Set-RDMCurrentDataSource
    Update-RDMRepository
    Update-RDMUI
} else {
    $CurrentDataSource = Get-RDMCurrentDataSource
    $DataSource = $CurrentDataSource.Name
}
Write-Verbose -Message ('Operating with datasource {0}' -f $DataSource)

if ($Vault) {
    $Repository = Get-RDMRepository -Name $Vault
    Set-RDMCurrentRepository -Repository $Repository
    Update-RDMRepository
    Update-RDMUI
} else {
    $currentVault = Get-RDMCurrentRepository
    $vault = $currentVault.Name
}
Write-Verbose -Message ('Working with vault: {0}' -f $Vault)

$SessionParams = @{
    IncludeSubfolders = $true
}

if ($Group) {
    Write-Verbose -Message ('searching for customer: {0}' -f $Group)
    $SessionParams.GroupName = $Group
} elseif (-not ($Force -or $PSCmdlet.ShouldContinue("Do you really want to scan whole Vault?", "Full scan"))) {
    exit
}

$SessionList = Get-RDMSession @SessionParams |
    Where-Object ConnectionType -Like 'RDPConfigured'

function Test-RdmConnection {
    param (
            [parameter(
                ValueFromPipeline
            )]
            [RemoteDesktopManager.PowerShellModule.PSOutputObject.PSConnection]
        $InputObject,
            [uint16]
        $Port
    )

    process {
        $TestProperties = @{
            ComputerName = $InputObject.Host
        }
        $TestProperties.Port = if ($Port) { $Port } elseif ($InputObject.HostPort -ne -1) { $InputObject.HostPort } else { 3389 }
        $result = Test-NetConnection @TestProperties
        [PSCustomObject] @{
            Folder   = $InputObject.Group
            ComputerName = $InputObject.Name
            Hostname = $result.ComputerName
            IP = $result.RemoteAddress
            Port = $result.RemotePort
            PingSucceeded = $result.PingSucceeded
            TcpTestSucceeded = $result.TcpTestSucceeded
        }
    }
}
if ($TestRdmPort -or -not $Port) {
    Write-Verbose -Message 'Checking port from RDM session'
    $SessionList | Test-RdmConnection
}

if ($Port) {
    Write-Verbose -Message ('Checking port: {0}' -f $Port)
    $SessionList | Sort-Object -Property Host -Unique | Test-RdmConnection -Port $Port
}

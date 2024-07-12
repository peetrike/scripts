#Requires -Version 7
#Requires -Modules Devolutions.PowerShell

<#PSScriptInfo
    .VERSION 0.0.1
    .GUID 4b52f9d7-296c-462b-9dc3-b2b25c6ee1f1

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2024.  All rights reserved.

    .TAGS rdm, network, hopper
    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES Devolutions.PowerShell
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [0.0.1] - 2024.07.11 - Initial release

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

[CmdletBinding(
    SupportsShouldProcess
)]
param (
        [SupportsWildcards()]
        [Alias('Hopper')]
        [string]
        # RD Gateway server to look for
    $Gateway = '*',
        [string]
        # RDM folder name to scan
    $Group,
        [Parameter(Mandatory)]
        [string]
    $CredentialName,
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



$Credential = Get-RDMSession -Name $CredentialName |
    Where-Object ConnectionType -Like 'Credential'

switch ($Credential.Count) {
    0 { Write-Error -Message 'There CredentialName points to no credential' -ErrorAction Stop }
    1 {
        $CredentialId = $Credential.ID
    }
    default {
        $Credential = $Credential |
            Select-Object -Property Name, ID |
            Out-GridView -Title 'Select credential to use' -OutputMode Single
        $CredentialId = $Credential.ID
    }
}
if (-not $CredentialId) {
    Write-Error -Message 'There Credential not picked' -ErrorAction Stop
} else {
    Write-Verbose -Message ('Using Credential: {0}' -f $CredentialId)
}

$SessionParams = @{
    IncludeSubfolders = $true
}
if ($Group) {
    Write-Verbose -Message ('searching for customer: {0}' -f $Group)
    $SessionParams.GroupName = $Group
} elseif (-not ($Force -or $PSCmdlet.ShouldContinue('Do you really want to scan whole Vault?', 'Full scan'))) {
    exit
}

Get-RDMSession @SessionParams |
    Where-Object {
        $_.ConnectionType -Like 'RDPConfigured' -and
        $_.RDP.GatewayHostname -like $Gateway -and
        $_.RDP.GatewayCredentialConnectionID -and $_.RDP.GatewayCredentialConnectionID -ne $CredentialId
    } |
    ForEach-Object {
        $CurrentSession = $_
        $OldCredential = Get-RDMSession -ID $CurrentSession.RDP.GatewayCredentialConnectionID
        Write-Verbose -Message (
            'Session: {0}; Credential to replace: {1}' -f $CurrentSession.Name, $OldCredential.Name
        )
        if ($PSCmdlet.ShouldProcess($CurrentSession.Name, 'Change Credential')) {
            $CurrentSession.RDP.GatewayCredentialConnectionID = $CredentialId
            Set-RDMSession -Session $CurrentSession -Refresh
        }
    }

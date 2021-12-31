#Requires -Version 5.1
#Requires -Modules RemoteDesktopManager

<#PSScriptInfo

    .VERSION 1.0.1
    .GUID 956e359e-18fc-4499-8a35-1aee5b0032db

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2019.  All rights reserved.

    .TAGS rdm, network, port
    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://bitbucket.atlassian.teliacompany.net/projects/PWSH/repos/scripts/
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES RemoteDesktopManager
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.0.0] - 2019.09.30 - Initial release
        [1.0.1] - 2021.10.06 - Changed RDM module requirement

    .PRIVATEDATA
#>

<#
    .DESCRIPTION
        Export RDP session IP/Port from RDM datasource
#>

[CmdletBinding()]
Param(
        [string]
    $Path,
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
        # Dont ask permission to do full vault export
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

$sessionList = Get-RDMSession @SessionParams |
    Where-Object ConnectionType -Like 'RDPConfigured' |
    # Sort-Object -Property Host -Unique |
    ForEach-Object {
        Write-Verbose -Message ('Processing session: {0}' -f $_.Name)
        $ObjectProperties = [ordered]@{
            Folder       = $_.Group.split('\')[-1]
            ComputerName = $_.Name
            Hostname     = $_.Host
            IP           = $_.Host
            Port         = $_.HostPort
        }
        $Resolved = Resolve-DnsName $_.Host -ErrorAction SilentlyContinue -Verbose:$false
        if (($_.Host -as [ipaddress]) -and $Resolved.NameHost) {
            $ObjectProperties.HostName = $Resolved.NameHost
        } elseif ($Resolved.IPAddress) {
            $ObjectProperties.IP = $Resolved.IPAddress
        }
        if ($ObjectProperties.port -eq -1) { $ObjectProperties.Port = 3389 }
        New-Object -TypeName 'PSCustomObject' -Property $ObjectProperties
    }

if ($Path) {
    $sessionList |
    Export-Csv -UseCulture -Encoding Default -Path $Path -NoTypeInformation
} else {
    $sessionList
}

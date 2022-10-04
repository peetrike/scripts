#Requires -Version 3.0
# Requires -Modules ExchangeOnlineManagement

<#PSScriptInfo
    .VERSION 1.1.1

    .GUID 620aced0-5d45-4168-b454-2e603e1d09ca

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2022.  All rights reserved.

    .TAGS office365 group report

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.1.1] - Import only set of command when connecting with ExO.
        [1.1.0] - refactor script: Support MFA authentication and delegated access with ExO module.
        [1.0.4] - refactor script: use existing connection to Exchange Online, when available.
        [1.0.3] - added missing parameter names, changed -Filter to string
        [1.0.2] - changed Import-PSSession so that it imports only required cmdlets
        [1.0.1] - Initial release with documentation

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Generate distribution group members report.
    .DESCRIPTION
        This script collects Office 365 Distribution Group members.
        The result is saved as one .csv file or separate .csv file for each
        Distribution Group.

        When you haven't already established connection to Exchange Online, the
        Credential parameter is required to connect to Exchange Online.
    .EXAMPLE
        Get-DistributionGroupReport -Credential $MyCredential

        This example uses previously obtained credential variable.
    .EXAMPLE
        Get-DistributionGroupReport -UserPrincipalName me@consoto.com -DelegatedOrganization adatum.com

        This example uses MFA authentication and connects to delegated organization.
    .EXAMPLE
        Get-DistributionGroupReport -OutputFile Multiple

        This example generates separate report for each distribution group.
    .EXAMPLE
        Get-DistributionGroupReport -Filter "Name -like 'Group*'"

        This example uses custom filter to get list of distribution groups.
    .INPUTS
        None
    .OUTPUTS
        None
    .NOTES
        You need to be assigned permissions before you can run this script.
        To find the permissions required to run any cmdlet or parameter in your
        organization, see Find the permissions required to run any Exchange
        cmdlet (https://docs.microsoft.com/powershell/exchange/find-exchange-cmdlet-permissions).
    .LINK
        Get-DistributionGroup
    .LINK
        Get-DistributionGroupMember
    .LINK
        https://docs.microsoft.com/powershell/exchange/filter-properties
#>

[CmdletBinding(
    DefaultParameterSetName = 'MFA'
)]
param (
        [string]
        # The Filter parameter indicates the OPath filter used to filter recipients.
    $Filter,
        [ValidateSet('Single', 'Multiple')]
        [string]
        # Specifies whether to create single report file or separate file for every distribution group.
    $OutputFile = 'Single',
        [parameter(
            HelpMessage = 'Enter credential for Office365 tenant',
            Mandatory,
            ParameterSetName = 'Credential'
        )]
        [System.Management.Automation.Credential()]
        [PSCredential]
        # The Credential parameter specifies the user name and password that's used to connect Office 365.
    $Credential,
        [parameter(
            ParameterSetName = 'MFA'
        )]
        [string]
        # Specifies User name to use for authentication
    $UserPrincipalName,
        [parameter(
            ParameterSetName = 'MFA'
        )]
        [string]
        # Delegated organization domain name to connect
    $DelegatedOrganization
)

$CmdletList = 'Get-DistributionGroup', 'Get-DistributionGroupMember'
try {
    $null = Get-Command Get-DistributionGroup -ErrorAction Stop
    Write-Verbose -Message 'Connection already established'
} catch {
    if (Get-Module ExchangeOnlineManagement -ListAvailable) {
        Write-Verbose -Message 'Connecting using EXO v2 module using MFA'
        $ConnectionParams = @{
            ShowBanner  = $false
            CommandName = $CmdletList
        }

        if ($Credential) {
                $ConnectionParams.Credential = $Credential
        } elseif ($UserPrincipalName) {
                $ConnectionParams.UserPrincipalName = $UserPrincipalName
        }
        if ($DelegatedOrganization) { $ConnectionParams.DelegatedOrganization = $DelegatedOrganization }
        #Import-Module ExchangeOnlineManagement -Verbose:$false
        Connect-ExchangeOnline @ConnectionParams
    } else {
        Write-Warning -Message 'EXO v2 module not available, importing direct PS session'
        if (-not $Credential) {
            $Credential = Get-Credential -Message 'Enter credential for Office365 tenant'
        }
        $SessionProps = @{
            ConfigurationName = 'Microsoft.Exchange'
            ConnectionUri     = 'https://outlook.office365.com/powershell-liveid/'
            Credential        = $Credential
            Authentication    = 'Basic'
        }
        $Session = New-PSSession @SessionProps -AllowRedirection -Verbose:$false
        $null = Import-PSSession -Session $Session -DisableNameChecking -CommandName $CmdletList -Verbose:$false
    }
}

$CsvProps = @{
    UseCulture        = $true
    Encoding          = 'Default'
    NoTypeInformation = $true
}

$dgProps = @{
    ResultSize = 'Unlimited'
}
if ($Filter) {
    $dgProps.Filter = $Filter
}

$GroupNameProperty = @{ Name = 'GroupName'; expression = { $Group.DisplayName } }
$GroupMember = Get-DistributionGroup @dgProps | ForEach-Object {
    $Group = $_
    Write-Verbose -Message ('Processing group: {0}' -f $Group.DisplayName)

    $members = Get-DistributionGroupMember -Identity $Group.DistinguishedName -ResultSize Unlimited |
        Select-Object -Property Name, Alias, PrimarySmtpAddress, RecipientType

    switch ($OutputFile) {
        'Single' {
            $members | Select-Object -Property $GroupNameProperty, *
        }
        'Multiple' {
            $members | Export-Csv @CsvProps -Path ('{0}.csv' -f $Group.Name)
        }
    }
}

if ($OutputFile -like 'Single') {
    $GroupMember | Export-Csv @CsvProps -Path 'AllGroupsReport.csv'
}

if ($Session) {
    Remove-PSSession -Session $Session
}

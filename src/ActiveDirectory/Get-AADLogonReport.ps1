#Requires -Version 3.0
#Requires -Modules AzureAdPreview

<#PSScriptInfo
    .VERSION 1.0.1

    .GUID 6894168a-33aa-430b-b7c9-66cd749c51ab

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2021.  All rights reserved.

    .TAGS Azure, ActiveDirectory, AD, user, logon, report

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://bitbucket.atlassian.teliacompany.net/projects/PWSH/repos/scripts/
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES AzureAdPreview
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.0.1] - 2021.03.25 - Add verbose message to report generation
        [1.0.0] - 2021.01.21 - Initial Release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Compiles Azure AD logon report
    .DESCRIPTION
        This script generates Azure AD logon report.
        The result is saved as .csv file.  The report file name is Azure AD tenant name or ID.

        If there is already existing connection to Azure AD, that connection is used.
        Otherwise, the user credential or service principal information should be provided.
    .EXAMPLE
        Get-AADLogonReport.ps1 -ConfigPath myconfig.json -Latest -PassThru |
            Out-GridView

        This example takes service principal information from configuration file.
        The logon report will contain only latest logon event per user.
        The results will be piped to Out-GridView instead of writing to .csv file.
    .EXAMPLE
        $ConnectProperties = @{
            CertificateThumbPrint = CDD4EEAE6000AC7F40C3802C171E30148030C072
            TenantID = 8e8b2e5a-91d1-4420-b3b2-af75a2c7ad34
            ApplicationId = 6c1e51a5-acf4-4764-8768-847fa86c2bce
        }
        Get-AADLogonReport.ps1 @ConnectionProperties -Include Success -FilterAppId c44b4083-3bb0-49c1-b47d-974e53cbdf3c

        This example authenticates to Azure AD with provided service principal.
        The logon report will contain only successful logon events for Azure Portal application.
    .EXAMPLE
        Get-AADLogonReport.ps1 -Credential me@company.onmicrosoft.com -After ([datetime]::Today)

        This example authenticates to Azure AD with provided credential.
        The logon report will contain only logon events for today.
    .LINK
        https://docs.microsoft.com/graph/api/signin-list
    .LINK
        Get-AzureADAuditSignInLogs
#>

[CmdletBinding(
    DefaultParameterSetName = 'Config'
)]
param (
    #region ParameterSet Config
        [parameter(
            ParameterSetName = 'Config'
        )]
        [ValidateScript( {
            if (Test-Path -Path $_) { $true }
            else { throw 'Config file not found' }
        })]
        [PSDefaultValue(Help = '<scriptname>.json in the same folder as script')]
        [string]
        # Specifies config file path to be loaded
    $ConfigPath = (Join-Path -Path $PSScriptRoot -ChildPath ((Get-Item $PSCommandPath).BaseName + '.json')),
    #endregion

    #region ParameterSet Application
        [parameter(
            Mandatory,
            ParameterSetName = 'Application'
        )]
        [guid]
        # Specifies Azure AD application ID of the service principal for authentication
    $ApplicationId,
        [parameter(
            Mandatory,
            ParameterSetName = 'Application'
        )]
        [guid]
        # Specifies Azure AD Tenant Id to connect with.
    $TenantId,
        [parameter(
            Mandatory,
            ParameterSetName = 'Application'
        )]
        [string]
        # Specifies certificate thumbprint of a X.509 certificate to use for authentication.
    $CertificateThumbPrint,
    #endregion

    #region ParameterSet Credential
            [Parameter(
                Mandatory,
                ParameterSetName = 'Credential'
            )]
            [ValidateNotNull()]
            [System.Management.Automation.PSCredential]
            [System.Management.Automation.Credential()]
            # Specifies the user account credentials to use when performing this task.
        $Credential,
    #endregion

        [datetime]
        # Specifies date to use for filtering logon events
    $After,
        [string]
        # Specifies Application ID to filter logon events
    $FilterAppId,
        [ValidateSet(
            'Both',
            'Failure',
            'Success'
        )]
        [string]
        # Specifies whether to get Success or Failure logon events.  By default both are retrieved.
    $Include = 'Both',
        [ValidateScript( {
            Test-Path -Path $_ -PathType Container
        } )]
        [PSDefaultValue(Help = 'Current working directory')]
        [Alias('Path')]
        [string]
        # Specifies the folder, where report .CSV should be saved.  Default value is current directory.
    $ReportPath = $PWD,
        [Alias('Top')]
        [int]
        # The maximum number of logon events to return.
    $First,
        [switch]
        # Specifies that only latest logon event per user should be preserved.
    $Latest,
        [switch]
        # Passes logon events to pipeline instead of report file.
    $PassThru
)

try {
    $ConnectionInfo = Get-AzureADCurrentSessionInfo -ErrorAction Stop
    Write-Verbose -Message ('Using previous connection to {0} as: {1}' -f $ConnectionInfo.TenantId, $ConnectionInfo.Account)
} catch {
    if ($PSCmdlet.ParameterSetName -like 'Config') {
        Write-Verbose -Message ('Loading config file: {0}' -f $ConfigPath)
        $config = Get-Content -Path $ConfigPath | ConvertFrom-Json
        $TenantId = $config.TenantId
        $ApplicationId = $config.ApplicationId
        $CertificateThumbPrint = $config.CertificateThumbPrint
    }
    $connectionParams = if ($Credential) {
        @{
            Credential = $Credential
        }
    } else {
        @{
            TenantId              = $TenantId.Guid
            ApplicationId         = $ApplicationId.Guid
            CertificateThumbprint = $CertificateThumbPrint
        }
    }
    $ConnectionInfo = Connect-AzureAD @connectionParams
    Write-Verbose -Message ('Connected to {0} as: {1}' -f $ConnectionInfo.TenantId, $ConnectionInfo.Account)
}

if ($After) {
    $Filter = 'CreatedDateTime ge {0:yyyy-MM-dd}' -f $After
}

if ($FilterAppId) {
    $Filter = $Filter, ("appId eq '{0}'" -f $FilterAppId) -join ' and '
}

switch ($Include) {
    'Failure' {
        $Equation = 'ne'
    }
    'Success' {
        $Equation = 'eq'
    }
}
if ($Equation) {
    $Filter = $Filter, ('status/errorcode {0} 0' -f $Equation) -join ' and '
}

Write-Verbose -Message ('Filter: {0}' -f $filter)

$RequestProps = @{
    All = $true
}
if ($Filter) {
    $RequestProps.Filter = $Filter
}
if ($First) {
    $RequestProps.Top = $First
    $RequestProps.All = $false
}

$ExportProperties = @(
    'UserDisplayName'
    'UserPrincipalName'
    'IpAddress'
    'AppDisplayName'
    'AppId'
    'ClientAppUsed'
)

$SignInEvents = foreach ($event in Get-AzureADAuditSignInLogs @RequestProps) {
    $EventProps = @{}
    foreach ($p in $ExportProperties) {
        $EventProps.$p = $event.$p
    }
    $EventProps.CreatedDateTime = [datetime]$event.CreatedDateTime

    $EventProps.ErrorCode = $event.Status.ErrorCode
    $EventProps.ErrorDetails = $event.Status.FailureReason

    $EventProps.OperatingSystem = $event.DeviceDetail.OperatingSystem
    $EventProps.Browser = $event.DeviceDetail.Browser
    $EventProps.DeviceName = $event.DeviceDetail.DisplayName

    $EventProps.Location = $event.Location.CountryOrRegion
    [pscustomobject] $EventProps
}

if ($Latest.IsPresent) {
    Write-Verbose -Message 'Filtering latest events only'
    $SignInEvents = $SignInEvents |
        #Sort-Object -Property UserPrincipalName |
        Group-Object -Property UserPrincipalName |
        ForEach-Object {
            $_.Group |
                Sort-Object -Property CreatedDateTime -Descending |
                Select-Object -First 1
        }
}

if ($PassThru.IsPresent) {
    $SignInEvents
} else {
    $CsvFileName = if ($ConnectionInfo.TenantDomain) {
        $ConnectionInfo.TenantDomain
    } else {
        $ConnectionInfo.TenantId.Guid
    }
    $CsvProps = @{
        UseCulture        = $true
        Encoding          = 'Default'
        NoTypeInformation = $true
        Path              = Join-Path -Path $ReportPath -ChildPath ($CsvFileName + '.csv')
    }

    Write-Verbose -Message ('Saving Report to: {0}' -f $CsvProps.Path)
    $SignInEvents |
        Export-Csv @CsvProps
}
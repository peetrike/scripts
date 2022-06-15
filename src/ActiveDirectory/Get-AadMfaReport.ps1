#Requires -Version 5.1
#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Reports, Microsoft.Graph.Users

<#PSScriptInfo
    .VERSION 2.1.1
    .GUID cdcc21f2-2d08-4d7b-9cf3-524ab2781cd8

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2022.  All rights reserved.

    .TAGS Azure, ActiveDirectory, AD, user, MFA, report, PSEdition_Desktop, Windows

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES Microsoft.Graph.Authentication, Microsoft.Graph.Reports, Microsoft.Graph.Users
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [2.1.1] - 2022.06.15 - Add support for using certificate from computer store.
        [2.1.0] - 2022.06.08 - Replace parameter -Credential with -Interactive
        [2.0.0] - 2022.05.17 - Script rewritten to use Microsoft.Graph modules
        [1.0.3] - 2022.05.16 - Added other (non-default) MFA methods to report.
        [1.0.2] - 2021.12.31 - Moved script to Github.
        [1.0.1] - 2021.06.07 - Remove redundant module dependency.
        [1.0.0] - 2021.06.07 - Remove certificate-based authentication.
        [0.0.1] - 2021.06.03 - Initial release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Generates Azure AD users MFA status report

    .DESCRIPTION
        This script generates Azure AD users MFA status report.

    .EXAMPLE
        Get-AadMfaReport -Interactive

        Generate MFA report using browser-based logon form.

    .EXAMPLE
        Get-AadMfaReport -PassThru -MfaStatus Enabled

        Generate MFA report that only included users with Enabled MFA.
        Send the result to standard output, don't generate .csv report.

    .OUTPUTS
        The MFA report entries, if `-PassThru` parameter is used.

    .NOTES
        This script requires following Graph API permissions:
        * UserAuthenticationMethod.Read.All
        * AuditLog.Read.All

    .LINK
        https://docs.microsoft.com/graph/api/resources/userregistrationdetails
#>

[CmdletBinding(
    DefaultParameterSetName = 'Interactive'
)]
[OutputType([PSCustomObject])]

param (
    #region ParameterSet Config
        [parameter(
            Mandatory,
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

    #region ParameterSet Interactive
            [Parameter(
                ParameterSetName = 'Interactive'
            )]
            [switch]
            # Specifies the user account credentials to use when performing this task.
        $Interactive,
    #endregion

        [ValidateScript( {
            Test-Path -Path $_ -PathType Container
        } )]
        [PSDefaultValue(Help = 'Current working directory')]
        [Alias('Path')]
        [string]
        # Specifies the folder, where report .CSV should be saved.  Default value is current directory.
    $ReportPath = $PWD,
        [switch]
        # Passes user accounts to pipeline instead of report file.
    $PassThru,
        [ValidateSet(
            'All',
            'Disabled',
            'Enabled'
        )]
        [string]
        # Specifies that only users with given MFA status should be returned.
    $MfaStatus = 'All',
        [string]
        # Specifies string that is used to separate authentication methods.
    $MfaListSeparator = "`n"
)

$ConnectionInfo = Get-MgContext
if ($ConnectionInfo.Scopes -match 'UserAuthenticationMethod') {
    Write-Verbose -Message (
        'Using existing connection to {0} with app: {1}' -f $ConnectionInfo.TenantId, $ConnectionInfo.AppName
    )
} else {
    if ($PSCmdlet.ParameterSetName -like 'Config') {
        Write-Verbose -Message ('Loading config file: {0}' -f $ConfigPath)
        $config = Get-Content -Path $ConfigPath | ConvertFrom-Json
        $TenantId = $config.TenantId
        $ApplicationId = $config.ApplicationId
        $CertificateThumbPrint = $config.CertificateThumbPrint
    }

    if ($PSCmdlet.ParameterSetName -like 'Interactive') {
        $connectionParams = @{ Scopes = 'AuditLog.Read.All', 'Directory.Read.All' }
    } else {
        $connectionParams = @{
            TenantId = $TenantId.Guid
            ClientId = $ApplicationId.Guid
        }
        $CertPath = Join-Path -Path Cert:\LocalMachine\My -ChildPath $CertificateThumbPrint
        try {
            $Cert = Get-Item -Path $CertPath -ErrorAction Stop
            Write-Verbose -Message ('Using computer certificate: {0}' -f $Cert.Subject)
            $connectionParams.Certificate = $Cert
        } catch {
            Write-Verbose -Message ('Using user certificate: {0}' -f $CertificateThumbPrint)
            $connectionParams.CertificateThumbprint = $CertificateThumbPrint
        }
    }

    $null = Connect-MgGraph @connectionParams
    $ConnectionInfo = Get-MgContext
    Write-Verbose -Message ('Connected to {0} as: {1}' -f $ConnectionInfo.TenantId, $ConnectionInfo.Account)
}

if ((Get-MgProfile).Name -like 'v1.0') {
    # switch to Beta endpoint
    Select-MgProfile -Name beta
}

$PropertyList = @(
    'assignedLicenses'
    'companyName'
    'department'
    'displayName'
    'id'
    'onPremisesLastSyncDateTime'
    'userPrincipalName'
)

$UserFilter = "accountEnabled eq true and userType eq 'Member'"

if (-not $PassThru.IsPresent) {
    $CsvFileName = $ConnectionInfo.TenantId + '-MFA.csv'
    $CsvProps = @{
        UseCulture        = $true
        Encoding          = 'UTF8'
        NoTypeInformation = $true
        Path              = Join-Path -Path $ReportPath -ChildPath $CsvFileName
        Append            = $true
    }
    if ($PSVersionTable.PSVersion.Major -gt 5) {
        $CsvProps.Encoding = 'utf8BOM'
    }

    Write-Verbose -Message ('Saving Report to: {0}' -f $CsvProps.Path)
    if (Test-Path -Path $CsvProps.Path -PathType Leaf ) {
        Remove-Item -Path $CsvProps.Path
    }
}

Get-MgUser -Filter $UserFilter -Property ($PropertyList -join ',') |
    ForEach-Object {
        $User = $_
        Write-Verbose -Message ('Processing user: {0}' -f $user.DisplayName)
        $UserProps = [ordered] @{}
        switch ($PropertyList) {
            'assignedLicenses' {
                $UserProps.IsLicensed = $User.AssignedLicenses.Count -gt 0
            }
            'id' {}
            default {
                $UserProps.$_ = $User.$_
            }
        }
        $AuthenticationMethod =
            Get-MgReportAuthenticationMethodUserRegistrationDetail -UserRegistrationDetailsId $User.Id

        $UserMfa = @('Disabled', 'Enabled')[$AuthenticationMethod.IsMfaRegistered]
        if ($MfaStatus -in 'All', $UserMfa) {
            $UserProps.MfaStatus = $UserMfa
            $UserProps.MfaList = $AuthenticationMethod.MethodsRegistered -join $MfaListSeparator
            [PSCustomObject] $UserProps
        }
    } |
    ForEach-Object {
        if ($PassThru.IsPresent) {
            $_
        } else {
            $_ | Export-Csv @CsvProps
        }
    }

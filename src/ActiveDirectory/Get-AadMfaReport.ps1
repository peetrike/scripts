#Requires -Version 5.1
#Requires -Modules MSOnline, telia.savedcredential

<#PSScriptInfo
    .VERSION 1.0.3
    .GUID cdcc21f2-2d08-4d7b-9cf3-524ab2781cd8

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2021.  All rights reserved.

    .TAGS Azure, ActiveDirectory, AD, user, MFA, report, PSEdition_Desktop, Windows

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES MSOnline
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
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
        Get-AadMfaReport -Credential admin@my.onmicorosft.com

        Generate MFA report using provided credentials.

    .EXAMPLE
        Get-AadMfaReport -PassThru -MfaStatus Enabled

        Generate MFA report that only included users with Enabled MFA.
        Send the result to standard output, don't generate .csv report.

    .OUTPUTS
        The MFA report entries, if `-PassThru` parameter is used.

    .NOTES
        Script tries to avoid Azure AD Premium license dependency.

    .LINK
        https://docs.microsoft.com/azure/active-directory/authentication/howto-mfa-reporting
#>

[CmdletBinding(
    DefaultParameterSetName='Config'
)]
[OutputType([PSCustomObject])]

param (
        [ValidateNotNull()]
        [PSCredential]
        [Management.Automation.Credential()]
        # Specifies the user account credentials to use when performing this task.
    $Credential,

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
            'Enabled',
            'Enforced'
        )]
        [string]
        # specifies that only users with given MFA status should be returned.
    $MfaStatus = 'All'
)

try {
    $CompanyDetails = Get-MsolCompanyInformation -ErrorAction Stop
} catch {
    if (-not $Credential) {
        $Credential = Get-SavedCredential -FileName (Get-Item $PSCommandPath).BaseName
    }
    if (-not $Credential) {
        $Credential = Get-Credential -Message 'Enter credential for Azure AD Connection' -ErrorAction Stop
    }
    Write-Verbose -Message ('Using credential: {0}' -f $Credential.UserName)
    Connect-MsolService -Credential $Credential -ErrorAction Stop
    $CompanyDetails = Get-MsolCompanyInformation
}

$PropertyList = @(
    'DisplayName'
    'UserPrincipalName'
    'LastDirSyncTime'
    'IsLicensed'
)

Write-Verbose -Message ('Connected to tenant: {0}' -f $CompanyDetails.InitialDomain)
$UserList = Get-MsolUser -EnabledFilter EnabledOnly -All |
    Where-Object UserType -Like 'Member' |
    ForEach-Object {
        $User = $_
        $UserProps = [ordered] @{}
        foreach ($p in $PropertyList) { $UserProps.$p = $User.$p }
        $UserMfa = if ($User.StrongAuthenticationRequirements.State) {
            $User.StrongAuthenticationRequirements.State
        } else { 'Disabled' }
        if ($MfaStatus -in 'All', $UserMfa) {
            $UserProps.MfaStatus = $UserMfa
            $UserProps.DefaultMfa = ($User.StrongAuthenticationMethods | Where-Object IsDefault).MethodType
            $UserProps.OtherMfa = (
                $User.StrongAuthenticationMethods | Where-Object { -not $_.IsDefault }
            ).MethodType -join ','
            [pscustomobject] $UserProps
        }
    }

if ($PassThru.IsPresent) {
    $UserList
} else {
    $CsvFileName = $CompanyDetails.InitialDomain + '-MFA'
    $CsvProps = @{
        UseCulture        = $true
        Encoding          = 'utf8'
        NoTypeInformation = $true
        Path              = Join-Path -Path $ReportPath -ChildPath ($CsvFileName + '.csv')
    }

    Write-Verbose -Message ('Saving Report to: {0}' -f $CsvProps.Path)
    $UserList |
        Export-Csv @CsvProps
}

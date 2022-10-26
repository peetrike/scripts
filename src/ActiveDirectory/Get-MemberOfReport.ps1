#Requires -Version 5
#Requires -Modules ActiveDirectory

<#PSScriptInfo
    .VERSION 0.1.0
    .GUID 2763ebae-f04c-4fa2-8ede-fbbdb4ecdadd

    .AUTHOR CPG4285
    .COMPANYNAME Telia Eesti
    .COPYRIGHT (c) Telia Eesti 2022.  All rights reserved.

    .TAGS ActiveDirectory, AD, group, memberof

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES ActiveDirectory, Microsoft.PowerShell.LocalAccounts
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [0.1.0] - 2022-10-26 - refactor script to generate memberof report.
        [0.0.1] - 2022-10-21 - Initial release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Report groups the AD principal is member of
    .DESCRIPTION
        This script discovers AD principal's group memberships, i.e. the groups
        that appear in user's Access Token.
    .EXAMPLE
        Get-MemberOfReport.ps1 -Identity $env:USERNAME -ReportPath .\report-csv
        This example discovers currently logged on user group membership and saves report to specified file
    .EXAMPLE
        Get-ADUser $env:USERNAME | Get-MemberOfReport.ps1 | Out-GridView
        This example discovers currently logged on user group membership.
        The report is sent to to an interactive table in a separate window.
    .INPUTS
        User Account to use for discovery
    .OUTPUTS
        User account's member of group report
    .NOTES
        When user or any group has SidHistory attribute in AD, that SID is also reported
        (with associated object info).
    .LINK
        https://learn.microsoft.com/dotnet/api/system.security.principal.windowsidentity
#>

[CmdletBinding(
    DefaultParameterSetName = 'Identity'
)]
[OutputType([PSCustomObject])]

param (
        [Parameter(
            Mandatory,
            HelpMessage = 'Enter AD User object identity',
            ParameterSetName = 'Identity'
        )]
        [String]
        # Specifies an Active Directory user object by providing one of the following property values.
        #   * Distinguished Name
        #   * GUID (objectGUID)
        #   * Security Identifier (objectSid)
        #   * SAM account name  (sAMAccountName)
        #   * User Principal Name
    $Identity,
        [Parameter(
            ParameterSetName = 'PipeLine',
            ValueFromPipeline
        )]
        [Microsoft.ActiveDirectory.Management.ADUser]
        # The user account object
    $User,
        [string]
    $ReportPath
)

begin {
    $Domain = Get-ADDomain
    if ($PSCmdlet.ParameterSetName -like 'Identity') {
        $User = Get-ADUser -Identity $Identity
    }
    $CsvProps = @{
        UseCulture        = $true
        NoTypeInformation = $true
        Encoding          = 'UTF8'
    }
    if ($PSVersionTable.PSVersion.Major -gt 5) {
        $CsvProps.Encoding = 'utf8BOM'
    }
}

process {
    $WinIdentity = ([Security.Principal.WindowsIdentity] $User.UserPrincipalName)

    foreach ($Sid in $WinIdentity.Groups) {
        $Group = $Sid.Translate([Security.Principal.NTAccount]).Value
        $ResultProps = @{
            UserPrincipalName = $User.UserPrincipalName
            UserName          = $User.Name
            GroupName         = $Group
            GroupScope        = $null
            GroupType         = $null
            GroupDescription  = $null
            SID               = $Sid
        }
        $namePart = $Group.Split('\')
        switch ($namePart[0]) {
            $Domain.NetBIOSName {
                try {
                    $AdGroup = Get-ADGroup -Identity $namePart[-1] -Properties Description -ErrorAction Stop
                    $ResultProps.GroupScope = $AdGroup.GroupScope
                    $ResultProps.GroupType = $AdGroup.GroupCategory
                    $ResultProps.GroupDescription = $AdGroup.Description
                } catch {
                    $ADObject = Get-ADObject -Filter { SidHistory -like $Sid } -Properties Description
                    $ResultProps.GroupScope = 'SidHistory'
                    $ResultProps.GroupType = $ADObject.ObjectClass
                    $ResultProps.GroupDescription = $AdObject.Description
                }
            }
            $env:COMPUTERNAME {
                $LocalGroup = Get-LocalGroup -Name $namePart[-1]
                $ResultProps.GroupScope = $LocalGroup.PrincipalSource
                $ResultProps.GroupType = 'Security'
                $ResultProps.GroupDescription = $localGroup.Description
            }
        }
        $Result = [PSCustomObject] $ResultProps

        if ($ReportPath) {
            $Result | Export-Csv @CsvProps -Path $ReportPath -Append
        } else { $Result }
    }
}

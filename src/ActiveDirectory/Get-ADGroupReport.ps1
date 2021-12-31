#Requires -Version 3.0
#Requires -Modules ActiveDirectory

<#PSScriptInfo
    .VERSION 1.1.3

    .GUID ac2008ad-6645-45d4-84da-300e6ffdfe5e

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2019.  All rights reserved.

    .TAGS ActiveDirectory, AD, group, report

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://bitbucket.atlassian.teliacompany.net/projects/PWSH/repos/scripts/
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES ActiveDirectory
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.1.3] - 2019.11.01 - Fixed SearchBase and SearchScope
        [1.1.2] - 2019.10.17 - Renamed script
        [1.1.1] - 2019.10.03 - Changed:
            * added e-mail to MemberOf report
            * made Members report generation faster
        [1.1.0] - 2019.10.03 - added -DirectMembers parameter
        [1.0.0] - 2019.07.02 - initial release

    .PRIVATEDATA

#>

<#
    .SYNOPSIS
        Get list of AD group members and group membership based on OU

    .DESCRIPTION
        This script finds all groups in given OU and reports back all group members or all group memberships.
        Group members are resolved from nested groups, unless -DirectMembers parameter is used.
        The result is saved as one .csv file or separate .csv file for each group.

    .EXAMPLE
        PS C:\> Get-ADGroupReport -Filter {Name -like 'one*'} -SearchBase 'OU=Grupid,DC=firma,DC=ee'

        This command finds all groups that have name starting with 'one' in OU Grupid and adds members of those groups into report.

    .EXAMPLE
        PS C:\> Get-ADOrganizationalUnit -Identity 'OU=Grupid,DC=firma,DC=ee' | Get-ADGroupReport -MemberOf

        This command finds all groups from OU Grupid and adds groups that found groups are members of into report.

    .EXAMPLE
        PS C:\> Get-ADGroupReport -DirectMembers

        This command finds all groups in AD domain and generates report of only direct members of each group.

    .EXAMPLE
        PS C:\> Get-ADGroupReport -OutputType Multiple

        This command finds all groups in AD domain and generates report of group members for each group.

    .INPUTS
        System.String

        An Active Directory path to search under.

    .OUTPUTS
        None

    .LINK
        Get-ADGroupMember https://docs.microsoft.com/en-us/powershell/module/activedirectory/get-adgroupmember
        Get-ADPrincipalGroupMembership https://docs.microsoft.com/en-us/powershell/module/activedirectory/get-adprincipalgroupmembership
#>

[CmdLetBinding(
    DefaultParameterSetName = 'Members'
)]
param (
        [parameter(
            HelpMessage = "A filter, such as 'samAccountName -like `"Domain*`"', which is used to search the directory for matching groups."
        )]
        [ValidateNotNullOrEmpty()]
        [string]
        # Specifies a query string that retrieves Active Directory objects.
    $Filter = '*',
        [parameter(
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNull()]
        [Alias('DistinguishedName', 'DN')]
        [string]
        # Specifies an Active Directory path to search under.
    $SearchBase,
        [ValidateNotNullOrEmpty()]
        [Microsoft.ActiveDirectory.Management.ADSearchScope]
        [PSDefaultValue(Help = 'Subtree')]
        # Specifies the scope of an Active Directory search. Possible values are: Base, OneLevel, Subtree
    $SearchScope,
        [parameter(
            Mandatory,
            ParameterSetName = 'MemberOf'
        )]
        [switch]
        # Report AD groups that have searched groups as members
    $MemberOf,
        [parameter(
            ParameterSetName = 'Members'
        )]
        [switch]
        # Report only direct members of group, don't resolve nested groups.
    $DirectMembers,
        [ValidateSet('Single', 'Multiple')]
        [string]
        # Specifies whether to create single report file or separate file for every distribution group. Possible values are: Single, Multiple.
    $OutputType = 'Single'
)

$groupProps = @{
    Filter = $Filter
}

if ($SearchBase) {
    $groupProps.SearchBase = $SearchBase
    $CsvName = (Get-ADOrganizationalUnit $SearchBase).Name
} else {
    $CsvName = (Get-ADDomain).DnsRoot
}

if ($SearchScope) {
    $groupProps.SearchScope = $SearchScope
}

$CsvProps = @{
    UseCulture = $true
    Encoding = 'Default'
    NoTypeInformation = $true
}

$Membership = if ($MemberOf.IsPresent) {
    'memberof'
} else {
    'members'
}

$CsvProps.Path = Join-Path -Path $PWD -ChildPath ('{0}_{1}.csv' -f $CsvName, $Membership)
if ($OutputType -like 'Single') {
    if (Test-Path -Path $CsvProps.Path -PathType Leaf ) {
        Remove-Item -Path $CsvProps.Path
    }
}

$GroupList = Get-ADGroup @groupProps

$Surname = @{
    Name = 'Surname'
    Expression = { $_.sn }
}
$GroupName = @{
    Name = 'GroupName'
    Expression = { $Group.Name }
}

foreach ($Group in $GroupList) {
    Write-Verbose -Message ('Processing group: {0}' -f $Group.Name)

    $MemberProps = @{
        Identity = $Group.objectGUID
    }

    $list = if ($MemberOf.IsPresent) {
        Get-ADPrincipalGroupMembership @MemberProps |
            Get-ADGroup -Properties mail |
            Select-Object -Property Name, SamAccountName, mail, Group*
    } else {
        if (-not $DirectMembers.IsPresent) {
            $MemberProps.Recursive = $true
        }
        Get-ADGroupMember @MemberProps |
            Get-ADObject -Properties GivenName, sn, SamAccountName, UserPrincipalName, mail |
            Select-Object -Property Name, GivenName, $Surname, SamAccountName, UserPrincipalName, mail
    }

    switch ($OutputType) {
        'Single' {
            $list |
                Select-Object -Property $GroupName, * |
                Export-Csv @CsvProps -Append
        }
        'Multiple' {
            $CsvName = '{0}_{1}.csv' -f ($Group.Name.Split([io.path]::GetInvalidFileNameChars()) -join '_'), $Membership
            $CsvProps.Path = Join-Path -Path $PWD -ChildPath $CsvName
            $list | Export-Csv @CsvProps
        }
    }
}

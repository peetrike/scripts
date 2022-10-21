#Requires -Version 3
#Requires -Modules ActiveDirectory

<#PSScriptInfo
    .VERSION 0.0.1
    .GUID 2763ebae-f04c-4fa2-8ede-fbbdb4ecdadd

    .AUTHOR CPG4285
    .COMPANYNAME Telia Eesti
    .COPYRIGHT (c) Telia Eesti 2022.  All rights reserved.

    .TAGS ActiveDirectory, AD, group, memberof

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES ActiveDirectory
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [0.0.1] - 2022-10-21 - Initial release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Find groups the AD principal is member of

    .DESCRIPTION
        This script discovers AD principal's group memberships, i.e. the groups
        that contain provided principal as member.

    .EXAMPLE
        Get-ADUser $env:USERNAME | Get-MemberOf.ps1 -Level 2
        This example discovers currently logged on user group membership for 2 levels of nesting
    .INPUTS
        AD principal to use for discovery
    .OUTPUTS
        List of groups
    .LINK
        https://learn.microsoft.com/powershell/module/activedirectory/get-adprincipalgroupmembership
#>

[CmdletBinding(
    DefaultParameterSetName = 'Parameter Set 1'
)]
#[Alias('')]
[OutputType([Microsoft.ActiveDirectory.Management.ADGroup])]

param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [Microsoft.ActiveDirectory.Management.ADObject]
        # AD principal to start discovery
    $AdPrincipal,

        [Parameter(ParameterSetName = 'Parameter Set 1')]
        [int]
        # number of levels to look for
    $Level = 1,
        [bool]
        # specifies, that returned list should only have unique groups
    $Unique = $true
)

begin {
    function GroupMembership {
        [CmdletBinding()]
        param (
                [Parameter(
                    Mandatory = $true,
                    ValueFromPipeline = $true
                )]
                [Microsoft.ActiveDirectory.Management.ADObject]
            $AdPrincipal,

                [Parameter(ParameterSetName = 'Parameter Set 1')]
                [int]
                # Param2 help description
            $Level = 1
        )
        process {
            $AdPrincipal

            if ($level -ne 0) {
                Write-Verbose -Message ('Processing principal: {0}' -f $AdPrincipal.Name)
                Get-ADPrincipalGroupMembership $AdPrincipal |
                    GroupMembership -level ($Level - 1)
            }
        }
    }
}

process {
    $result = $AdPrincipal | GroupMembership -Level $Level | Select-Object -Skip 1
    if ($Level -eq 1) { $Unique = $false }

    if ($Unique) {
        $result | Sort-Object -Unique
    } else {
        $result
    }
}

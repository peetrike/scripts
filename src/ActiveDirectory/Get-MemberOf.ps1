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
        Short description

    .DESCRIPTION
        Find groups the account is member of

    .EXAMPLE
        Get-MemberOf.ps1 -Param1 'Done'
        Explanation of what the example does
    .INPUTS
        Inputs (if any)
    .OUTPUTS
        List of groups
    .NOTES
        General notes
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
        [Alias("p1")]
        [Microsoft.ActiveDirectory.Management.ADObject]
        # Param1 help description
    $AdPrincipal,

        [Parameter(ParameterSetName = 'Parameter Set 1')]
        [int]
        # Param2 help description
    $Level = 1,
        [bool]
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

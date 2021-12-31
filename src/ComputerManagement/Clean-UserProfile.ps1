#Requires -Version 3.0
#Requires -Modules UserProfile

<#PSScriptInfo
    .VERSION 2.0.2
    .GUID cba62666-c56b-4cb7-b5f7-b8f696482688

    .AUTHOR CPG4285
    .COMPANYNAME Telia Eesti
    .COPYRIGHT (c) Telia Eesti 2021.  All rights reserved.

    .TAGS user, profile, cleanup

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES UserProfile
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [2.0.2] - 2021.12.31 - Moved script to Github
        [2.0.1] - 2021-07-16 - Fixed unknown local user discovery
        [2.0.0] - 2021-07-16 - Changed:
            - Replace -LocalOnly with -Target
            - Use ADSI instead of ActiveDirectory module
            - Fix local user discovery and disabled check
        [1.0.0] - 2021-07-16 - First public release
        [0.0.1] - 2021-07-15 - Initial release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Cleanup User Profiles that can't be used.
    .DESCRIPTION
        This script deletes User Profiles for unknown or disabled accounts.
        It only discovers user profiles that are not loaded and that are owned
        by (former) local or domain accounts.
    .EXAMPLE
        Clean-UserProfile.ps1 -IncludeDisabled

        Cleans up profiles for both unknown and disabled users.
    .EXAMPLE
        Clean-UserProfile.ps1 -Target Local

        Cleans up profiles for local users only.
    .INPUTS
        None
    .OUTPUTS
        None
    .NOTES
        For cleaning up domain accounts You need to be logged on as domain user.
    .LINK
        Get-UserProfile
#>

[CmdletBinding(
    SupportsShouldProcess
)]

param (
        [switch]
        # Include disabled user accounts to profile cleanup.
    $IncludeDisabled,
        [ValidateSet('Domain', 'Local')]
        [string[]]
        # Target user accounts: Domain or Local.  By default, both are included.
    $Target = @('Domain', 'Local')
)

$CimProps = @{
    ErrorAction = [Management.Automation.ActionPreference]::Stop
    Verbose     = $false
    ClassName   = 'Win32_UserAccount'
}

$DomainSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.AccountDomainSid
$SidString = (Get-CimInstance Win32_UserAccount -Filter 'LocalAccount=true' -Verbose:$false)[0].SID
$ComputerSid = ([Security.Principal.SecurityIdentifier]$SidString).AccountDomainSid
if ($DomainSid -eq $ComputerSid) {
    $Target = 'Local'
}

Get-UserProfile -Loaded $false | ForEach-Object {
    $UserProfile = $_
    $UserSid = [Security.Principal.SecurityIdentifier]($UserProfile.SID)

    $Result = switch ($UserSid.AccountDomainSid) {
        $ComputerSid {
            if ($Target -contains 'Local') {
                Write-Verbose -Message ('Processing local user profile: {0}' -f $UserProfile.LocalPath)
                $CimProps.Filter = 'LocalAccount=True and SID="{0}"' -f $UserProfile.SID
                $User = Get-CimInstance @CimProps
                if (-not $User) {
                    Write-Verbose -Message ('Unknown account: {0}' -f $UserProfile.SID)
                    $UserProfile
                } elseif ($User.Disabled -and $IncludeDisabled.IsPresent) {
                    Write-Verbose -Message ('Disabled account: {0}' -f $User.Name)
                    $UserProfile
                }
            }
        }
        $DomainSid {
            if ($Target -contains 'Domain') {
                Write-Verbose -Message ('Processing domain user profile: {0}' -f $UserProfile.LocalPath)
                $DirectorySearcher = New-Object DirectoryServices.DirectorySearcher -ArgumentList (
                    ('(objectSid={0})' -f $UserProfile.SID),     # LDAP Filter
                    @( 'name', 'userAccountControl')             # Properties to load
                )
                $User = $DirectorySearcher.FindAll().Properties
                if (-not $User) {
                    Write-Verbose -Message ('Unknown account: {0}' -f $UserProfile.SID)
                    $UserProfile
                } elseif (
                    (2 -band ($User.useraccountcontrol[0])) -and
                    $IncludeDisabled.IsPresent
                ) {
                    Write-Verbose -Message ('Disabled account: {0}' -f $User.name[0])
                    $UserProfile
                }
            }
        }
    }
    if ($Result -and $PSCmdlet.ShouldProcess($Result.LocalPath, 'Remove user profile')) {
        Remove-UserProfile -InputObject $Result -Confirm:$false -WhatIf:$false
    }
}

#Requires -Modules UserProfile

<#PSScriptInfo
    .VERSION 0.0.1
    .GUID 2b1ce67a-2d66-42bb-bf06-cea1db933ac1

    .AUTHOR Peter Wawa
    .COMPANYNAME Telia Eesti
    .COPYRIGHT (c) Telia Eesti 2022.  All rights reserved.

    .TAGS user, profile, cleanup

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES UserProfile
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [0.0.1] - 2022-03-04 - Initial release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Clear old user profiles

    .DESCRIPTION
        Cleanup old user profiles

    .EXAMPLE
        Clean-OldProfile.ps1 -Days 40

        Find user profiles that are more than 40 days old and remove them
    .INPUTS
        This script has no input

    .OUTPUTS
        Output (if any)

    .NOTES
        General notes

    .LINK
        Win32_UserProfile class: https://docs.microsoft.com/previous-versions/windows/desktop/usm/win32-userprofile
#>

[CmdletBinding(
    SupportsShouldProcess = $true
)]
param (
        [int]
        # User profile age in days to be deleted
    $Days = 30,
        [switch]
        # remove also corrupted profiles
    $RemoveCorrupted,
        [switch]
        # remove also temporary profiles
    $RemoveTemporary
)

$BeforeDate = (get-date).AddDays(-$days)
Get-UserProfile -Before $BeforeDate | Remove-UserProfile

if ($RemoveCorrupted.IsPresent) {
    Get-UserProfile -Status Corrupted -ErrorAction Ignore | Remove-UserProfile
}

if ($RemoveTemporary.IsPresent) {
    Get-UserProfile -Status Temporary -Loaded $false -ErrorAction Ignore | Remove-UserProfile
}

#Requires -Version 4
#Requires -Modules UserProfile, Storage
#Requires -RunAsAdministrator

<#PSScriptInfo
    .VERSION 0.0.1
    .GUID 28f51784-0595-4645-a485-88a40cb1c684

    .AUTHOR Peter Wawa
    .COPYRIGHT (c) Peter Wawa 2025.  All rights reserved.

    .TAGS

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES Storage
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [0.0.1] - 2025-01-22 - Initial release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Dismount unloaded user profile disks
    .DESCRIPTION
        This script will dismount unloaded user profile disks.
    .EXAMPLE
        Dismount-Upd.ps1

        This example dismounts all unloaded user profile disks.
    .INPUTS
        None
    .OUTPUTS
        Microsoft.Management.Infrastructure.CimInstance#ROOT/Microsoft/Windows/Storage/MSFT_DiskImage
        The dismounted disk images
    .NOTES

    .LINK
        https://learn.microsoft.com/powershell/module/storage/dismount-diskimage
#>

[CmdletBinding(
    SupportsShouldProcess
)]
param (
        [ValidateScript({
            if (Test-Path -Path $_) {
                $true
            } else {
                throw 'Path not found'
            }
        })]
        [string[]]
    $Path
)

$PathList = if ($Path) {
    (Resolve-Path -Path $Path).Path
} else {
    (Get-UserProfile -Special $false -Loaded $false -ErrorAction SilentlyContinue).LocalPath
}

$PathList | ForEach-Object {
    $VolumeName = (mountvol.exe $_ /L).Trim().TrimEnd('\')
    if ($VolumeName -like '\\*' -and $PSCmdlet.ShouldProcess($_, 'Dismount UPD')) {
            # The Dismount-DiskImage does not honor the ShouldProcess parameters
        Dismount-DiskImage -DevicePath $VolumeName
    }
}

#Requires -Version 3
#Requires -Modules UserProfile

<#PSScriptInfo
    .VERSION 0.0.1
    .GUID 21dd32f4-ce38-4288-a8ee-5cf490face48

    .AUTHOR CPG4285
    .COMPANYNAME Telia Eesti
    .COPYRIGHT (c) Telia Eesti 2022.  All rights reserved.

    .TAGS user, profile, temp, cleanup

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES UserProfile
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [0.0.1] - 2022-06-06 - Initial release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Cleanup user profile temp folders.
    .DESCRIPTION
        This script cleans up temp folders in user profiles.  It looks
        for user profiles that are not loaded and then clears temp folders.

        Cleaning currently logged on users is not good idea, as there might be
        running applications that use files in temp folder.
    .EXAMPLE
        Clean-UserTemp.ps1 -CurrentUser

        This example cleans temporary files folder for currently logged on user only.
    .EXAMPLE
        UserTemp.ps1 -IncludeSystemTemp

        This example cleans up not logged on user's temporary folders and also
        system temporary files folder.
#>

[CmdletBinding(
    SupportsShouldProcess
)]
param (
        [switch]
        # Check only currently logged on user
    $CurrentUser,
        [switch]
        # Cleanup also system temp folder.  Requires admin permissions.
    $IncludeSystemTemp,
        [switch]
        # Forces the script to remove items that cannot otherwise be changed, such as hidden or read-only files.
    $Force
)

$WorkItemList = if ($CurrentUser.IsPresent) {
    Write-Warning -Message 'There might be temporary files, that are currently used'
    $env:USERPROFILE
} else {
    Get-UserProfile -Loaded $false -Special $false | Select-Object -ExpandProperty LocalPath
}

$CleanParams = @{
    Recurse = $true
}
if ($Force.IsPresent) {
    $CleanParams.Force = $true
}

foreach ($ProfilePath in $WorkItemList) {
    $UserTempPath = Join-Path -Path $ProfilePath -ChildPath 'Appdata/Local/Temp'
    Write-Verbose -Message ('Cleaning up folder {0}' -f $UserTempPath)
    if (Test-Path -Path $UserTempPath) {
        $TempPath = Join-Path -Path $UserTempPath -ChildPath '*'
        Remove-Item -Path $TempPath @CleanParams
    } else {
        Write-Verbose -Message ('No temporary files folder for user profile {0}' -f $ProfilePath)
    }
}

if ($IncludeSystemTemp.IsPresent) {
    $SystemTemp = [Environment]::GetEnvironmentVariable('temp', [EnvironmentVariableTarget]::Machine)
    Write-Verbose -Message ('Cleaning up System temp folder: {0}' -f $SystemTemp)
    Write-Warning -Message 'There might be temporary files, that are currently used'
    $TempPath = Join-Path -Path $SystemTemp -ChildPath '*'
    Remove-Item -Path $TempPath @CleanParams
}

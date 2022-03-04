#Requires -Version 3
#Requires -Modules UserProfile

<#PSScriptInfo
    .VERSION 0.0.2
    .GUID b6a150a7-ca36-460f-aca2-7592fc728f58

    .AUTHOR CPG4285
    .COMPANYNAME Telia Eesti
    .COPYRIGHT (c) Telia Eesti 2021.  All rights reserved.

    .TAGS user, profile, browser, cache, cleanup

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES UserProfile
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [0.0.2] - 2021.12.31 - Moved script to Github
        [0.0.1] - 2021-09-08 - Initial release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Cleanup browser cache folders.
    .DESCRIPTION
        This script Cleans up browser cache folders in user profiles.  It looks
        for user profiles that are not loaded and then clears provided browser
        cache locations.

        When cleaning currently logged on user only, then browser applications
        must be turned off before running this script.
    .EXAMPLE
        Clean-BrowserCache.ps1 -CurrentUserOnly

        Cleanups browser cache folders for currently logged on user only.
    .EXAMPLE
        Clean-BrowserCache.ps1 -Browser Chrome, Edge

        Cleanups browser cache folders for all users not currently logged on.
        Only Google Chrome and Microsoft Edge browsers are affected.
#>

[CmdletBinding(
    SupportsShouldProcess
)]
param (
        [Parameter(
            Position = 0
        )]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('All', 'Chrome', 'Edge', 'Firefox', 'IE')]
        [string[]]
        # Specify browsers to process
    $Browser = 'All',
        [switch]
        # Check only currently logged on user
    $CurrentUserOnly
)

if ($Browser -like 'All') {
    $Browser = 'Chrome', 'Firefox', 'Edge' #, 'IE'
}
$BrowserList = @{
    Chrome  = @{
        BasePath    = 'Google/Chrome/User Data'
        ProfilePath = 'Default', 'Profile*'
        ClearPath   = 'Cache'
    }
    Edge    = @{
        BasePath    = 'Microsoft/Edge/User Data'
        ProfilePath = 'Default', 'Profile*'
        ClearPath   = 'Cache'
    }
    FireFox = @{
        BasePath    = 'Mozilla/Firefox/Profiles'
        ProfilePath = '*.default*'
        ClearPath   = 'Cache', 'Cache2/entries', 'OfflineCache'
    }
    IE      = @{
        BasePath    = 'Microsoft'
        ProfilePath = 'Windows'
        ClearPath   = @(
            'Temporary Internet Files'
            'Caches'
            'INetCache'                 # Windows Apps Cache (IE, Word etc)
            'WebCache'
        )
    }
}

$WorkItemList = if ($CurrentUserOnly.IsPresent) {
    Write-Warning -Message 'Cleaned up browsers should be turned off before running ths script'
    $env:USERPROFILE
} else {
    Get-UserProfile -Loaded $false -Special $false | Select-Object -ExpandProperty LocalPath
}

foreach ($ProfilePath in $WorkItemList) {
    Write-Verbose -Message ('Cleaning up user {0}' -f (Split-Path -Path $ProfilePath -Leaf))
    $LocalAppDataPath = Join-Path -Path $ProfilePath -ChildPath 'Appdata/Local'
    foreach ($item in $Browser) {
        $BrowserItem = $BrowserList.$item
        $BrowserBasePath = Join-Path -Path $LocalAppDataPath -ChildPath $BrowserItem.BasePath
        if (Test-Path -Path $BrowserBasePath -ErrorAction SilentlyContinue) {
            foreach ($folder in $BrowserItem.ProfilePath) {
                Get-ChildItem -Path $BrowserBasePath -Directory -Filter $folder | ForEach-Object {
                    $BrowserProfilePath = $_.FullName
                    foreach ($subfolder in $BrowserItem.ClearPath) {
                        $TargetFolder = Join-Path -Path $BrowserProfilePath -ChildPath $subfolder
                        if (Test-Path $TargetFolder -PathType Container) {
                            Write-Verbose -Message ('Cleaning up folder {0}' -f $TargetFolder)
                            Get-ChildItem -Path $TargetFolder -Filter * -ErrorAction SilentlyContinue |
                                Remove-Item -Recurse -Force
                        }
                    }
                }
            }
        } else {
            Write-Verbose -Message ('No data for browser {0}' -f $item)
        }
    }
}

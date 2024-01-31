#Requires -Version 2.0

<#PSScriptInfo
    .VERSION 1.0.0
    .GUID 607b2df9-5615-4d42-a76e-f816d1782552

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2021.  All rights reserved.

    .TAGS environment, variable, PSEditon_Desktop, PSEdition_Core, Windows

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.0.0] - 2024.01.30 - Initial Release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Retrieves environment variable that contains list of paths
    .DESCRIPTION
        This script gets environment variable content, that has value like
        Path environment variable.

        The value is taken from registry, if possible.  That allows obtaining
        non-expanded values.
    .EXAMPLE
        Get-PathVar -Target Machine

        This example gets variable Path value for Machine environment target.
    .EXAMPLE
        Get-PathVar -Variable PSModulePath

        This example gets variable PSModulePath from User target.
    .NOTES
    .LINK
        https://learn.microsoft.com/dotnet/api/microsoft.win32.registrykey.getvalue
#>

[CmdletBinding()]
param (
        [Alias('Name')]
        [string]
        # Specifies variable name to change
    $Variable = 'Path',

        [EnvironmentVariableTarget]
        # Specifies the location where an environment variable is located
    $Target = [EnvironmentVariableTarget]::User
)

$PathSeparator = [IO.Path]::PathSeparator

if ($Target) {
    $BaseKey = if ($Target -eq [EnvironmentVariableTarget]::Machine) {
        'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
    } else { 'HKCU:\' }
    $key = (Get-Item $BaseKey).OpenSubKey('Environment', $false)
    $key.GetValue($Variable, '', 'DoNotExpandEnvironmentNames').Split($PathSeparator)
} else {
    [Environment]::GetEnvironmentVariable($Variable, $Target).Split($PathSeparator)
}

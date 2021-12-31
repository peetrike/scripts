#Requires -Version 2.0

<#PSScriptInfo
    .VERSION 1.0.0
    .GUID 0391ff58-893b-4d0b-949b-3a1e32fdfa75

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2021.  All rights reserved.

    .TAGS environment, variable, PSEditon_Desktop, PSEdition_Core, Windows

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.0.0] - 2021.01.08 - remove redundant verbose message
        [0.0.3] - 2021.01.08 - fix problem when variable contains only 1 path
        [0.0.2] - 2021.01.07 - Refactor script
            Add default value (Path) to -Variable
            Ensure that all path values are unique
        [0.0.1] - 2021.01.07 - Initial Release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Change environment variable that contains list of paths

    .DESCRIPTION
        This script changes environment variable content, that has value like
        Path environment variable.

        The specific path can be added or removed.  When adding, the new path
        can be added before or after existing list of paths.

    .EXAMPLE
        Set-PathVar -Value 'c:\path' -Target Machine

        This example adds new path 'c:\path' after existing variable Path value.
        The variable value is taken from Machine target.

    .EXAMPLE
        Set-PathVar -Variable PSModulePath -Value 'c:\path' -Operation Remove

        This example removes path 'c:\path' from variable PSModulePath.

    .NOTES
        Setting variable with Target Machine requires admin privileges.
        If added path already exists, then it will be moved to beginning or end of path list.

    .LINK
        https://docs.microsoft.com/dotnet/api/system.environment.setenvironmentvariable
#>

[CmdletBinding(
    SupportsShouldProcess=$true
)]

param (
        [Alias('Name')]
        [string]
        # Specifies variable name to change
    $Variable = 'Path',

        [Parameter(
            Mandatory = $true
        )]
        [string]
        # Specifies value to add or remove
    $Value,

        [EnvironmentVariableTarget]
        # Specifies the location where an environment variable is located
    $Target = [EnvironmentVariableTarget]::User,

        [ValidateSet('Add', 'Remove')]
        [string]
        # Specifies operation to perform: Add, Remove
    $Operation = 'Add',
        [Alias('Prepend')]
        [switch]
        # Specifies, that added path should be located before existing values.
    $Before
)

function Test-IsAdmin {
    $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Role = [Security.Principal.WindowsBuiltinRole]::Administrator
    ([Security.Principal.WindowsPrincipal] $CurrentUser).IsInRole($Role)
}

$PathSeparator = [IO.Path]::PathSeparator
[object[]]$OldList = [environment]::GetEnvironmentVariable($Variable, $Target ) -split $PathSeparator |
    Where-Object { $_ -and ($_ -ne $Value) } |
    Select-Object -Unique

if ($Operation -like 'Add') {
        $NewList = if ($Before.IsPresent) {
            $Value, $OldList | ForEach-Object { $_ }
        } else {
            $OldList + $Value
        }
} else {
    $NewList = $OldList # | Where-Object { $_ -ne $Value }
}

$NewValue = $NewList -join $PathSeparator
Write-Verbose -Message ('New value: {0}' -f $NewValue)

if ($PSCmdlet.ShouldProcess($Variable, ('Modify Environment variable: operation - {0}') -f $Operation)) {
    if (($Target -eq [EnvironmentVariableTarget]::Machine) -and -not (Test-IsAdmin)) {
        throw (New-Object -TypeName System.Management.Automation.PSSecurityException -ArgumentList 'Admin Privileges required')
    }
    [Environment]::SetEnvironmentVariable($Variable, $NewValue, $Target)
}

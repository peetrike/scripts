#Requires -Version 2.0

<#PSScriptInfo
    .VERSION 2.1.1
    .GUID 0391ff58-893b-4d0b-949b-3a1e32fdfa75

    .AUTHOR Peter Wawa
    .COPYRIGHT (c) Peter Wawa 2024.  All rights reserved.

    .TAGS environment variable PSEdition_Desktop PSEdition_Core Windows

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [2.1.1] - 2025.11.03 - Remove redundant assignment.
        [2.1.0] - 2024.06.25 - Remove compressing paths.
        [2.0.1] - 2024.06.25 - Fix finding registry path.
        [2.0.0] - 2024.01.30 - Script now uses registry and non-expanded strings.
            It also converts full paths to expand-strings, when possible.
        [1.0.1] - 2021.12.31 - Moved script to Github
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
    .LINK

#>

[CmdletBinding(
    SupportsShouldProcess = $true
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

if (($Target -eq [EnvironmentVariableTarget]::Machine) -and -not (Test-IsAdmin)) {
    throw [Management.Automation.PSSecurityException] 'Admin Privileges required'
}
$PathSeparator = [IO.Path]::PathSeparator

[object[]]$OldList = if ($Target) {
    $BaseKey = switch ($Target) {
        'Machine' { 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' }
        'User' { 'HKCU:\' }
    }
    $key = (Get-Item $BaseKey).OpenSubKey('Environment', $true)

    $key.GetValue($Variable, '', 'DoNotExpandEnvironmentNames').Split($PathSeparator) |
        Where-Object { $_ -and ($_ -ne $Value) } |
        Select-Object -Unique
} else {
        # Process scope
    [Environment]::GetEnvironmentVariable($Variable, $Target).Split($PathSeparator) |
        Where-Object { $_ -and ($_ -ne $Value) } |
        Select-Object -Unique
}

if ($Operation -like 'Add') {
    $NewList = if ($Before) {
        $Value, $OldList | ForEach-Object { $_ }
    } else {
        $OldList + $Value
    }
} else {
    $NewList = $OldList
}

$NewValue = $NewList -join $PathSeparator
Write-Verbose -Message ('New value: {0}' -f $NewValue)

if ($PSCmdlet.ShouldProcess($Variable, ('Modify Environment variable: operation - {0}') -f $Operation)) {
    if ($Target) {
        $key.SetValue($Variable, $NewValue, [Microsoft.Win32.RegistryValueKind]::ExpandString)
    } else {
        [Environment]::SetEnvironmentVariable($Variable, $NewValue, $Target)
    }
}

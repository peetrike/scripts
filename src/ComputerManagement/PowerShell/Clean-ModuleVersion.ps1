#Requires -Version 3

<#PSScriptInfo

    .VERSION 1.1.0
    .GUID ae7932ba-f838-4a6b-b66e-0f30039683a3

    .AUTHOR CPG4285
    .COMPANYNAME !ZUM!
    .COPYRIGHT (c) 2023 Peter Wawa.  All rights reserved.

    .TAGS powershell module cleanup

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES PowerShellGet
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.1.0] - 2023.05.13 - Update modules location discovery
        [1.0.0] - 2023.01.16 - Initial release

    .PRIVATEDATA

#>

<#
    .SYNOPSIS
        Remove old installed module versions.
    .DESCRIPTION
        This script cleans up installed module versions, so that only desired number of versions is kept.
#>

[CmdletBinding(
    SupportsShouldProcess
)]
param (
        [Parameter(
            Position = 1
        )]
        [string]
        [SupportsWildcards()]
        # Specifies module name to search
    $Name,
        [ValidateSet('AllUsers', 'CurrentUser')]
        [string]
    $Scope,
        [ValidateRange(1, 10)]
        [int]
        # Number of versions to keep
    $VersionCount
)

function Clean-ModuleVersion {
    [CmdletBinding(
        SupportsShouldProcess
    )]
    param (
            [Parameter(
                Position = 1
            )]
            [string]
            [SupportsWildcards()]
            # Specifies module name to search
        $Name = '*',
            [ValidateSet('AllUsers', 'CurrentUser')]
            [string]
        $Scope = 'AllUsers',
            [ValidateRange(1, 10)]
            [int]
            # Number of versions to keep
        $VersionCount = 2
    )

    $PSVersionName = 'PowerShell'
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        $PSVersionName = 'Windows' + $PSVersionName
    }
    $SearchPattern = switch ($Scope) {
        'AllUsers' { '{0}\' -f $env:ProgramFiles }
        'CurrentUser' { '{0}*' -f $env:USERPROFILE }
    }
    $ModulePath = $env:PSModulePath -split [IO.Path]::PathSeparator | Where-Object {
        $_ -like ('{0}{1}\Modules' -f $SearchPattern, $PSVersionName)
    }
    $SearchPath = Join-Path -Path $ModulePath -ChildPath $Name

    Get-ChildItem -Path $SearchPath -Include * -Directory |
        Group-Object { $_.Parent.Name } |
        Where-Object Count -GT $VersionCount |
        ForEach-Object {
            $ModuleName = $_.Name
            Write-Verbose -Message ('Processing module: {0}' -f $ModuleName)
            $DeleteList = $_.Group |
                Sort-Object { [version] $_.Name } -Descending |
                Select-Object -Skip $VersionCount
            foreach ($folder in $DeleteList) {
                $Message = 'Remove module "{0}" version' -f $ModuleName
                if ($PSCmdlet.ShouldProcess($folder.Name, $Message)) {
                    Remove-Item $folder -Recurse -Force -Confirm:$false
                }
            }
        }
}

Clean-ModuleVersion @PSBoundParameters

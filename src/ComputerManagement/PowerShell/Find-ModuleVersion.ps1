#Requires -Version 3

<#
    .SYNOPSIS
        Find local modules that have too many versions on disk
    .DESCRIPTION
        This script searches installed modules that have too many versions on disk.
#>

[CmdletBinding()]
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
    $VersionCount
)

function Find-ModuleVersion {
    [CmdletBinding()]
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
        Group-Object { $_.Parent.Name } -NoElement |
        Where-Object Count -GT $VersionCount
}

Find-ModuleVersion @PSBoundParameters

#Requires -Version 3
#Requires -Modules @{ModuleName = 'PowerShellGet'; MaximumVersion = 2.99}

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
    $Name = '*',
        [ValidateSet('AllUsers', 'CurrentUser')]
        [string]
    $Scope = 'AllUsers',
        [ValidateRange(1, 10)]
        [int]
    $VersionCount = 2
)

$PathName = $Scope + 'Modules'

$ModulePath = $PSGetPath.$PathName
$SearchPath = Join-Path -Path $ModulePath -ChildPath $Name

Get-ChildItem -Path $SearchPath -Include * -Directory |
    Group-Object { $_.Parent.Name } -NoElement |
    Where-Object Count -GT $VersionCount

<#
    .DESCRIPTION
        This script reports the various .NET Framework versions installed on the local computer.
    .NOTES
        Author      : Martin Schvartzman
        Modified by : Peter Wawa
    .LINK
        https://docs.microsoft.com/dotnet/framework/migration-guide/how-to-determine-which-versions-are-installed
#>

[CmdletBinding()]
param (
        [ValidateRange(1, 4)]
        [int[]]
        # Main version of .NET Framework to be included in response
    $Generation = @(4, 3, 2),
        [ValidateSet('Client', 'Full')]
        [string]
        # .NET 4.0 profile to be reported
    $Type = 'Full'
)

Function Get-NetFrameworkVersion {
    [CmdletBinding()]
    param (
            [ValidateRange(1, 4)]
            [int[]]
        $Generation = @(4, 3, 2),
            [ValidateSet('Client', 'Full')]
            [string]
        $Type = 'Full'
    )

    $dotNetRegistry = 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP'
    $dotNet4Registry = Join-Path -Path $dotNetRegistry -ChildPath 'v4'
    $InstalledComponents = 'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components'

    $dotNet4Builds = @{
        '30319'  = @{ Version = [Version]'4.0' }
        '378389' = @{ Version = [Version]'4.5' }
        '378675' = @{ Version = [Version]'4.5.1' ; Comment = '(8.1/2012R2)' }
        '378758' = @{ Version = [Version]'4.5.1' ; Comment = '(8/7 SP1/Vista SP2)' }
        '379893' = @{ Version = [Version]'4.5.2' }
        '380042' = @{ Version = [Version]'4.5'   ; Comment = 'and later with KB3168275 rollup' }
        '393295' = @{ Version = [Version]'4.6'   ; Comment = '(Windows 10)' }
        '393297' = @{ Version = [Version]'4.6'   ; Comment = '(NON Windows 10)' }
        '394254' = @{ Version = [Version]'4.6.1' ; Comment = '(Windows 10 1511)' }
        '394271' = @{ Version = [Version]'4.6.1' ; Comment = '(NON Windows 10 1511)' }
        '394802' = @{ Version = [Version]'4.6.2' ; Comment = '(Windows 10 1607/Srv16)' }
        '394806' = @{ Version = [Version]'4.6.2' ; Comment = '(NON Windows 10 1607/Srv16)' }
        '460798' = @{ Version = [Version]'4.7'   ; Comment = '(Windows 10 1703)' }
        '460805' = @{ Version = [Version]'4.7'   ; Comment = '(NON Windows 10 1703)' }
        '461308' = @{ Version = [Version]'4.7.1' ; Comment = '(Windows 10 1709)' }
        '461310' = @{ Version = [Version]'4.7.1' ; Comment = '(NON Windows 10 1709)' }
        '461808' = @{ Version = [Version]'4.7.2' ; Comment = '(Windows 10 1803)' }
        '461814' = @{ Version = [Version]'4.7.2' ; Comment = '(NON Windows 10 1803)' }
        '528040' = @{ Version = [Version]'4.8.0' ; Comment = '(Windows 10 1903/1909)' }
        '528049' = @{ Version = [Version]'4.8.0' ; Comment = '(Non Windows 10 1903 or newer)' }
        '528372' = @{ Version = [Version]'4.8.0' ; Comment = '(Windows 10 2004 or newer)' }
        '528449' = @{ Version = [Version]'4.8.0' ; Comment = '(Windows 11 / Server 2022)' }
    }
    $dotNet1Builds = @{
        '{78705f0d-e8db-4b2d-8193-982bdda15ecd}' = 'on supported platforms except for Windows XP Media Center and Tablet PC'
        '{FDC11A6F-17D1-48f9-9EA3-9051954BAA24}' = 'shipped with Windows XP Media Center 2002/2004 and Tablet PC 2004'
    }

    foreach ($g in $Generation) {
        switch ($g) {
            4 {
                Get-ChildItem -Path $dotNet4Registry |
                    Where-Object { $_.PSChildName -Like $Type } |
                    Get-ItemProperty |
                    ForEach-Object {
                        $Release = $_.Release
                        if (-not $Release) {
                            $Release = 30319
                        }
                        New-Object -TypeName PSObject -Property @{
                            #Type = $_.PSChildName
                            Version = $dotNet4Builds["$Release"].Version
                            Build   = $Release
                            SP      = ''
                            Comment = $dotNet4Builds["$Release"].Comment
                        }
                    }
            }
            1 {
                $version = 'v1.1.4322'
                $dotNet1Registry = Join-Path -Path $dotNetRegistry -ChildPath $version
                if (Test-Path -Path $dotNet1Registry) {
                    $version = [version] $version
                    New-Object -TypeName PSObject -Property @{
                        Version = $version
                        Build   = $version.Build
                    }
                } else {
                    foreach ($component in $dotNet1Builds.Keys) {
                        $dotNet1Registry = Join-Path -Path $InstalledComponents -ChildPath $component
                        if (Test-Path $dotNet1Registry -PathType Container) {
                            $DotNet1Key = Get-ItemProperty -Path $dotNet1Registry
                            $version = [version] $DotNet1Key.Version.Replace(',', '.')
                            New-Object -TypeName PSObject -Property @{
                                Version = $version
                                Build   = $version.Build
                                SP      = 'SP{0}' -f $version.Revision
                                Comment = $dotNet1Builds.$component
                            }
                        }
                    }
                }
            }
            Default {
                Get-ChildItem -Path $dotNetRegistry |
                    Where-Object { $_.PSChildName -like "v[$g]*" } |
                    Get-ItemProperty |
                    ForEach-Object {
                        $version = [version] $_.Version
                        New-Object -TypeName PSObject -Property @{
                            Version = $version
                            Build   = $version.Build
                            SP      = $_.SP
                        }
                    }
            }
        }
    }
}

Get-NETFrameworkVersion @PSBoundParameters

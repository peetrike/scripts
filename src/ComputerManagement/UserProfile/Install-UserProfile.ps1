#Requires -Version 5.1
#Requires -Modules PackageManagement
#Requires -RunAsAdministrator

<#PSScriptInfo
    .VERSION 0.0.1
    .GUID 46c07847-9579-4a58-bb1e-e5b5ad8f7967

    .AUTHOR Peter Wawa
    .COMPANYNAME Telia Eesti
    .COPYRIGHT (c) Telia Eesti 2022.  All rights reserved.

    .TAGS user, profile

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [0.0.1] - 2022-03-04 - Initial release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Installs UserProfile module, if needed

    .DESCRIPTION
        Installs UserProfile module and updates PowerShellGet module, if needed

    .EXAMPLE
        Install-UserProfile.ps1

        This example installs module, if needed
    .INPUTS
        This script takes no input

    .OUTPUTS
        Output (if any)
#>

[CmdletBinding()]
#[Alias('')]
[OutputType([void])]

param ()

if (Get-Module UserProfile -ListAvailable) {
    Write-Verbose -Message 'Module already installed'
} else {
        # add TLS 1.2 support, if needed
    if (-not ([Net.ServicePointManager]::SecurityProtocol -band [Net.SecurityProtocolType]::Tls12)) {
        [Net.ServicePointManager]::SecurityProtocol =
            [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    }

    try {
        Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction Stop
    } catch {
        Install-PackageProvider -Name NuGet -Scope AllUsers -Force
    }

    if ((Get-Module -Name PowerShellGet -ListAvailable).Version | Where-Object { $_ -gt '2.2.4' }) {
        Write-Verbose -Message 'PowershellGet already up to date'
    } else {
        Install-Module PowerShellGet -Force
        Remove-Module PowerShellGet, PackageManagement
    }
}

#Requires -Version 5.1
#Requires -Modules PackageManagement
#Requires -RunAsAdministrator

<#PSScriptInfo
    .VERSION 0.0.1
    .GUID 4f0f23da-46ea-462c-97ce-93d3b6319811

    .AUTHOR Peter Wawa
    .COMPANYNAME Telia Eesti
    .COPYRIGHT (c) Telia Eesti 2024.  All rights reserved.

    .TAGS powershell, package, management

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [0.0.1] - 2024-04-24 - Initial release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Updates PowerShellGet module, if needed

    .DESCRIPTION
        Prepares PowerShell for using PSGallery.

    .EXAMPLE
        Update-PowerShellGet.ps1 -PSResourceGet

        This example updates PowerShellGet and installs PSResourceGet module, if needed
    .INPUTS
        This script takes no input

#>

[OutputType([void])]
[CmdletBinding()]
param (
        [switch]
        # Install PSResourceGet module, if not available
    $PSResourceGet
)


$PSResourceGetExists = Get-Module *PSResourceGet -ListAvailable

if ($PSResourceGetExists) {
    Write-Warning -Message 'PSResourceGet already exists, skipping'
    return
} else {
        # add TLS 1.2 support, if needed
    [Net.ServicePointManager]::SecurityProtocol =
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    try {
        Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction Stop
    } catch {
        Install-PackageProvider -Name NuGet -Scope AllUsers -Force
    }

    if ((Get-Module -Name PowerShellGet -ListAvailable).Version | Where-Object { $_ -gt '2.2.4' }) {
        Write-Verbose -Message 'PowershellGet already up to date'
    } else {
        Install-Module PowerShellGet -Force -Repository PSGallery
        Remove-Module PowerShellGet, PackageManagement
    }

    if ($PSResourceGet) {
        Install-Module Microsoft.PowerShell.PSResourceGet -Force -Repository PSGallery -Scope AllUsers
    }
}

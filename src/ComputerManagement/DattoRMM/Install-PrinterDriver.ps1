#Requires -Version 5.1
#Requires -Modules PrintManagement

<#PSScriptInfo
    .VERSION 1.0.3
    .GUID d21e3c0c-65c3-40c6-9509-795cca667081

    .AUTHOR CPG4285
    .COMPANYNAME Telia Eesti
    .COPYRIGHT (c) Telia Eesti 2021.  All rights reserved.

    .TAGS install, printer, driver

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES PrintManagement
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.0.3] - 2021-12-31 - Moved script to Github.
        [1.0.2] - 2021-12-30 - when no parameters on command line, use PrinterPackage.json on script folder
        [1.0.1] - 2021-12-30 - Add cleanup
        [1.0.0] - 2021-12-29 - Initial release
        [0.0.1] - 2021-12-28 - Started work

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Install Printer drivers on local system.
    .DESCRIPTION
        Install Printer drivers according to package file.
    .EXAMPLE
        Install-PrinterDriver.ps1 -Customer myCustomer

        This example downloads and installs driver package for specified customer.
    .EXAMPLE
        Install-PrinterDriver.ps1 -PackageFile .\PrinterPackage.json

        This example downloads and installs drivers based on specified package file.
    .INPUTS
        None
    .OUTPUTS
        pnputil.exe output
    .NOTES
        This script requires admin privileges.

        The package file is .json file containing details needed to add drivers.
    .LINK
        Add-PrinterDriver
    .LINK
        pnputil.exe: https://docs.microsoft.com/windows-server/administration/windows-commands/pnputil
#>

[CmdletBinding(
    DefaultParameterSetName = 'PackageFile',
    SupportsShouldProcess
)]
[OutputType([string])]

param (
        [Parameter(
            Mandatory,
            ParameterSetName = 'Customer'
        )]
        [string]
        # Specifies customer name to use for printer package file download.
    $Customer,

        [Parameter(
            ParameterSetName = 'PackageFile'
        )]
        [uri]
        # Specifies printer package file location.
    $PackageFile = (Join-path -Path $pwd -ChildPath 'PrinterPackage.json')
)

Function Test-IsAdmin {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $adminRole = [Security.Principal.WindowsBuiltinRole]::Administrator
    ([Security.Principal.WindowsPrincipal] $currentUser).IsInRole($adminRole)
}

if (-not (Test-IsAdmin)) {
    throw [Management.Automation.PSSecurityException]::new('Admin Privileges required')
}

switch ($PSCmdlet.ParameterSetName) {
    'PackageFile' {
        $Package = switch ($PackageFile.Scheme) {
            '' {
                Get-Content -Path $PackageFile.OriginalString | ConvertFrom-Json
            }
            [uri]::UriSchemeFile {
                Get-Content -Path $PackageFile.LocalPath | ConvertFrom-Json
            }
            default {
                Invoke-RestMethod -Uri $PackageFile
            }
        }
    }
    'Customer' {
        $PackageUri = 'http://miracle.mlxplus.com/Kliendid', $Customer, 'PrinterPackage.json' -join '/'
        $Package = Invoke-RestMethod -Uri $PackageUri
    }
}

:outer foreach ($driver in $Package.Drivers |
    Where-Object x64 -eq ([environment]::Is64BitOperatingSystem)) {
        $DriverName = $driver.Name
        if ($PSCmdlet.ShouldProcess($DriverName, 'Install driver for')) {
            $DownloadUri = [uri]$driver.Uri
            switch ($DownloadUri.Scheme) {
                '' {
                    $DownloadFullPath = $DownloadUri.OriginalString
                }
                [uri]::UriSchemeFile {
                    $DownloadFullPath = $DownloadUri.LocalPath
                }
                Default {
                    $DownloadFileName = $DownloadUri.Segments[-1]
                    $DownloadFullPath = Join-Path -Path $env:TEMP -ChildPath $DownloadFileName
                    try {
                        Invoke-WebRequest -Uri $DownloadUri -OutFile $DownloadFullPath -ErrorAction Stop
                    } catch {
                        Write-Error -Message ('Unable to download driver: {0}' -f $DriverName)
                        continue outer
                    }
                }
            }
            try {
                $DriverFile = Get-Item $DownloadFullPath -ErrorAction Stop
            } catch {
                Write-Error -Message ('Unable to find driver package: {0}' -f $DownloadFullPath)
                continue outer
            }

            Write-Verbose -Message ('Unpacking: {0}' -f $DriverFile.Name)
            $driverPath = Join-Path -Path $env:TEMP -ChildPath $DriverFile.BaseName
            if (Test-Path -Path $driverPath) {
                Remove-Item -Path $driverPath -Recurse -Force -Confirm:$false
            }
            $null = New-Item -Path $driverPath -ItemType Directory -Confirm:$false
            Expand-Archive -Path $DownloadFullPath -DestinationPath $driverPath

            Write-Verbose -Message ('Adding drivers from: {0}' -f $driverPath)
            pnputil.exe -add-driver "$driverPath\*.inf" #-install
            Add-PrinterDriver -Name $DriverName -Verbose:$Verbose.IsPresent

            #region Cleanup
            Remove-Item -Path $driverPath -Recurse -Force -Confirm:$false
            if ($DownloadFullPath -like "$env:TEMP*") {
                Remove-Item -Path $DownloadFullPath -Confirm:$false
            }
            #endregion
        }
    }

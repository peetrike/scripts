#Requires -Version 5.1
#Requires -Modules PrintManagement

<#PSScriptInfo
    .VERSION 1.0.2
    .GUID a1615324-ebd4-4864-b9a6-7aeef6258001

    .AUTHOR CPG4285
    .COMPANYNAME Telia Eesti
    .COPYRIGHT (c) Telia Eesti 2021.  All rights reserved.

    .TAGS install, printer

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES PrintManagement
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.0.2] - 2021-12-31 - Moved script to Github
        [1.0.1] - 2021-12-30 - When no parameters on command line, use PrinterPackage.json on script folder
        [1.0.0] - 2021-12-29 - Initial release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Install printers according to printer package file
    .DESCRIPTION
        Add printers according to package file.
    .EXAMPLE
        Install-Printer.ps1 -Customer myCustomer

        This example adds printers for specified customer.
    .EXAMPLE
        Install-Printer.ps1 -PackageFile .\PrinterPackage.json

        This example adds printers based on specified package file.
    .NOTES
        This script should be used in the context of user who needs printers.

        The package file is .json file containing details needed to add printers.
    .LINK
        Add-Printer
#>

[CmdletBinding(
    SupportsShouldProcess
)]
[OutputType([void])]

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

switch ($PSCmdlet.ParameterSetName) {
    'PackageFile' {
        if (-not $PackageFile.Scheme) {
            $Package = Get-Content -Path $PackageFile.OriginalString | ConvertFrom-Json
        } elseif ($PackageFile.Scheme -eq [uri]::UriSchemeFile) {
            $Package = Get-Content -Path $PackageFile.LocalPath | ConvertFrom-Json
        } else {
            $Package = Invoke-RestMethod -Uri $PackageFile
        }
    }
    'Customer' {
        $PackageUri = 'http://miracle.mlxplus.com/Kliendid', $Customer, 'PrinterPackage.json' -join '/'
        $Package = Invoke-RestMethod -Uri $PackageUri
    }
}

$Package.Drivers |
    Where-Object x64 -eq ([environment]::Is64BitOperatingSystem) |
    ForEach-Object {
        $driver = $_
        $PrinterName = $driver.Name

        if ($PSCmdlet.ShouldProcess($PrinterName, 'Install printer')) {
            $PrinterIp = $driver.Connection

            Write-Verbose -Message ('Adding printer port: {0}' -f $PrinterIp)
            try {
                $null = Get-PrinterPort -Name $PrinterIp -ErrorAction Stop
                Write-Warning -Message ('Port already exists: {0}' -f $PrinterIp)
            } catch {
                Add-PrinterPort -Name $PrinterIp -PrinterHostAddress $PrinterIp
            }

            Write-Verbose -Message ('Adding printer: {0}' -f $PrinterName)
            try {
                $null = Get-Printer -Name $PrinterName -ErrorAction Stop
                Write-Warning -Message ('Pinter already exists: {0}' -f $PrinterName)
            } catch {
                Add-Printer -Name $PrinterName -DriverName $PrinterName -PortName $PrinterIp
            }
        }
    }

#Requires -Version 2.0
# Requires -RunAsAdministrator

<#PSScriptInfo
    .VERSION 1.1.0
    .GUID 4fd6dfae-9f42-4b2d-bd1a-a938e7d42544

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2020.  All rights reserved.

    .TAGS tls, security, Windows, PSEdition_Desktop, PSEdition_Core

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.1.0] - 2022.09.14 - replace script body with function
                             - add registry settings for .NET framework and OS
        [1.0.0] - 2020.12.10 - Initial release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Set SChannel protocol states
    .DESCRIPTION
        This script allows to change SChannel protocol states for server and client.
    .EXAMPLE
    Set-Tls.ps1 -Protocol Ssl3

    This example disables SSL3 protocol for both server and client.
    .EXAMPLE
    Set-Tls.ps1 -Target Server -Protocol Ssl3 -State Enabled

    This example enables SSL3 protocol for server.
    .LINK
        https://docs.microsoft.com/windows-server/security/tls/tls-registry-settings
#>

[CmdletBinding(
    SupportsShouldProcess = $true
)]
param (
        [ValidateSet('Client', 'Server', 'Both')]
        [string[]]
    $Target = 'Both',
        [parameter(
            Mandatory = $true
        )]
        [ValidateSet(
            'Ssl2', #DevSkim: ignore DS440000
            'Ssl3', #DevSkim: ignore DS440000
            'Tls10', #DevSkim: ignore DS440000
            'Tls11', #DevSkim: ignore DS440000
            'Tls12' #DevSkim: ignore DS440000
        )]
        [string[]]
    $Protocol,
        [ValidateSet(
            'Default',
            'Disabled',
            'Enabled'
        )]
        [string]
    $State = 'Disabled'
)

function Set-Tls {
    # .EXTERNALHELP telia.windows.security-help.xml
    [CmdletBinding(
        SupportsShouldProcess = $true
    )]
    param (
            [ValidateSet('Client', 'Server', 'Both')]
            [string[]]
        $Target = 'Both',
            [parameter(
                Mandatory = $true
            )]
            [ValidateSet(
                'Ssl2', #DevSkim: ignore DS440000
                'Ssl3', #DevSkim: ignore DS440000
                'Tls10', #DevSkim: ignore DS440000
                'Tls11', #DevSkim: ignore DS440000
                'Tls12' #DevSkim: ignore DS440000
            )]
            [string[]]
        $Protocol,
            [ValidateSet(
                'Default',
                'Disabled',
                'Enabled'
            )]
            [string]
        $State ='Disabled'
    )

    function Test-IsAdmin {
        [CmdletBinding()]
        #[OutputType([Boolean])]
        param()

        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        ([Security.Principal.WindowsPrincipal] $currentUser).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
    }

    if (-not (Test-IsAdmin)) {
        throw (New-Object -TypeName System.Management.Automation.PSSecurityException -ArgumentList "Admin Privileges required")
    }

    function Set-DefaultState {
        [CmdletBinding()]
        param(
            $Path,
            $Name
        )
        Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue |
            Remove-ItemProperty -Name $Name -Confirm:$false -WhatIf:$false
    }

    if ($Target -eq 'Both') {
        $Target = 'Client', 'Server'
    }

    $ShouldProcessProps = @{
        Confirm = $false
        WhatIf  = $false
    }

    #region Set .NET Framework
    # https://docs.microsoft.com/dotnet/framework/network-programming/tls
    $DotNetVersion = 'v2.0.50727', 'v4.0.30319'
    $PropertyName = 'SystemDefaultTlsVersions', 'SchUseStrongCrypto' #DevSkim: ignore DS440000

    foreach ($basePath in '', 'Wow6432Node') {
        foreach ($version in $DotNetVersion) {
            $RegPath = 'HKLM:\SOFTWARE', $BasePath, 'Microsoft\.NETFramework', $version -join '\'
            $RegPath = Resolve-Path -Path $RegPath
            if (Test-Path -Path $RegPath) {
                foreach ($p in $PropertyName) {
                    Set-ItemProperty -Path $RegPath -Name $p -Value 1 @ShouldProcessProps -Type DWord
                }
            }
        }
    }
    #endregion

    $SecureChannelKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\'
    $ProtocolKey = Join-Path -Path $SecureChannelKey -ChildPath 'Protocols'

    $ProtocolList = @{
        Ssl2  = 'SSL 2.0' #DevSkim: ignore DS440000
        Ssl3  = 'SSL 3.0' #DevSkim: ignore DS440000
        Tls10 = 'TLS 1.0' #DevSkim: ignore DS440000
        Tls11 = 'TLS 1.1' #DevSkim: ignore DS440000
        Tls12 = 'TLS 1.2' #DevSkim: ignore DS440000
    }

    foreach ($TargetProtocol in $Protocol) {
        foreach ($t in $Target) {
            $Path = $ProtocolKey, $ProtocolList.$TargetProtocol, $t -join '\'
            if ($PSCmdlet.ShouldProcess(
                $('{0} for {1}' -f $TargetProtocol, $t),
                $('Set to {0}' -f $State)
            )) {
                if (-not (Test-Path -Path $Path -PathType Container)) {
                    $null = New-Item -Path $Path -ItemType Container -Force
                }
                switch ($State) {
                    'Default' {
                        $Name = 'Enabled'
                        Set-DefaultState -Path $Path -Name 'Enabled'
                        Set-DefaultState -Path $Path -Name 'DisabledByDefault'
                    }
                    'Disabled' {
                        Set-ItemProperty -Path $Path -Name Enabled -Value 0 @ShouldProcessProps
                        Set-ItemProperty -Path $Path -Name DisabledByDefault -Value 1 @ShouldProcessProps
                    }
                    'Enabled' {
                        Set-ItemProperty -Path $Path -Name Enabled -Value 1 @ShouldProcessProps
                        Set-ItemProperty -Path $Path -Name DisabledByDefault -Value 0 @ShouldProcessProps
                    }
                }
                Write-Warning -Message 'Restart computer to make changes active'
            }
        }
    }
}

Set-Tls @PSBoundParameters

#Requires -Version 2.0
# Requires -RunAsAdministrator

<#PSScriptInfo
    .VERSION 1.0
    .GUID 4fd6dfae-9f42-4b2d-bd1a-a938e7d42544

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2020.  All rights reserved.

    .TAGS tls, security, Windows, PSEdition_Desktop, PSEdition_Core

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://bitbucket.atlassian.teliacompany.net/projects/PWSH/repos/scripts/
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
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
        # Specify the client or server as operation target
    $Target = 'Both',
        [parameter(
            Mandatory = $true
        )]
        [ValidateSet(
            'Ssl2',
            'Ssl3',
            'Tls10',
            'Tls11',
            'Tls12'
        )]
        [string[]]
        # Specify protocol to change
    $Protocol,
        [ValidateSet(
            'Default',
            'Disabled',
            'Enabled'
        )]
        [string]
        # Specify the desired protocol state
    $State ='Disabled'
)

function Test-IsAdmin {
    # .EXTERNALHELP PWAddins-help.xml
    [CmdletBinding()]
    [OutputType([Boolean])]
    param()

    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    ([Security.Principal.WindowsPrincipal] $currentUser).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    throw (New-Object -TypeName System.Management.Automation.PSSecurityException -ArgumentList "Admin Privileges required")
}

if ($Target -eq 'Both') {
    $Target = 'Client', 'Server'
}

$SecureChannelKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\'
$ProtocolKey = Join-Path -Path $SecureChannelKey -ChildPath 'Protocols'

$ProtocolList = @{
    Ssl2  = 'SSL 2.0'
    Ssl3  = 'SSL 3.0'
    Tls10 = 'TLS 1.0'
    Tls11 = 'TLS 1.1'
    Tls12 = 'TLS 1.2'
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
            $ShouldProcessProps = @{
                Confirm = $false
                WhatIf  = $false
            }
            switch ($State) {
                'Default' {
                    Get-ItemProperty -Path $Path | Remove-ItemProperty -Name Enabled @ShouldProcessProps
                }
                'Disabled' {
                    Set-ItemProperty -Path $Path -Name Enabled -Value 0 @ShouldProcessProps
                    Set-ItemProperty -Path $Path -Name DisabledByDefault -Value 1 @ShouldProcessProps
                }
                'Enabled' {
                    Set-ItemProperty -Path $Path -Name Enabled -Value 4294967295 @ShouldProcessProps
                    Set-ItemProperty -Path $Path -Name DisabledByDefault -Value 0 @ShouldProcessProps
                }
            }
            Write-Warning -Message 'Restart computer to make changes active'
        }
    }
}

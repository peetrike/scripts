#Requires -Version 5.1
#Requires -Modules CimCmdlets

<#PSScriptInfo
    .VERSION 1.0.1
    .GUID c0fab87b-7294-44d8-9956-b98f8b6c1c23

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2020.  All rights reserved.

    .TAGS rdp shadow PSEdition_Desktop Windows

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://bitbucket.atlassian.teliacompany.net/projects/PWSH/repos/scripts/
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES CimCmdlets
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.0.0] - 2020.09.02 - Initial release
        [1.0.1] - 2020.09.02 - fix problem with invoke-cimmethod

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Add Shadow session establishing permissions in RDP farm.
    .DESCRIPTION
        This script configures RD Session Host servers, adding Shadow session establishing permissions to specified
        account.
#>

[CmdletBinding(
    SupportsShouldProcess
)]
param (
        [string]
        # Specify RD Connection Broker server name.  By default this is discovered automatically.
    $ConnectionBroker,
        [string]
        # Specify user/group account that should be granted with permissions on RD Session Host servers.
        # Be sure that you enter correct name, as there is no validation.
    $AccountName
)

function Get-ConnectionBroker {
    $RegistryArgs = @{
        Name = 'SessionDirectoryLocation'
        Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\ClusterSettings\'
    }
    $ConnectionBroker = Get-ItemPropertyValue @RegistryArgs
    if ($ConnectionBroker -eq [net.dns]::GetHostByName($env:COMPUTERNAME).HostName) {
        $env:COMPUTERNAME
    } else { $ConnectionBroker }
}

if (-not $ConnectionBroker) {
    $ConnectionBroker = Get-ConnectionBroker
}

$ServerProperty = 'ServerName'
$ServerProps = @{
    ComputerName = $ConnectionBroker
    ClassName    = 'Win32_SessionDirectoryServer'
    #Property     = $ServerProperty
}
$RdshProps = @{
    ClassName = 'Win32_TSPermissionsSetting'
    Namespace = 'root/cimv2/TerminalServices'
    Filter    = 'TerminalName = "RDP-Tcp"'
}
$MethodProps = @{
    MethodName = 'AddAccount'
    Arguments  = @{
        AccountName      = $AccountName
        PermissionPreSet = 2 # WINSTATION_ALL_ACCESS
    }
    Confirm    = $false
    WhatIf     = $false
}

    # set permissions in all RD Session Host servers
foreach ($server in (Get-CimInstance @ServerProps).$ServerProperty) {
    if ($PSCmdlet.ShouldProcess('Set permissions on server', $server)) {
        $RdshProps.ComputerName = $server
        Get-CimInstance @rdshProps |
            Invoke-CimMethod @MethodProps
    }
}

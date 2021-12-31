#Requires -Version 3
# Requires -RunAsAdministrator
#Requires -Modules NetSecurity

<#PSScriptInfo
    .VERSION 1.0.1
    .GUID ff051f84-9a4f-4b2c-9971-5a5ba70d6d83

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2019.  All rights reserved.

    .TAGS firewall, nbu, netbackup, backup

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://bitbucket.atlassian.teliacompany.net/projects/PWSH/repos/scripts/browse
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES NetSecurity
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.0.1] - 2018.12.10 - Changed test for admin rights
        [1.0.0] - 2018.11.21 - Initial Release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Creates firewall rules required by NetBackup Agent

    .DESCRIPTION
        This script creates firewall rules required by NetBackup Agent

#>

[CmdletBinding(
    SupportsShouldProcess
)]
param ()

Function Test-IsAdmin {
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

# Üks reegel 3 pordi jaoks
# New-NetFirewallRule -DisplayName "NBU backup" -LocalPort 1556,13782,13724 -Protocol TCP -Action Allow -Profile Any -Direction Inbound -RemoteAddress 88.196.98.192/27

# eraldi reeglid iga teenuse jaoks

function New-Rule {
    [CmdletBinding(
        SupportsShouldProcess
    )]
    param (
            [ValidateRange(0,65535)]
            [int]
        $LocalPort,
            [ValidateScript({
                $parts = $_.split('%')
                if ($parts.count -gt 1) {
                    $path = join-path (Get-Content env:\$($parts[1])) $parts[2]
                } else {
                    $path = $_
                }
                if (Test-Path $path) { $true }
                else { throw ('Path not found: {0}' -f $_) }
            })]
            [string]
        $ProgramPath,
            [ValidateScript({
                if (Get-Service -Name $_) { $true }
                else { throw ('Service not found: {0}' -f $_) }
            })]
            [string]
        $ServiceName,
            [string]
        $DisplayName
    )

    $RuleProps = @{
        Action        = 'Allow'
        Description   = 'NBU Backup Agent rules'
        Direction     = 'Inbound'
        Enabled       = 'True'
        Profile       = 'Domain','Private'
        RemoteAddress = '88.196.98.192/27'
        Protocol      = 'TCP'
        LocalPort     = $LocalPort
        DisplayName   = $DisplayName
        Program       = $ProgramPath
#        Service     = $ServiceName
    }

    $Rule = Get-NetFirewallRule -DisplayName $DisplayName -ErrorAction SilentlyContinue

    if ($Rule) {
        Write-Verbose -Message ('Changing existing rule: {0}' -f $Rule.DisplayName)
        Set-NetFirewallRule @RuleProps -WhatIf:$WhatIfPreference
    } else {
        Write-Verbose -Message ('Creating new rule: {0}' -f $DisplayName)
        New-NetFirewallRule @RuleProps -WhatIf:$WhatIfPreference
    }
}

New-Rule -LocalPort 1556 -ProgramPath '%ProgramFiles(x86)%\VERITAS\VxPBX\bin\pbx_exchange.exe' -ServiceName 'VRTSpbx' -DisplayName 'Veritas Private Branch Exchange' -WhatIf:$WhatIfPreference
New-Rule -LocalPort 13724 -ProgramPath '%ProgramFiles%\Veritas\NetBackup\bin\vnetd.exe' -ServiceName 'NetBackup Legacy Network Service' -DisplayName 'NetBackup Legacy Network Service' -WhatIf:$WhatIfPreference
New-Rule -LocalPort 13782 -ProgramPath '%ProgramFiles%\Veritas\NetBackup\bin\bpcd.exe' -ServiceName 'NetBackup Client Service' -DisplayName 'NetBackup Client Service' -WhatIf:$WhatIfPreference

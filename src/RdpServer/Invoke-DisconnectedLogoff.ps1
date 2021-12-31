#Requires -Version 2.0
# Requires -Modules telia.common
# Requires -Modules RemoteDesktop

<#PSScriptInfo
    .VERSION 1.0.1
    .GUID 5a6d1359-df01-4607-aead-111495452518
    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2019.  All rights reserved.
    .TAGS logoff, rdp, session
    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://bitbucket.atlassian.teliacompany.net/projects/PWSH/repos/scripts/
    .ICONURI
    .EXTERNALMODULEDEPENDENCIES
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES
    .RELEASENOTES
        [0.0.1] - 2019.07.15 - Started work
        [1.0.0] - 2019.07.16 - Initial release
        [1.0.1] - 2020.05.06 - Replace function Write-Log

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        logs off all disconnected user sessions

    .DESCRIPTION
        This script logs off all RDP sessions that are currently disconnected.
        Logged off users are written into log file.
#>

[CmdLetBinding()]
Param(
        [string]
        # Specifies log file path
    $LogFilePath
)

function Write-Log {
    # copied from telia.common module
    [CmdletBinding(SupportsShouldProcess = $True)]
    Param(
            [Parameter(Position = 0, ValueFromPipeline = $true)]
            [String]
        $Message,
            [Parameter(Position = 1)]
            [string]
        $Path = $(
            if ($LogFilePath) {
                $LogFilePath
            } else {
                Join-Path -Path $PWD -ChildPath 'WriteLog.txt'
            }
        ),
            [bool]
        $WriteLog = $true,
            [Switch]
        $NoDate,
            [Switch]
        $Force,
            [Switch]
        $AddEmptyLine
    )

    begin {
        Write-Verbose -Message ('Using logfile: {0}' -f $Path)
    }

    process {
        if ($NoDate) {
            $LogMessage = $Message
        } else {
            $LogMessage = '{0:g} {1}' -f [datetime]::Now, $Message
        }

        if ($WriteLog -and ($Force -or $PSCmdlet.ShouldProcess($Path, 'write message to log'))) {
            Write-Verbose $LogMessage

            if ($Message) {
                Add-Content -Value $LogMessage -Path $Path -WhatIf:$false -Confirm:$false
            }
            if ($AddEmptyLine) {
                Add-Content -Value '' -Path $Path -WhatIf:$false -Confirm:$false
            }
        }
    }
}

function Get-RdpUserSession {
    [CmdletBinding()]
    param (
            [ValidateSet('Active', 'Disconnected')]
            [string]
        $State
    )

    $FilteredState = $State
    if ($State -like 'Disconnected') {
        $FilteredState = 'Disc'
    }

    $queryResults = query.exe user
    $Header =$queryResults[0]
    $starters = New-Object psobject -Property @{
        SessionName = $Header.IndexOf("SESSIONNAME")
        State       = $Header.IndexOf("STATE")
        IdleTime    = $Header.IndexOf("IDLE TIME")
        LogonTime   = $Header.IndexOf("LOGON TIME")
    }
    foreach ($result in $queryResults | Select-Object -Skip 1) {
        $SessionState = $result.Substring($starters.State, $starters.IdleTime - $starters.State).trim()
        if ((-not $State) -or ($SessionState -like $FilteredState)) {
            $SessionUserName = $result.Substring(1, $result.Trim().Indexof(" ")).TrimEnd()
            Write-Verbose -Message ('Processing user {0}' -f $SessionUserName)

            $EndOfSessionName = $result.IndexOf(" ", $starters.SessionName)
            New-Object psobject -Property @{
                SessionName = $result.Substring($starters.SessionName, $EndOfSessionName - $starters.SessionName)
                Username    = $SessionUserName
                ID          = $result.Substring($EndOfSessionName, $starters.State - $EndOfSessionName).trim() -as [int]
                State       = $SessionState
                IdleTime    = $result.Substring($starters.IdleTime, $starters.LogonTime - $starters.IdleTime).trim();
                LogonTime   = [datetime]::Parse($result.Substring($starters.LogonTime))
            }
        }
    }
}

if (-not $LogFilePath) {
    $DesktopPath = [System.Environment]::GetFolderPath("Desktop")
    $LogFileName = 'sessions_{0}.log' -f [datetime]::now.ToString('s').Replace(':', '.')
    $LogFilePath = join-path -Path $DesktopPath -ChildPath $LogFileName
}

Write-Log -Message "Disconnected Sessions CleanUp"
Write-Log -Message "============================="
foreach ($user in Get-RdpUserSession -State Disconnected ) {
    Write-Log -Message ('Logging off user: {0}' -f $user.Username)
    logoff.exe $user.ID
}
Write-Log -Message "Finished" -AddEmptyLine

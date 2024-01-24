#Requires -Version 2.0

<#PSScriptInfo
    .VERSION 1.1.0

    .GUID 5a6d1359-df01-4607-aead-111495452518

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2019.  All rights reserved.

    .TAGS logoff, rdp, session

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.1.0] - 2024.01.24 - Convert IdleTime to [timespan]
        [1.0.3] - 2024.01.24 - When converting logon time, try using en-us culture first
        [1.0.2] - 2022.05.27 - Fix obtaining Session Name
        [1.0.1] - 2020.05.06 - Replace function Write-Log
        [1.0.0] - 2019.07.16 - Initial release
        [0.0.1] - 2019.07.15 - Started work

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Logs off all disconnected user sessions
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
    } else {
        Write-Verbose -Message 'No logged on user sessions exist'
    }

    $queryResults = query.exe user 2> $null
    if ($queryResults) {
        $Header = $queryResults[0]
        $starters = New-Object psobject -Property @{
            SessionName = $Header.IndexOf('SESSIONNAME')
            State       = $Header.IndexOf('STATE')
            IdleTime    = $Header.IndexOf('IDLE TIME')
            LogonTime   = $Header.IndexOf('LOGON TIME')
        }
    }
    foreach ($result in $queryResults | Select-Object -Skip 1) {
        $SessionState = $result.Substring($starters.State, $starters.IdleTime - $starters.State).trim()
        if ((-not $State) -or ($SessionState -like $FilteredState)) {
            $SessionUserName = $result.Substring(1, $result.Trim().Indexof(' ')).TrimEnd()
            Write-Verbose -Message ('Processing session {0}' -f $SessionUserName)

            $EndOfSessionName = $result.IndexOf(' ', $starters.SessionName)
            $IdleString = $result.Substring(
                $starters.IdleTime, $starters.LogonTime - $starters.IdleTime
            ).trim()
            New-Object psobject -Property @{
                SessionName = $result.Substring(
                    $starters.SessionName, $EndOfSessionName - $starters.SessionName
                )
                Username    = $SessionUserName
                ID          = $result.Substring(
                    $EndOfSessionName, $starters.State - $EndOfSessionName
                ).trim() -as [int]
                State       = $SessionState
                IdleTime    = switch -Regex ($IdleString) {
                    { $_ -as [int] } { New-TimeSpan -Minutes $_ }
                    '^(\d{1,2}):(\d{1,2})' {
                        New-TimeSpan -Hours $Matches[1] -Minutes $Matches[2]
                    }
                    '^(\d+)\+(\d{1,2}):(\d{1,2})' {
                        New-TimeSpan -Days $Matches[1] -Hours $Matches[2] -Minutes $Matches[3]
                    }
                    default { [timespan] 0 }
                }
                LogonTime   = try {
                    [datetime] $result.Substring($starters.LogonTime)
                } catch {
                    [datetime]::Parse($result.Substring($starters.LogonTime))
                }
            }
        }
    }
}

if (-not $LogFilePath) {
    $DesktopPath = [System.Environment]::GetFolderPath("Desktop")
    $LogFileName = 'sessions_{0}.log' -f [datetime]::now.ToString('s').Replace(':', '.')
    $LogFilePath = join-path -Path $DesktopPath -ChildPath $LogFileName
}

Write-Log -Message 'Disconnected Sessions CleanUp'
Write-Log -Message '============================='
foreach ($session in Get-RdpUserSession -State Disconnected ) {
    Write-Log -Message ('Logging off user: {0}' -f $session.Username)
    logoff.exe $session.ID
}
Write-Log -Message 'Finished' -AddEmptyLine

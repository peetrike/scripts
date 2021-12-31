#Requires -Version 2.0

<#PSScriptInfo

    .VERSION 1.0.1

    .GUID 4ac33aa8-f03f-46d9-86ae-24067d634bd6

    .AUTHOR CPG4285

    .COMPANYNAME Telia Eesti AS

    .COPYRIGHT (c) Telia Eesti AS 2018.  All rights reserved.

    .TAGS network, ping

    .LICENSEURI https://opensource.org/licenses/MIT

    .PROJECTURI https://bitbucket.atlassian.teliacompany.net/projects/PWSH/repos/scripts/

    .ICONURI

    .EXTERNALMODULEDEPENDENCIES

    .REQUIREDSCRIPTS

    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.0.1] - 2019.06.18 - Removed redundant variable
        [1.0.0] - 2019.06.18 - Initial release

    .PRIVATEDATA

#>

<#
    .SYNOPSIS
        Pings remote computers and collects too long and unsuccessful ones.

    .DESCRIPTION
        This script tests connection to remote computer by pinging them.
        Then it collects unsuccessful and too long ping results and saves
        them in log file.

    .INPUTS
        System.String[] or PSObject[].

        Hosts that should be pinged

    .OUTPUTS
        System.Management.ManagementObject#root\cimv2\Win32_PingStatus

        Ping status objects that are considered good

    .EXAMPLE
        Test-BadPing.ps1 -ComputerName www.example.com

        Ping host www.example.com 10 times and record unsuccessful responses in log file.

    .EXAMPLE
        Test-BadPing.ps1 -ComputerName host1, host2 -Count 2

        Ping several hosts 2 times and record unsuccessful responses in log file.

    .EXAMPLE
        Test-BadPing.ps1 host1, host2 -Limit 200

        Ping several hosts 10 times and record all responses that did not reach
        destination or which took more than 200 ms.

    .EXAMPLE
        Test-BadPing.ps1 -LogFile mylog.txt

        Ping default host 10 times and record unsuccessful responses in log file
        named mylog.txt.
#>

[CmdletBinding()]
param (
        [parameter(
            Position = 0,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [Alias('CN', 'PingDest', 'IPAddress', 'DNSHostName')]
        [string[]]
        # Specifies the computers to ping. Type the computer names or type IP addresses in IPv4 or IPv6 format.
    $ComputerName = 'www.ee',
        [parameter(
            Position = 1
        )]
        [int]
        # Specifies response time that is considered too slow.  Response time is given in milliseconds.
    $Limit = 500,
        [string]
        # Specifies filename for too long ping responses
    $LogFile = (join-path -Path $PWD -ChildPath 'badpings.log'),
        [int]
        # Specifies how many times ping is performed
    $Count = 10
)

begin {
    Write-Verbose -Message ('Logging replies over {0}ms.' -f $Limit)
}

process {
    :computer foreach ($computer in $ComputerName) {
        Write-Verbose -Message ('Pinging {0}' -f $computer)

        foreach ($i in 1..$Count) {
            $result = $null

            try {
                $result = Test-Connection -ComputerName $computer -Count 1 -ErrorAction Stop
            } catch [System.Net.NetworkInformation.PingException] {
                Write-Error $_
                $line = '[{0:T}] {1}' -f (Get-Date), $_.Exception.Message
                Add-Content -Path $logFile -Value $line
                continue computer
            }

            if ($result) {
                $time = $result.ResponseTime
                if ($time -gt $Limit) {
                    $line = '[{0:T}] Reply from {1}: bytes={3} time={2}ms TTL={4}' -f (Get-Date), $computer, $time, $result.ReplySize, $result.TimeToLive
                    Add-Content -Path $logFile -Value $line
                    Write-Warning -Message $line
                } else {
                    $result
                }
            }
            Start-Sleep -Seconds 1
        }
    }
}

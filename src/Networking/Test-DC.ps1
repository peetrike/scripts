<#
    .SYNOPSIS
        Check that DC is available
    .DESCRIPTION
        This script checks that domain controller known ports are available for this computer
    .LINK
        Specify a URI to a help page, this will show when Get-Help -Online is used.
    .EXAMPLE
        Test-DC -ReportFile myreport.json
        This example checks DC availability and saves result to specified file
#>

[CmdletBinding()]
param (
        [string]
        # .json file name to use for saving result.  If file exists, new result will be added.
    $ReportFile = (Join-Path -Path $PWD -ChildPath ((Get-Item $PSCommandPath).BaseName + '.json')),
        [switch]
        # Returns an object representing the check result.
    $PassThru
)

$RootDse = [adsi] 'LDAP://RootDse'
$DcName = $RootDse.dnsHostName.Value
$Domain = ($rootdse.ldapServiceName -split '@')[-1]

$NameResolution = [bool] (Resolve-DnsName -Type SRV -Name ('_ldap._tcp.{0}' -f $Domain))

$PortList = foreach ($port in 88, 389, 636, 445) {
    Test-NetConnection -ComputerName $DcName -Port $port |
        Select-Object -Property Remote*, TcpTestSucceeded
}

$result = @(
    if (Test-Path -Path $ReportFile -PathType Leaf) {
        Get-Content -Path $ReportFile -Encoding utf8 | ConvertFrom-Json | ForEach-Object { $_ }
    }
    [PSCustomObject] @{
        Time      = [datetime]::Now
        DnsCheck  = $NameResolution
        DCName    = $DcName
        PortTests = $PortList
    }
)
ConvertTo-Json -InputObject $result -Depth 3 |
    Set-Content -Path $ReportFile -Encoding utf8

if ($PassThru) {
    $result |
        Select-Object -Last 1 |
        Select-Object -Property Time -ExpandProperty PortTests
}

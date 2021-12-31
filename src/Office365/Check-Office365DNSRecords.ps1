#Requires -Version 3.0
#Requires -Modules Indented.Net.Dns

<#PSScriptInfo

    .VERSION 1.1.0
    .GUID 7216e2a5-936c-4936-9478-bcad3286bd35

    .AUTHOR cpg4285
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2019.  All rights reserved.

    .TAGS dns, office365, PSEditon_Core, PSEditon_Desktop, Windows

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://bitbucket.atlassian.teliacompany.net/projects/PWSH/repos/scripts/
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.1.0] - 2020-09-04 - changed dependent module to make script compatible with PowerShell 7
        [1.0.2] - 2019-03-01 - changed comment-based help
        [1.0.1] - 2019-03-01 - removed commented out code
        [1.0.0] - 2019-03-01 - Initial release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Checks for Office365-related DNS records.
    .DESCRIPTION
        This script checks a list of domains: scans each domain for DNS records that may indicate which Office 365 services have been configured in DNS
    .EXAMPLE
        PS C:\> Check-Office365DNSRecords.ps1 -Domain telia.ee
        This command checks single DNS domain provided from command line
    .EXAMPLE
        PS C:\> 'telia.ee', 'elion.ee' | Check-Office365DNSRecords.ps1
        This command checks several DNS domains provided through pipeline
    .INPUTS
        Domain names to be checked, single name in a row
    .OUTPUTS
        Check results
    .NOTES
        Based on script Get-Office365DNSRecords.ps1 (https://gallery.technet.microsoft.com/office/Get-Office365DNSRecordsps1-da47f91c)
        Modified by Jako Berson
        Refactored by Peter Wawa
#>

[CmdLetBinding()]
param (
        [parameter(
            Mandatory,
            ValueFromPipeline,
            HelpMessage = 'Sisesta domeeninimed, mida kontrollida'
        )]
        [alias('SingleDomain')]
        [string[]]
        # Specifies DNS domain to be checked
    $Domain
)

begin {
    function Get-DnsRecord {
        [CmdLetBinding()]
        param (
                [string]
            $Name,
                [string]
            $Type
        )

        Write-Verbose -Message ('Performing query of type {0} for {1}' -f $Type, $Name)
        $Result = get-Dns -Name $Name -Type $Type |
            Select-Object -ExpandProperty Answer

        foreach ($record in $Result) {
            $Response = New-Object -TypeName PSCustomObject -Property @{
                Name   = $record.Name
                Record = $record.RecordData
                <# Record = switch ($record.Type) {
                    'CNAME' {$record.RECORD.CNAME}
                    'MX' {$record.RECORD.EXCHANGE}
                    'NS' {$record.RECORD.NSDNAME}
                    'SRV' {$record.RECORD.TARGET}
                    'TXT' {$record.RECORD.TXT -join ' '}
                } #>
            }
            Write-Verbose -Message ('DNS Result: {0}' -f $Response.Record)
            $Response
        }
    }
}

process {
    foreach ($domaintotest in $Domain) {
        Write-host ("`nChecking domain: {0}" -f $domaintotest)

        $autodiscovercheck = Get-DnsRecord -Name "autodiscover.$domaintotest" -Type 'CNAME'
        if ($null -ne $autodiscovercheck) {
            if ($autodiscovercheck.Record -like "autodiscover.outlook.com." ) {$color = "green"} else {$color = "red"}
            $message = 'Autodiscover CNAME found: {0}     -   {1}' -f $autodiscovercheck.Name, $autodiscovercheck.Record
            Write-Host $message -ForegroundColor $color
        } else {
            Write-Host "No autodiscover CNAME found for $domaintotest" -ForegroundColor Red -BackgroundColor Yellow
        }

        $AutodiscoverSRVcheck = Get-DnsRecord -Name "_autodiscover._tcp.$domaintotest" -Type 'SRV'
        if ($null -ne $AutodiscoverSRVcheck) {
            $message = 'Autodiscover SRV found: {0} -   {1}' -f $AutodiscoverSRVcheck.Name, $AutodiscoverSRVcheck.Record
            Write-Host $message -ForegroundColor Red
        } else {
            Write-Host "No autodiscover SRV record found for $domaintotest" -ForegroundColor Green
        }

        $mxcheck = Get-DnsRecord -Name $domaintotest -Type 'MX'
        if ($null -ne $mxcheck) {
            if ($mxcheck.Record -like "*mail.protection.outlook.com." ) {$color = "Green"} else {$color = "Red"}
            $message = "MX Records found for {0}                        -   {1}" -f $domaintotest, ($mxcheck.Record -join ' ')
            Write-Host $message -ForegroundColor $color
        } else {
            Write-Host "No MX record found for $domaintotest" -ForegroundColor Red -BackgroundColor Yellow
        }

        $SPFcheck = Get-DnsRecord -Name $domaintotest -Type 'TXT' | Where-Object Record -like "*v=spf1*"
        if ($null -ne $SPFcheck) {
            if ($SPFcheck.Record -like '*include:spf.protection.outlook.com*' ) {$color = "green"} else {$color = "red"}
            $message = 'SPF record found: {0}                           -   {1}' -f $domaintotest, $SPFcheck.Record
            if ($SPFcheck.Record -like '*~all*' ) {
                Write-Host $message -ForegroundColor $color -BackgroundColor DarkRed
            } else {
                Write-Host $message -ForegroundColor $color
            }
        } else {
            Write-Host "No SPF record found for $domaintotest" -ForegroundColor Red -BackgroundColor Yellow
        }

        $siptlscheck = Get-DnsRecord -Name "_sip._tls.$domaintotest" -Type 'SRV'
        if ($null -ne $siptlscheck) {
            $message = 'SIP TLS Records found: {0}           -   {1}' -f $siptlscheck.Name, $siptlscheck.Record
            Write-Host $message -ForegroundColor Green
        } else {
            Write-Host "No SIP TLS record found for $domaintotest" -ForegroundColor Red -BackgroundColor Yellow
        }

        $sipfederationtlscheck = Get-DnsRecord -Name "_sipfederationtls._tcp.$domaintotest" -Type 'SRV'
        if ($null -ne $sipfederationtlscheck) {
            $message = 'SIP Federation TLS: {0} -   {1}' -f $sipfederationtlscheck.Name, $sipfederationtlscheck.Record
            Write-Host $message -ForegroundColor Green
        } else {
            Write-Host "No SIP Federation TLS record found for $domaintotest" -ForegroundColor Red -BackgroundColor Yellow
        }

        $sipcheck = Get-DnsRecord -Name "sip.$domaintotest" -Type 'CNAME'
        if ($null -ne $sipcheck) {
            $message = 'SIP Record found: {0}                      -   {1}' -f $sipcheck.Name, $sipcheck.Record
            Write-Host $message -ForegroundColor Green
        } else {
            Write-Host "No SIP record found for $domaintotest" -ForegroundColor Red -BackgroundColor Yellow
        }

        $lyncdiscovercheck = Get-DnsRecord -Name "lyncdiscover.$domaintotest" -Type 'CNAME'
        if ($null -ne $lyncdiscovercheck) {
            $message = 'Lyncdiscover Record found: {0}    -   {1}' -f $lyncdiscovercheck.Name, $lyncdiscovercheck.Record
            Write-Host $message -ForegroundColor Green
        } else {
            Write-Host "No Lyncdiscover record found for $domaintotest" -ForegroundColor Red -BackgroundColor Yellow
        }

        $msoidcheck = Get-DnsRecord -Name "msoid.$domaintotest" -Type 'CNAME'
        if ($null -ne $msoidcheck) {
            $message = 'MSOID Record found: {0}                  -   {1}' -f $msoidcheck.Name, $msoidcheck.Record
            Write-Host $message -ForegroundColor Green
        } else {
            Write-Host "No MSOID record found for $domaintotest" -ForegroundColor Red -BackgroundColor Yellow
        }

        $TXTMScheck = Get-DnsRecord -Name $domaintotest -Type TXT | Where-Object Record -like "MS=ms*"
        if ($null -ne $TXTMScheck) {
            $message = 'TXT MS=msxxxx record found: {0}                -   {1}' -f $domaintotest, $TXTMScheck.Record
            Write-Host $message -ForegroundColor Green
        } else {
            Write-Host "No MS=msxxxx found for $domaintotest" -ForegroundColor Red -BackgroundColor Yellow
        }

        $NScheck = Get-DnsRecord -Name $domaintotest -Type 'NS'
        if ($null -ne $NScheck) {
            $message = 'NS record found: {0}                            -   {1}' -f $domaintotest, ($NScheck.Record -join ', ')
            write-host $message -foregroundcolor green
        } else {
            Write-Host "No NameServer found for $domaintotest" -ForegroundColor Red -BackgroundColor Yellow
        }
    } # foreach
}

end {
    Write-Host 'Checks complete'
}

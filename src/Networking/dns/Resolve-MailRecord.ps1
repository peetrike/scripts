#Requires -Version 5.1
#Requires -Modules Indented.Net.Dns

<#PSScriptInfo
    .VERSION 0.1.4
    .GUID 44df3732-f427-452b-bfe3-cce783102778

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2021.  All rights reserved.

    .TAGS dns, e-mail, PSEdition_Core, PSEdition_Desktop, Windows

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [0.1.4] - 2023.04.18 - refactor DKIM record queries
        [0.1.3] - 2023.04.18 - Add DKIM specific records
        [0.1.2] - 2021.12.31 - Moved script to Github
        [0.1.0] - 2020.09.04 - changed dependent module to make script compatible with PowerShell 7
        [0.0.2] - 2020.03.30 - Added DKIM record collection
        [0.0.1] - 2020.03.27 - Initial release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Returns mail-related DNS records for specified domain
    .DESCRIPTION
        Returns e-mail related DNS records for specified domain in object format.
    .EXAMPLE
        Resolve-MailRecord -Name telia.ee

        Returns MX and associated records for specified domain
    .EXAMPLE
        Get-Content domains.txt | Resolve-MailRecord

        Returns MX and associated records for all names in domains.txt file.
    .INPUTS
        List of names to resolve
    .OUTPUTS
        Found DNS records
    .NOTES
        The returned records are:
        * MX records
        * A/AAAA records of names mentioned in MX records
        * TXT records for SPF (records that start with 'v=spf')
        * TXT records for DMARC (_dmarc.doamin)
        * DKIM records (selector1._domainkey and selector2._domainkey)
    .LINK
        Get-Dns https://github.com/indented-automation/Indented.Net.Dns/blob/master/Indented.Net.Dns/help/Get-Dns.md
#>

[CmdLetBinding()]
Param(
        [parameter(
            Mandatory,
            ValueFromPipeline
        )]
        [Alias('Domain')]
        [string[]]
    $Name
)

process {
    foreach ($SingleName in $Name) {
        Write-Verbose -Message ('Processing name: {0}' -f $SingleName)
        $result = Get-Dns -Name $SingleName -Type MX
        $result.Answer
        $result.Additional

        (Get-Dns -Name $SingleName -Type TXT).Answer |
            Where-Object Text -like 'v=spf*'

        $DmarkRecord = '_dmarc', $SingleName -join '.'
        (Get-Dns -Name $DmarkRecord -Type TXT).Answer

        $NameList = 1, 2 | ForEach-Object { 'selector{0}._domainkey.{1}' -f $_, $SingleName }
        ($NameList | Get-Dns -Type ANY).Answer
    }
}

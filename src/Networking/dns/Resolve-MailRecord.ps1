#Requires -Version 5.1
#Requires -Modules Indented.Net.Dns

<#PSScriptInfo
    .VERSION 0.1.0
    .GUID 44df3732-f427-452b-bfe3-cce783102778

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2020.  All rights reserved.

    .TAGS dns, e-mail, PSEdition_Core, PSEdition_Desktop, Windows

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://bitbucket.atlassian.teliacompany.net/projects/PWSH/repos/scripts/
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
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
        PS C:\> Resolve-MailRecord -Name telia.ee

        Returns MX and associated records for specified domain

    .EXAMPLE
        PS C:\> Get-Content domains.txt | Resolve-MailRecord

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

    .LINK
        PoshNet module: https://www.powershellgallery.com/packages/poshnet/
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
        $result = Get-Dns -Name $SingleName -Type MX
        $result.Answer
        $result.Additional

        (Get-Dns -Name $SingleName -Type TXT).Answer |
            Where-Object Text -like 'v=spf*'

        $NameList = '_dmarc', '_domainkey' | ForEach-Object { '{0}.{1}' -f $_, $SingleName }
        ($NameList | Get-Dns -Type TXT).Answer
    }
}

#Requires -Version 2.0
#Requires -Modules ActiveDirectory

<#PSScriptInfo
    .VERSION 1.0.1
    .GUID 03ed78db-cabd-4969-b6dd-092cd2f31e7a

    .AUTHOR CPG4285
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2022.  All rights reserved.

    .TAGS ActiveDirectory, AD, Certificate, update

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES ActiveDirectory
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.0.1] - 2022.05.12 - Add ActiveDirectory module as external reference
        [1.0.0] - 2022.05.12 - Initial release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Update ID Card certificate reference in user objects
    .DESCRIPTION
        This script will find AD user objects with ID Card certificate reference
        and updates them to support KB5014754 update for Window Server
    .PARAMETER Whatif
        Shows what would happen if the script runs. The changes will not be saved.
    .PARAMETER Confirm
        Prompts you for confirmation before making changes.
    .EXAMPLE
        Update-SKCertificateReference.ps1 -LeaveExisting
#>

[CmdletBinding(
    SupportsShouldProcess = $true
)]
Param(
        [switch]
        # if there are existing mappings, leave them intact
    $LeaveExisting
)

function ConvertTo-ReversePath {
    param (
            [parameter(
                Mandatory = $true
            )]
            [string]
        $Path
    )

    $PathList = $Path -split ', '
    [array]::Reverse($PathList)
    $PathList -join ','
}

function ConvertTo-ReverseSN {
    param (
            [parameter(
                Mandatory = $true
            )]
            [string]
        $SerialNumber
    )

    $bytes = $SerialNumber -split '(?<=\G.{2})' | Where-Object { $_ }
    [array]::Reverse($bytes)
    -join $bytes
}

Add-Type -AssemblyName System.DirectoryServices.Protocols

$LDAPDirectoryService = 'esteid.ldap.sk.ee:636'
$LDAPServer = New-Object System.DirectoryServices.Protocols.LdapConnection $LDAPDirectoryService

$LDAPServer.AuthType = [DirectoryServices.Protocols.AuthType]::Anonymous
$LDAPServer.SessionOptions.ProtocolVersion = 3
$LDAPServer.SessionOptions.SecureSocketLayer = $True

# Import-Module ActiveDirectory

$DomainDN = 'dc=ESTEID,c=EE'
$Scope = [DirectoryServices.Protocols.SearchScope]::Subtree
$AttributeList = @('usercertificate;binary')

$PnoFilter = ',SERIALNUMBER=(?<PNO>\d{11})$'
$AdFilter = { altSecurityIdentities -like '*' -and Enabled -eq $true }
$ConfirmProps = @{
    Confirm = $false
    WhatIf  = $false
}

foreach ($Account in Get-ADUser -Filter $AdFilter -Properties altSecurityIdentities) {
    Write-Verbose -Message ('Processing user: {0}' -f $account.UserPrincipalName)
    if ($Account.altSecurityIdentities | Where-Object { $_ -match $PnoFilter }) {
        $PNO = $Matches.PNO

        Write-Verbose -Message ('  Using PNO value: {0}' -f $PNO)

        $LDAPFilter = '(serialNumber=PNOEE-{0})' -f $PNO
        $SearchRequest = New-Object System.DirectoryServices.Protocols.SearchRequest -ArgumentList @(
            $DomainDN
            $LDAPFilter
            $Scope
            $AttributeList
        )

        try {
            $certResponse = $LDAPServer.SendRequest($SearchRequest)
        } catch {
            Write-Error $_.Exception.Message -ErrorAction Stop
        }

        $CertList = $certResponse.Entries |
            Where-Object { $_.DistinguishedName -match 'ou=Authentication,o=(Identity|Digital|Residence card)' }

        if ($CertList) {
            if (-not $LeaveExisting.IsPresent) {
                Set-ADUser -Identity $Account -Clear 'altSecurityIdentities'
            }

            foreach ($UserCert in $CertList.Attributes['usercertificate;binary']) {
                $cert = [Security.Cryptography.X509Certificates.X509Certificate2] $UserCert
                Write-Verbose -Message ('  Found certificate with subject: {0}' -f $Cert.Subject)

                    # Certain fields, such as Issuer, Subject, and SerialNumber, are reported in a "forward" format
                $issuer = ConvertTo-ReversePath $cert.Issuer
                $Serial = ConvertTo-ReverseSN $cert.SerialNumber

                $altSecurityIdentity = 'X509:<I>{0}<SN>{1}' -f $issuer, $Serial

                if ($PSCmdlet.ShouldProcess($Account.samAccountName, 'Add Name Mapping')) {
                    Set-ADUser -Identity $Account @ConfirmProps -Add @{
                        'altSecurityIdentities' = $altSecurityIdentity
                    }
                        # Output the reference for changed object
                    New-Object -TypeName PSCustomObject -Property @{
                        UPN      = $Account.UserPrincipalName
                        PNO      = $PNO
                        Identity = $altSecurityIdentity
                    }
                }
            }
        } else {
            Write-Warning -Message (
                '  No suitable certificates found from {0}, skipping' -f $LDAPDirectoryService.split(':')[0]
            )
        }
    }
}

#Requires -Version 2.0
#Requires -Modules ActiveDirectory

<#PSScriptInfo
    .VERSION 1.3.0
    .GUID a3b444d6-9e92-4f51-a8dc-dbd5aa155eea

    .AUTHOR Jaanus Jõgisu
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2025.  All rights reserved.

    .TAGS ActiveDirectory, AD, Certificate, import
    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES ActiveDirectory
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.3.0] - 2025.12.10 - Added second LDAP server to search from.
        [1.2.1] - 2022.11.14 - Updated SerialNumber AltIdentity string.
        [1.2.0] - 2022.05.12 - Added LeaveExisting parameter
        [1.1.0] - 2022.05.12 - Changed alternate certificate mapping to use
                               SerialNumber instead of Subject, by default
        [1.0.3] - 2021.12.31 - moved script to Github
        [1.0.2] - 2019.12.17 - added support for Residence card of long-term resident
        [1.0.1] - 2019.10.08 - changed:
            - if there is no value in $IdProperty, a warning is showed and script moves to next user
            - clearing of alternate identities is only performed, if new identity is discovered
            - a warning is showed, if no certificates found in LDAP repository
        [1.0.0] - 2019.10.08 - Initial release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Adds ID Card Certificate Name Mapping to AD user account.
    .DESCRIPTION
        This script finds certificates from esteid.ldap.sk.ee and ldap.eidpki.ee,
        based on user Personal Identity Code and adds certificate Name mapping to
        AD user account.

        It is assumed that Personal Identity Code is stored in AD user account
        attribute provided by IdProperty parameter (by default 'pager').
    .PARAMETER WhatIf
        Shows what would happen if the script runs. The changes will not be saved.
    .PARAMETER Confirm
        Prompts you for confirmation before making changes.
    .EXAMPLE
        Import-SKCertificate.ps1 -ADUser user -UseSubject

        This example adds certificate mappings to AD User account called user.
        The certificate mapping will use Subject attribute reference

    .EXAMPLE
        Get-ADUser -filter {Name -like 'user*'} | Import-SKCertificate.ps1 -IdProperty EmployeeId

        This example adds certificate mappings to several AD User accounts
        that are found by Get-ADUser cmdlet and passed to script through pipeline.
        Script uses AD user property EmployeeId to obtain Personal Identity Code
    .INPUTS
        None or Microsoft.ActiveDirectory.Management.ADUser

        AD User object is received by the ADUser parameter.
    .LINK
        Get-ADUser
        Set-ADUSer
    .NOTES
        Created by Jaanus Jõgisu
        Modified by Meelis Nigols
#>

[CmdletBinding(
    SupportsShouldProcess = $true
)]
param (
        [Parameter(
            Mandatory = $True,
            Position = 1,
            HelpMessage = 'Please enter AD user name',
            ValueFromPipeline = $True
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.ActiveDirectory.Management.ADUser]
        # Specifies an Active Directory user object to process.
    $ADUser,
        [string]
        # Specifies AD user object property, where PNO value is stored.
    $IdProperty = 'pager',
        [switch]
        # Use Subject reference instead of SerialNumber reference.
    $UseSubject,
        [switch]
        # if there are existing mappings, leave them intact
    $LeaveExisting
)

begin {
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

    $ConnectionData = @(
        [PSCustomObject] @{
            Fqdn       = 'esteid.ldap.sk.ee'
            DN         = 'dc=ESTEID,c=EE'
            Connection = $null
        }
        [PSCustomObject] @{
            Fqdn       = 'ldap.eidpki.ee'
            DN         = 'dc=ldap,dc=eidpki,dc=ee'
            Connection = $null
        }
    )
    foreach ($connection in $connectiondata) {
        $serverIdentifier = New-Object -TypeName DirectoryServices.Protocols.LdapDirectoryIdentifier -ArgumentList @(
            $Connection.Fqdn,
            636
        )
        $ldapConnection = New-Object -TypeName DirectoryServices.Protocols.LdapConnection -ArgumentList $ServerIdentifier
        $ldapConnection.AuthType = [DirectoryServices.Protocols.AuthType]::Anonymous
        $ldapConnection.SessionOptions.ProtocolVersion = 3
        $ldapConnection.SessionOptions.SecureSocketLayer = $true
        $Connection.Connection = $ldapConnection
    }

    $Scope = [DirectoryServices.Protocols.SearchScope]::Subtree
    $AttributeName = 'usercertificate;binary'
    $MappingAttribute = 'altSecurityIdentities'
    $ConfirmProps = @{
        Confirm = $false
        WhatIf  = $false
    }
}

process {
    $userAccount = Get-ADUser -Identity $ADUser -Properties $IdProperty
    $UserPrincipalName = $userAccount.UserPrincipalName
    Write-Verbose -Message ('Processing user account: {0}' -f $UserPrincipalName)

    $PNO = $userAccount.$IdProperty
    if (-not $PNO) {
        $ErrorProps = @{
            Message = 'User: {0} - PNO value not found in attribute "{1}", skipping' -f
                $UserPrincipalName, $IdProperty
        }
        Write-Warning @ErrorProps
    } else {
        Write-Verbose -Message ('Using PNO code: {0}' -f $PNO)
        $LdapQuery = '(serialNumber=PNOEE-{0})' -f $PNO
        $CertList = foreach ($connection in $ConnectionData) {
            $SearchRequest = New-Object DirectoryServices.Protocols.SearchRequest -ArgumentList @(
                $connection.DN
                $LdapQuery
                $Scope
                @($AttributeName)
            )

            try {
                $QueryResult = $Connection.Connection.SendRequest($SearchRequest)
            } catch {
                Write-Error $_.Exception.Message
                continue
            }
            $QueryResult.Entries |
                Where-Object {
                    $_.DistinguishedName -match 'ou=Authentication,o=(Identity|Digital|Residence card)'
                }
        }

        if ($CertList) {
            if (-not $LeaveExisting.IsPresent) {
                Set-ADUser -Identity $userAccount -Clear $MappingAttribute
            }

            foreach ($UserCert in $CertList.Attributes[$AttributeName]) {
                $cert = [Security.Cryptography.X509Certificates.X509Certificate2] $UserCert
                Write-Verbose -Message ('Found certificate with subject: {0}' -f $Cert.Subject)

                    # Certain fields, such as Issuer, Subject, and SerialNumber, are reported in a "forward" format
                    $issuer = ConvertTo-ReversePath $cert.Issuer
                    $altSecurityIdentity = 'X509:<I>{0}' -f $issuer
                    if ($UseSubject) {
                        $subject = ConvertTo-ReversePath $cert.Subject
                        $altSecurityIdentity += '<S>{0}' -f $subject
                    } else {
                        $Serial = ConvertTo-ReverseSN $cert.SerialNumber
                        $altSecurityIdentity += '<SR>{0}' -f $Serial
                    }

                if ($PSCmdlet.ShouldProcess($UserPrincipalName, 'Add Name Mapping')) {
                    Set-ADUser -Identity $userAccount @ConfirmProps -Add @{
                        $MappingAttribute = $altSecurityIdentity
                    }

                        # Output the reference for changed object
                    New-Object -TypeName PSCustomObject -Property @{
                        UPN      = $UserPrincipalName
                        PNO      = $PNO
                        Identity = $altSecurityIdentity
                    }
                }
            }
        } else {
            Write-Warning -Message (
                'User: {0} - no certificates found, skipping' -f $UserPrincipalName
            )
        }
    }
}

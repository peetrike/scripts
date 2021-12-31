#Requires -Version 2.0
#Requires -Modules ActiveDirectory

<#PSScriptInfo
    .VERSION 1.0.3
    .GUID a3b444d6-9e92-4f51-a8dc-dbd5aa155eea

    .AUTHOR Jaanus Jõgisu
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2021.  All rights reserved.

    .TAGS ActiveDirectory, AD, Certificate, import
    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES ActiveDirectory
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
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
        This script finds certificates from esteid.ldap.sk.ee based on user
        Personal Identity Code and adds certificate Name mapping to
        AD user acccount.

        It is assumed that Personal Identity Code is stored in AD user account
        attribute provided by IdProperty parameter (by default 'pager').
    .PARAMETER Whatif
        Shows what would happen if the script runs. The changes will not be saved.
    .PARAMETER Confirm
        Prompts you for confirmation before making changes.
    .EXAMPLE
        Import-SKCertificate.ps1 -ADUser user

        This command adds certificate mappings to AD User account called user

    .EXAMPLE
        Get-ADUser -filter {Name -like 'user*'} | Import-SKCertificate.ps1 -IdProperty EmployeeId

        This command adds certificate mappings to several AD User accounts
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

[cmdletbinding(
    SupportsShouldProcess = $True
)]
param(
        [Parameter(
            Mandatory = $True,
            Position = 1,
            HelpMessage = "Please enter AD user name",
            ValueFromPipeline = $True
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.ActiveDirectory.Management.ADUser]
        # Specifies an Active Directory user object to process.
    $ADUser,
        [string]
        # specifies AD user object property, where Personal Identity Code is stored.
    $IdProperty = 'pager'
)

begin {
    Function Reevers([string]$what) {
        $paths = $what -split ', '
        [array]::Reverse($paths)
        return $paths -join ','
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
}

process {
    $userAccount = Get-ADUser -Identity $ADUser -Properties $IdProperty
    Write-Verbose -Message ('Processing user account: {0}' -f $userAccount.samAccountName)
    $Isikukood = $userAccount.$IdProperty
    if (-not $Isikukood) {
        $ErrorProps = @{
            Message = 'User: {0} - Personal ID Code not found in attribute "{1}", skipping' -f $ADUser.Name, $IdProperty
        }
        Write-Warning @ErrorProps
    } else {
        Write-Verbose -Message ('Using ID code: {0}' -f $Isikukood)

        $LDAPFilter = '(serialNumber=PNOEE-{0})' -f $Isikukood
        $searchRequestProps = @(
            $DomainDN
            $LDAPFilter
            $Scope
            $AttributeList
        )
        $SearchRequest = New-Object System.DirectoryServices.Protocols.SearchRequest -ArgumentList $searchRequestProps

        try {
            $certResponse = $LDAPServer.SendRequest($SearchRequest)
        } catch {
            Write-Error $_.Exception.Message -ErrorAction Stop
        }

        $CertList = $certResponse.Entries |
            Where-Object { $_.DistinguishedName -match 'ou=Authentication,o=(Identity|Digital|Residence card)' }

        if ($CertList) {
            if ($PSCmdlet.ShouldProcess($userAccount.samAccountName, 'Clear old Name Mappings')) {
                Set-ADUser -Identity $userAccount -Clear 'altsecurityidentities'
            }

            foreach ($UserCert in $CertList.Attributes.'usercertificate;binary') {
                $cert = [Security.Cryptography.X509Certificates.X509Certificate2]$UserCert
                Write-Verbose -Message ('Found certificate with subject: {0}' -f $Cert.Subject)

                    # Active Directory ootab <I>.<S> ridasid teistpidi kui sertifikaadist lugedes
                $issuer = Reevers $cert.Issuer
                $subject = Reevers $cert.Subject

                    # Ehitame Active Directory jaoks sobiva lause
                $altSecurityIdentity = 'X509:<I>{0}<S>{1}' -f $issuer, $subject
                # Write-Verbose -Message ('Using AltSecurityIndentity: {0}' -f $altSecurityIdentity)

                if ($PSCmdlet.ShouldProcess($userAccount.samAccountName, 'Add Name Mapping')) {
                        # Määrame AD kasutaja Name Mappings väljale saadud väärtuse
                    Set-ADUser -Identity $userAccount -Add @{'altsecurityidentities' = $altSecurityIdentity }
                    Write-Output ("Name Mapping added to user: {0}, {1}" -f $userAccount.Name, $userAccount.$IdProperty)
                }
            }
        } else {
            Write-Warning -Message ('User: {0} - no certificates found from {1}, skipping' -f $userAccount.samAccountName, $LDAPDirectoryService.split(':')[0])
        }
    }
}

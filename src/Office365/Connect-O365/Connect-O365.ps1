#Requires -Version 5.1

<#PSScriptInfo
    .VERSION 0.5.3
    .GUID 6716a06d-01af-4654-acec-bfe28e1214b6

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2020.  All rights reserved.

    .TAGS office365 connect PSEdition_Desktop Windows

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES AzureAD, MSOnline, ExchangeOnlineManagement, Microsoft.Online.SharePoint.PowerShell, MicrosoftTeams

    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES https://github.com/peetrike/scripts/blob/master/src/Office365/Connect-O365/CHANGELOG.md

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Connect to Office 365 admin interfaces with Powershell
    .DESCRIPTION
        Connect to Office 365 admin interfaces with Powershell
    .EXAMPLE
        Connect-O365.ps1 -u user -p password

        This command connects to Office 365 admin interfaces using specified username and password
    .EXAMPLE
        Connect-O365.ps1 -UserName user@domain -TenantId e8988cb2-c355-4cae-aa9f-b1fad3163551

        This command connects to Office 365 admin interfaces using specified username and TenantID.
        The interactive authentication is automatically used.
    .NOTES
        Exchange and Security & Compliance Center connections use ExO v2 module, if available
        SharePoint Online only uses Microsoft.Online.SharePoint.PowerShell module
        Teams only uses MicrosoftTeams module

        When using interactive authentication, both AzureAD and SharePoint modules require manually entering credentials.
        When omitting password, the MSOnline module requires interactive authentication.
    .LINK
        https://docs.microsoft.com/microsoft-365/enterprise/connect-to-all-microsoft-365-services-in-a-single-windows-powershell-window
#>

[CmdletBinding(
    DefaultParameterSetName = 'Specific'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingPlainTextForPassword', '',
    Justification = 'Password is taken from RDM as plain text'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingConvertToSecureStringWithPlainText', '',
    Justification = 'Password is taken from RDM as plain text'
)]
param (
        [parameter(
            Mandatory
        )]
        [ValidateNotNullorEmpty()]
        [Alias('u')]
        [String]
        # Specify user name for authentication
    $UserName,
        [ValidateNotNullorEmpty()]
        [Alias('p')]
        [String]
        # Specify Password for authentication.
        # When omitted, interactive authentication is assumed.
    $Password,
        [guid]
        # Specify Azure AD Tenant Id to connect to.  Without this parameter,
        # the connection is established to the tenant where logged on user is from.
    $TenantId,
        [switch]
        # Specifies that authentication uses separate window, performing MFA authentication, if required.
    $Interactive,
        [parameter(
            Mandatory,
            ParameterSetName = 'All'
        )]
        [switch]
        # specify that all connections should be loaded
    $All,
        [parameter(
            ParameterSetName = 'Specific'
        )]
        [ValidateSet('AzureAD', 'MSOnline')]
        [string[]]
        # Specify Azure AD modules to load.  Possible values:
        # - AzureAD
        # - MSOnline
    $AdModule = @('AzureAD', 'MSOnline'),
        [parameter(
            ParameterSetName = 'Specific'
        )]
        [switch]
        # Add Exchange Online connection
    $Exchange,
        [parameter(
            ParameterSetName = 'Specific'
        )]
        [switch]
        # Add Office365 Security & Compliance Center connection
    $CC,
        [parameter(
            ParameterSetName = 'Specific'
        )]
        [switch]
        # Add SharePoint Online connection
    $SharePoint,
        [parameter(
            ParameterSetName = 'Specific'
        )]
        [switch]
        # Add Teams connection
    $Teams
)

$Host.UI.RawUI.WindowTitle = ('Office365 Admin: {0}' -f $UserName)

if ($Password) {
    Write-Debug -Message ('Name: {0}, password: {1}' -f $UserName, $Password)
    $SecurePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
    $LiveCred = [pscredential]::new($UserName, $SecurePassword)
} else {
    Write-Warning -Message 'Using interactive logon, prepare to enter credentials'
    $Interactive = $true
}

#region Load Azure AD Module(s)
if ($PSVersionTable.PSVersion.Major -lt 6) {
    switch ($AdModule) {
        'AzureAD' {
            try {
                Import-Module AzureAD -Verbose:$false -ErrorAction Stop
                Write-Verbose -Message 'Loading module AzureAD'
                $ConnectionProps = @{}
                if ($TenantId) {
                    $ConnectionProps.TenantId = $TenantId
                }
                if ($Interactive) {
                    Write-Warning -Message 'Connecting to Azure AD with interactive authentication'
                    Connect-AzureAD @ConnectionProps
                } else {
                    $ConnectionProps.Credential = $LiveCred
                    try {
                        Connect-AzureAD @ConnectionProps -Verbose:$false -ErrorAction Stop
                    } catch [Microsoft.Open.Azure.AD.CommonLibrary.AadAuthenticationFailedException] {
                        if ($TenantId) {
                            Write-Warning -Message 'Trying again, using interactive authentication'
                            $Interactive = $true
                            Connect-AzureAD -TenantId $TenantId
                        } else {
                            Write-Error -ErrorRecord $_
                        }
                    }
                }
            } catch {
                Write-Warning -Message 'Module AzureAD is not installed, skipping'
            }
        }
        'MSOnline' {
            try {
                Write-Verbose -Message 'Loading module MSOnline'
                Import-Module MsOnline -Verbose:$false -ErrorAction Stop
                if ($Password) {
                    Connect-MsolService -Credential $LiveCred -Verbose:$false
                } else {
                    Write-Warning -Message 'Connecting MSOnline with interactive authentication'
                    Connect-MsolService
                }
                if ($TenantId) {
                    Get-MsolPartnerContract -All |
                        Where-Object TenantId -EQ $TenantId |
                        Select-Object Name, TenantId, DefaultDomainName
                }
            } catch {
                Write-Warning -Message 'Module MSOnline is not installed, skipping'
            }
        }
    }
}
#endregion

#region Common parameters for next connections
try {
    $null = Get-AzureADCurrentSessionInfo -ErrorAction Stop
    $DomainList = (Get-AzureADTenantDetail).VerifiedDomains
        #$DefaultDomain = ($DomainList | Where-Object _Default).Name
    $InitialDomain = ($DomainList | Where-Object Initial).Name
} catch {
    if (Get-Module MSOnline) {
        $DomainProps = @{}
        if ($TenantId) {
            $DomainProps.TenantID = $TenantId
        }
        $InitialDomain = (Get-MsolDomain @DomainProps | Where-Object IsInitial).Name
    }
}

if ($TenantId -and $InitialDomain) {
    $orgName = $InitialDomain.split('.')[0]
    $ExConnectionUrl = 'https://ps.outlook.com/powershell-liveid?DelegatedOrg={0}' -f $InitialDomain
    $CcConnectionUrl =
        'https://ps.compliance.protection.outlook.com/powershell-liveid?DelegatedOrg={0}' -f $InitialDomain
} else {
    $orgName = ''
    $ExConnectionUrl = 'https://outlook.office365.com/powershell-liveid/'
    $CcConnectionUrl = 'https://ps.compliance.protection.outlook.com/powershell-liveid/'
}

$SessionParams = @{
    Authentication   = 'Basic'
    Credential       = $LiveCred
    AllowRedirection = $true
}
#endregion

#region Connect to Exchange Online
if ($Exchange.IsPresent -or $All.IsPresent) {
    try {
        Import-Module ExchangeOnlineManagement -Verbose:$false -ErrorAction Stop
        Write-Verbose -Message 'Connecting using EXO v2 module'
        $ConnectionProps = @{}
        if ($Interactive) {
            Write-Warning -Message 'Connecting to Exchange using interactive authentication'
            $ConnectionProps.UserPrincipalName = $UserName
        } else {
            $ConnectionProps.Credential = $LiveCred
        }
        if ($TenantId) { $ConnectionProps.DelegatedOrganization = $InitialDomain }
        Connect-ExchangeOnline @ConnectionProps -ShowBanner:$false
    } catch {
        if ($Interactive) {
            Write-Warning -Message 'Interactive logon used, skipping Exchange connection'
        } else {
            if ($_.Exception.GetType().Name -like 'FileNotFoundException') {
                Write-Warning -Message 'EXO v2 module not available, importing direct PS session'
            } else {
                Write-Warning -Message "EXO v2 module couldn't connect, trying direct PS session"
            }
            Write-Verbose -Message ('Using connection URI: {0}' -f $ExConnectionUrl)
            $SessionParams.ConnectionUri = $ExConnectionUrl
            $SessionParams.ConfigurationName = 'Microsoft.Exchange'
            $Session = New-PSSession @SessionParams -Verbose:$false
            $null = Import-PSSession $Session -DisableNameChecking -Verbose:$false
        }
    }
}
#endregion

#region Connect to Security & Compliance Center
if ($CC.IsPresent -or $all.IsPresent) {
    try {
        Import-Module ExchangeOnlineManagement -Verbose:$false -ErrorAction Stop
        Write-Verbose -Message 'Connecting to Compliance Center using EXO v2 module'
        $ConnectionProps = @{}
        if ($Interactive) {
            Write-Warning -Message 'Connecting to Compliance Center using interactive authentication'
            $ConnectionProps.UserPrincipalName = $UserName
        } else {
            $ConnectionProps.Credential = $LiveCred
        }
        Connect-IPPSSession @ConnectionProps -ErrorAction Stop
    } catch {
        if ($Interactive) {
            Write-Warning -Message 'Interactive logon used, skipping Control Center connection'
        } else {
            if ($_.Exception.GetType().Name -like 'FileNotFoundException') {
                Write-Warning -Message 'EXO v2 module not available, importing direct Compliance Center session'
            } else {
                Write-Warning -Message "EXO v2 module couldn't connect, trying direct Compliance Center session"
            }
            $SessionParams.Remove('ConfigurationName')
            Write-Verbose -Message ('Using connection URI: {0}' -f $CcConnectionUrl)
            $SessionParams.ConnectionUri = $CcConnectionUrl
            $Session = New-PSSession @SessionParams -Verbose:$false
            $null = Import-PSSession $Session -DisableNameChecking -Prefix cc -Verbose:$false
        }
    }
}
#endregion

#region Connect to SharePoint Online
if ($SharePoint.IsPresent -or $all.IsPresent) {
    if (Get-Module Microsoft.Online.SharePoint.PowerShell -ListAvailable -ErrorAction SilentlyContinue) {
        Import-Module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking -Verbose:$false
        if ($orgName) {
            $ConnectionProps = @{
                Url = 'https://{0}-admin.sharepoint.com' -f $orgName
            }
            if ($Interactive) {
                Write-Warning -Message 'Connecting to Sharepoint using interactive authentication'
            } else {
                $ConnectionProps.Credential = $LiveCred
            }
            Connect-SPOService @ConnectionProps
        } else {
            Write-Warning -Message 'Cannot decide organization name, skipping SharePoint'
        }
    } else {
        Write-Warning -Message 'SharePoint Online module is not installed'
    }
}
#endregion

#region Connect to Teams
if ($Teams.IsPresent -or $all.IsPresent) {
    try {
        Import-Module MicrosoftTeams -Verbose:$false -ErrorAction Stop
        $ConnectionProps = @{}
        if ($Interactive) {
            Write-Warning -Message 'Connecting to Teams with interactive authentication'
        } else {
            $ConnectionProps.Credential = $LiveCred
        }
        if ($TenantId) {
            $ConnectionProps.TenantID = $TenantId
        }
        Connect-MicrosoftTeams @ConnectionProps -Verbose:$false
    } catch {
        Write-Warning -Message 'Teams module is not installed, skipping'
    }
}
#endregion

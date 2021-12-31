#Requires -Version 3.0

<#PSScriptInfo
    .VERSION 1.0.4

    .GUID c90c7ea2-93e3-4d19-881f-e4defc7c73c8

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2021.  All rights reserved.

    .TAGS office365 report

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://bitbucket.atlassian.teliacompany.net/projects/PWSH/repos/scripts/
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.0.4] - 2021.12.28 - refactor script:
            - use existing connection to Exchange Online, when available.
            - use ExchangeOnline module, when available.
        [1.0.3] - added missing parameter names
        [1.0.2] - changed Import-PSSession so that it imports only required cmdlets
        [1.0.1] - Initial release with documentation
    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Generate shared mailbox permission report
    .DESCRIPTION
        This script generates Office 365 Shared Mailbox permission holders report.
        Report is saved as one .csv file or separate .csv file for each shared mailbox.

        When you haven't already established connection to Exchange Online, the
        Credential parameter is required to connect to Exchange Online.
    .EXAMPLE
        Get-SharedMailboxReport -Credential $MyCredential

        This example uses previously obtained credential variable.
    .EXAMPLE
        Get-SharedMailboxReport -OutputFile Multiple

        This example generates separate report for each mailbox.
    .EXAMPLE
        Get-SharedMailboxReport -Filter "Name -like 'Mailbox1'"

        This example uses custom filter to get list of shared mailboxes
    .INPUTS
        None
    .OUTPUTS
        None
    .NOTES
        You need to be assigned permissions before you can run this script.
        To find the permissions required to run any cmdlet or parameter in your
        organization, see Find the permissions required to run any Exchange
        cmdlet (https://docs.microsoft.com/powershell/exchange/find-exchange-cmdlet-permissions).
    .LINK
        Get-Mailbox: https://docs.microsoft.com/powershell/module/exchange/get-mailbox
    .LINK
        Get-Recipient: https://docs.microsoft.com/powershell/module/exchange/get-recipient
    .LINK
        Get-MailboxPermission: https://docs.microsoft.com/powershell/module/exchange/get-mailboxpermission
    .LINK
        Get-RecipientPermission: https://docs.microsoft.com/powershell/module/exchange/get-recipientpermission
    .LINK
        Filterable properties for the Filter parameter: https://docs.microsoft.com/powershell/exchange/filter-properties
#>

[CmdletBinding()]
param (
        [string]
        # The Filter parameter indicates the OPath filter used to filter recipients.
        # For more information about the filterable properties, see Filterable properties for the
        # -Filter parameter (https://docs.microsoft.com/powershell/exchange/filter-properties).
    $Filter,
        [parameter(
            HelpMessage = 'Enter credential for Office365 tenant'
        )]
        [System.Management.Automation.Credential()]
        [PSCredential]
        # The Credential parameter specifies the user name and password that's used to connect Office 365.
        # The used credential needs to have assigned permissions on Office 365 tenant you are using
        # to generate report.
    $Credential,
        [ValidateSet('Single', 'Multiple')]
        [string]
        # Specifies whether to create single report file or separate file for every shared mailbox.
        # The default is single file.
    $OutputFile = 'Single'
)

try {
    $null = Get-Command Get-Mailbox -ErrorAction Stop
    Write-Verbose -Message 'Connection already established'
} catch {
    if (-not $Credential) {
        $Credential = Get-Credential -Message 'Enter credential for Office365 tenant'
    }

    if (Get-Module ExchangeOnlineManagement -ListAvailable) {
        Write-Verbose -Message 'Connecting using EXO v2 module'
        Import-Module ExchangeOnlineManagement -Verbose:$false
        Connect-ExchangeOnline -Credential $Credential -ShowBanner:$false
    } else {
        Write-Warning -Message 'EXO v2 module not available, importing direct PS session'
        $SessionProps = @{
            ConfigurationName = 'Microsoft.Exchange'
            ConnectionUri     = 'https://outlook.office365.com/powershell-liveid/'
            Credential        = $Credential
            Authentication    = 'Basic'
        }
        $Session = New-PSSession @SessionProps -AllowRedirection
        $CmdList = @(
            'Get-Mailbox'
            'Get-MailboxPermission'
            'Get-Recipient'
            'Get-RecipientPermission'
        )
        $null = Import-PSSession -Session $Session -DisableNameChecking -CommandName $CmdList -Verbose:$false
    }
}

<# if (Get-Module ExchangeOnlineManagement -ListAvailable) {
    $MbCommand = Get-Command Get-EXOMailbox
    $MbpCommand = Get-Command Get-EXOMailboxPermission
    $RCommand = Get-Command Get-EXORecipient
    $RpCommand = Get-Command Get-EXORecipientPermission
} else {
    $MbCommand = Get-Command Get-Mailbox
    $MbpCommand = Get-Command Get-MailboxPermission
    $RCommand = Get-Command Get-Recipient
    $RpCommand = Get-Command Get-RecipientPermission
} #>

$CsvProps = @{
    UseCulture        = $true
    Encoding          = 'utf8'
    NoTypeInformation = $true
}

$MailboxProps = @{
    ResultSize           = 'Unlimited'
    RecipientTypeDetails = 'SharedMailbox'
}
if ($Filter) {
    $MailboxProps.Filter = $Filter
}

$SharedMailboxName = @{
    Name       = 'SharedMailbox'
    Expression = { $mailbox.DisplayName }
}

foreach ($mailbox in Get-Mailbox @MailboxProps) {
    Write-Verbose -Message ('Processing mailbox: {0}' -f $mailbox.DisplayName)

    $AllPermissions = @(
        Get-MailboxPermission -Identity $mailbox.DistinguishedName |
            Where-Object { -not $_.Deny -and $_.AccessRights -Contains 'FullAccess' } |
            ForEach-Object {
                Get-Recipient -Identity $_.User -ErrorAction SilentlyContinue
            } |
            Select-Object -Property $SharedMailboxName, Name, Alias, PrimarySmtpAddress, RecipientType, @{
                Name       = 'Permission'
                Expression = { 'Full Access' }
            }

        Get-RecipientPermission -Identity $mailbox.DistinguishedName |
            Where-Object AccessControlType -Like 'Allow' |
            ForEach-Object {
                Get-Recipient -Identity $_.Trustee -ErrorAction SilentlyContinue
            } |
            Select-Object -Property $SharedMailboxName, Name, Alias, PrimarySmtpAddress, RecipientType, @{
                Name       = 'Permission'
                Expression = { 'Send As' }
            }

        $mailbox.GrantSendOnBehalfTo |
            ForEach-Object {
                Get-Recipient -Identity $_ -ErrorAction SilentlyContinue
            } |
            Select-Object -Property $SharedMailboxName, Name, Alias, PrimarySmtpAddress, RecipientType, @{
                Name       = 'Permission'
                Expression = { 'Send on behalf' }
            }
    )

    switch ($OutputFile) {
        'Single' {
            $CsvProps.Path = 'AllSharedMailboxReport.csv'
            $AllPermissions | Export-Csv @CsvProps -Append
        }
        'Multiple' {
            if ($AllPermissions) {
                $CsvProps.Path = ('{0}.csv' -f $mailbox.Name)
                $AllPermissions | Export-Csv @CsvProps
            }
        }
    }
}

if ($Session) {
    Remove-PSSession -Session $Session
}

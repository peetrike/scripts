#Requires -Version 5.1
#Requires -Modules msal.ps

<#PSScriptInfo
    .VERSION 0.0.2
    .GUID 4d52a386-e0c5-4177-9476-f0beefe604a1

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2021.  All rights reserved.

    .TAGS graph, api

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES msal.ps
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [0.0.2] - 2021.12.31 - Moved script to Github.

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Invoke Microsoft Graph query

    .DESCRIPTION
        Longer Description

    .EXAMPLE
        PS C:\> Invoke-MSGraphQuery
        Explanation of what the example does

    .INPUTS
        Inputs (if any)

    .OUTPUTS
        Output (if any)

    .NOTES
        General notes

    .LINK
        Powershell Online Help: https://microsoft.com/powershell
#>

[CmdletBinding(
    SupportsShouldProcess
)]
[OutputType([psobject])]

param (

        [parameter(
            Mandatory,
            ParameterSetName = 'Token'
        )]
        [Microsoft.Identity.Client.AuthenticationResult]
    $Token,

        [Parameter(
            Mandatory,
            ParameterSetName = 'Default',
            Position = 0,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [Alias('AppId')]
        # Application ID to use for authentication
        [guid]
    $ApplicationId,

        [Parameter(
            Mandatory,
            ParameterSetName = 'Default',
            Position = 1,
            ValueFromPipelineByPropertyName
        )]
        [guid]
        # Azure AD tenant ID
    $TenantId,

        [Parameter(
            Mandatory,
            ParameterSetName = 'Default',
            ValueFromPipelineByPropertyName
        )]
        [string]
        # Client certificate thumbprint to use for authentication
    $CertificateThumbprint,
        [string]
        # MS Graph Api version.
    $Version = 'v1.0',
        [string]
        # Specifies item to query for
    $Object = 'auditLogs/signIns',
        [string]
        # Specifies query filter to use
    $Query,
        [switch]
        # Specifies that all responses should be returned
    $All
)

process {
    switch ($PSCmdlet.ParameterSetName) {
        'Token' { $AADToken = $token }
        Default {
            $ClientCertificate = Get-Item -Path (Join-Path -Path 'Cert:\CurrentUser\My' -ChildPath $CertificateThumbprint)
            $AADToken = Get-MsalToken -ClientId $ApplicationId -TenantId $TenantId -ClientCertificate $ClientCertificate
        }
    }

    $uri = 'https://graph.microsoft.com', $Version, $Object -join '/'
    $header = @{
        Authorization = "Bearer {0}" -f $AADToken.AccessToken
    }
    $ContentType = 'application/json'

    #$url = $uri, [uri]::EscapeDataString($Query) -join '?'
    #$url = $uri, [net.webutility]::UrlEncode($Query) -join '?'
    $url = $uri, $Query -join '?'
    $result = Invoke-RestMethod -Uri $url -Headers $header -ContentType $ContentType
    $result.value
    $NextLink = $result.'@odata.nextlink'
    #write-verbose -Message ('Next link: {0}' -f $NextLink)

    while ($all -and $NextLink -and $PSCmdlet.ShouldProcess($NextLink)) {
        $result = Invoke-RestMethod -Uri $NextLink -Headers $header -Verbose
        $result.value
        $NextLink = $result.'@odata.nextlink'
    }
}

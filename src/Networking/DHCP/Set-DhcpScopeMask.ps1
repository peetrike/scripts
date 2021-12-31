#Requires -Version 3.0
#Requires -Modules DhcpServer

<#PSScriptInfo
    .VERSION 1.0.3

    .GUID f40b6ec3-879b-4119-b196-1df69f934842

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2021.  All rights reserved.

    .TAGS dhcp, scope, subnet, mask

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES DhcpServer
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.0.3] - 2021.12.31 - Moved script to Github
        [1.0.2] - 2019.12.17 - changed encoding when saving XML file
        [1.0.1] - 2019.12.17 - turned off WhatIf parameter when removing exported DHCP configuration
        [1.0.0] - 2019.12.02 - Initial Release
        [0.0.2] - 2019.12.02 - Removed ScopeId parameter from Import-DhcpServer
        [0.0.1] - 2019.12.02 - Started work

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Change DHCP scope subnet mask
    .DESCRIPTION
        This script changes DHCP scope subnet mask.  This is done by
        exporting the scope, changing subnet mask, removing the scope and
        importing the changed scope.

        Only IPv4 scopes are processed.
    .EXAMPLE
        Set-DhcpScopeMask -ScopeId 10.0.0.0 -SubnetMask 255.255.255.0

        This command changes subnet mask for DHCP Scope with Scope ID 10.0.0.0
    .INPUTS
        None
    .OUTPUTS
        None
    .NOTES
        Be aware, that if you change subnet mask to contain more IP addresses,
        then the Scope ID can change.  In this case the script will emit
        error message about not being able to find file.  The change will still
        be done.
    .LINK
        Export-DhcpServer
    .LINK
        Import-DhcpServer
    .LINK
        Remove-DhcpServerv4Scope
#>

[CmdLetBinding(
    SupportsShouldProcess
)]
Param(
        [parameter(
            Mandatory
        )]
        [ValidateScript( {
            Get-DhcpServerv4Scope -ScopeId $_
        })]
        [ipaddress]
        # Specifies the scope to be changed
    $ScopeId,
        [parameter(
            Mandatory
        )]
        [ipaddress]
        # Specifies the new Subnet Mask
    $SubnetMask
)

#$Scope = Get-DhcpServerv4Scope -ScopeId $ScopeId -ErrorAction Stop
$fileName = Join-Path -Path $env:TEMP -ChildPath 'DhcpExport.xml'

Export-DhcpServer -ScopeId $ScopeId -File $fileName -Leases -Force

if ($PSCmdlet.ShouldProcess($ScopeId, 'Change scope subnet mask')) {
    $ConfData = [xml](Get-Content $fileName)
    ($ConfData.DHCPServer.IPv4.Scopes.Scope | Where-Object ScopeId -like $ScopeId).SubnetMask = $SubnetMask.ToString()
    $ConfData.InnerXml | Set-Content -Path $fileName -Encoding UTF8 -Confirm:$false

    Remove-DhcpServerv4Scope -ScopeId $ScopeId -Force
    Import-DhcpServer -File $fileName -Leases -ScopeOverwrite -BackupPath $env:TEMP -Force
    Write-Verbose -Message ('The file "{0}" contains just imported changes.' -f $fileName)
} else {
    Remove-Item $fileName -WhatIf:$false
}

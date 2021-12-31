#Requires -version 5.1
#Requires -Modules RemoteDesktop, CimCmdlets

<#PSScriptInfo
    .VERSION 1.0.0
    .GUID d7d66c86-d007-4dad-8e1c-3be5552e4eb7

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2020.  All rights reserved.

    .TAGS rdp shadow PSEdition_Desktop Windows

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://bitbucket.atlassian.teliacompany.net/projects/PWSH/repos/scripts/
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES RemoteDesktop, CimCmdlets
    .REQUIREDSCRIPTS Add-ShadowPermission
    .EXTERNALSCRIPTDEPENDENCIES
    .RELEASENOTES
        [1.0.0] - 2020.09.02 - Initial release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Establish Shadow session to selected session in RDP farm
    .DESCRIPTION
        This script helps to establish RDP Shadow session in RDP farm.
    .EXAMPLE
        Connect-ShadowSession.ps1 -Username me

        This example filters existing sessions by connected user name.
    .EXAMPLE
        Connect-ShadowSession.ps1 -NoConsentPrompt $false

        This examples shows, how permission will be asked from remote user before connecting.
    .EXAMPLE
        Connect-ShadowSession.ps1 -Collection Collection2 -Control $false

        This examples filters existing sessions by Session Collection name.
        Also shadow session cannot be controlled.

    .NOTES
        Be sure that you configure the environment before using this script.
    .LINK
        Farm configuration instructions: https://bitbucket.atlassian.teliacompany.net/projects/PWSH/repos/scripts/browse/src/RdpServer/ShadowSession/README.md
#>

[CmdLetBinding(
    SupportsShouldProcess
)]
param (
        [ValidateNotNullOrEmpty()]
        [string]
        # Specify Connection Broker server name.  By default the Connection Broker is determined automatically.
    $ConnectionBroker,
        [string]
        # Specify (part of) Session Collection name to filter sessions.
        # Session Collection name is searched using substring search.
    $Collection,
        [string]
        # Specify (part of) username for session to connect.  UserName is searched using substring search.
    $UserName,
        [bool]
        # Allow to take control on shadow session
    $Control = $true,
        [bool]
        # Do not ask permission before making shadow session
    $NoConsentPrompt = $true
)

function Get-ConnectionBroker {
    $RegistryArgs = @{
        Name = 'SessionDirectoryLocation'
        Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\ClusterSettings\'
    }
    $ConnectionBroker = Get-ItemPropertyValue @RegistryArgs
    if ($ConnectionBroker -eq [net.dns]::GetHostByName($env:COMPUTERNAME).HostName) {
        $env:COMPUTERNAME
    } else { $ConnectionBroker }
}

function Get-UserSession {
    param (
            [parameter(
                Mandatory
            )]
            [string]
        $ConnectionBroker,
            [string]
        $Collection,
            [string]
        $UserName
    )

    $CimProps = @{
        ComputerName = $connectionBroker
        Class = 'Win32_RDSHCollection'
        Namespace = 'root/cimv2/rdms'
    }
    if ($collection) {
        $CimProps.Filter = 'Name LIKE "%{0}%"' -f $collection
    }
    $RdshCollection = Get-CimInstance @CimProps -ErrorAction Stop
    if ($collection) {
        $CimProps.Filter = @(foreach ($collection in $RdshCollection) {
            'CollectionAlias = "{0}"' -f $Collection.Alias
        }) -join ' or '
    }
    if ($UserName) {
        if ($collection) {
            $CimProps.Filter += ' AND '
        }
        $CimProps.Filter += 'UserName LIKE "%{0}%"' -f $UserName
    }

    $CimProps.Class = 'Win32_SessionDirectorySessionEx'
    $CimProps.Remove('NameSpace')
    foreach ($Session in Get-CimInstance @CimProps -ErrorAction Stop) {
        [PSCustomObject] @{
            PSTypeName       = 'Microsoft.RemoteDesktopServices.Management.RDUserSession'
            ServerName       = $Session.ServerName
            SessionId        = $Session.SessionId
            UserName         = $Session.UserName
            DomainName       = $Session.DomainName
            ServerIPAddress  = $Session.ServerIPAddress
            TSProtocol       = $Session.TSProtocol
            ApplicationType  = $Session.ApplicationType
            ResolutionWidth  = $Session.ResolutionWidth
            ResolutionHeight = $Session.ResolutionHeight
            ColorDepth       = $Session.ColorDepth
            CreateTime       = $Session.CreateTime
            DisconnectTime   = $Session.DisconnectTime
            SessionState     = [Microsoft.RemoteDesktopServices.Management.SESSION_STATE] $Session.SessionState
            CollectionName   = ($RdshCollection | Where-Object Alias -Like $Session.CollectionAlias).Name
            CollectionType   = $Session.CollectionType
            UnifiedSessionId = $Session.UnifiedSessionId
            HostServer       = $Session.HostServer
            #IdleTime         = $Session.IdleTime
            IdleTime         = [timespan]::FromMilliseconds($Session.IdleTime)
            RemoteFxEnabled  = $Session.RemoteFxEnabled
        }
    }
}

if (-not $ConnectionBroker) {
    $ConnectionBroker = Get-ConnectionBroker
}

$ConnectionArgs = @{
    ConnectionBroker = $connectionBroker
}
if ($collection) {
    $ConnectionArgs.Collection = $collection
}
if ($UserName) {
    $ConnectionArgs.UserName = $UserName
}

$SessionList = @(Get-UserSession @ConnectionArgs)

$Session = if ($SessionList.count -gt 1) {
    $SessionList |
        Select-Object -Property Username, UnifiedSessionId, HostServer, SessionState, CreateTime, DisconnectTime, IdleTime |
        Sort-Object Username |
        Out-GridView -Title "Select RDP session to connect" -OutputMode Single
} else { $SessionList[0] }

if ($Session -and $PSCmdlet.ShouldProcess($Session.UserName, 'Establish Shadow session to user')) {
    $SessionArgs = @(
        '/v:{0}' -f $Session.HostServer
        '/shadow:{0}' -f $Session.UnifiedSessionId
    )
    if ($Control) { $SessionArgs += '/control' }
    if ($NoConsentPrompt) { $SessionArgs += '/noconsentprompt' }
    Start-Process -FilePath mstsc.exe -ArgumentList $SessionArgs
}

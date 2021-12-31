#Requires -Version 2.0

<#PSScriptInfo
    .VERSION 1.1.1
    .GUID a686b043-dd13-4fe7-9f2f-f3b602622772

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2021.  All rights reserved.

    .TAGS local, account, admin, ConfigMgr, report, wmi

    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.1.0] 2021.12.31 - moved script to Github
        [1.1.0] 2019.10.29 - added -PassThru parameter
                           - added check before creating class
                           - fixed namespace existence check
        [1.0.0] 2019.10.28 - Initial release

    .PRIVATEDATA
#>

<#
    .DESCRIPTION
        Updates local admin group members to CIM repository
#>

[CmdletBinding()]
Param(
        [switch]
        # show the created instances
    $PassThru
)

$NameSpaceName = 'Telia'
#$NameSpaceName = 'cimv2'
$NameSpace = 'root\{0}' -f $NameSpaceName
$ClassName = 'LocalAdmin'
#$ClassName = 'Win32_LocalAdmin'
$GroupName = 'Administrators'

    # create namespace, if needed
if (-not (Get-WmiObject -Namespace 'root' -Class "__Namespace" | Where-Object { $_.Name -eq $NamespaceName })) {
    Write-Verbose -Message ('Creating namespace: {0}' -f $NameSpace)
    $ns = ([WMICLASS]'\\.\root:__Namespace').CreateInstance()
    #$ns = New-Object -TypeName System.Management.ManagementClass -ArgumentList ('root:__namespace', [string]::Empty , $null )
    $ns.Name = $NameSpaceName
    $null = $ns.Put()
}

    # create new class, if needed
if (-not (Get-WmiObject -List -Namespace $NameSpace -Class $ClassName)) {
    Write-Verbose -Message ('Creating WMI class: {0}' -f $ClassName)
    $newClass = New-Object -TypeName System.Management.ManagementClass -ArgumentList ($NameSpace, [String]::Empty, $null)
    $newClass.__CLASS = $ClassName
    $newClass.Qualifiers.Add('Static', $true)

    $newClass.Properties.Add('Name', [Management.CimType]::String, $false)
    $newClass.Properties['Name'].Qualifiers.Add('Key', $true)
    $newClass.Properties.Add('Domain', [Management.CimType]::String, $false)
    $newClass.Properties['Domain'].Qualifiers.Add('Key', $true)

    $newClass.Properties.Add('Caption', [Management.CimType]::String, $false)
    #$newClass.Properties.Add("Description", [Management.CimType]::String, $false)
    $newClass.Properties.Add('LocalAccount', [Management.CimType]::Boolean, $false)
    #$newClass.Properties.Add("SID", [Management.CimType]::String, $false)
    #$newClass.Properties.Add("Status", [Management.CimType]::String, $false)
    $newClass.Properties.Add('Type', [Management.CimType]::String, $false)
    $null = $newClass.Put()
}

    # clear existing info:
Write-Verbose -Message 'Clearing class instances'
Get-WmiObject -Namespace $NameSpace -Class $ClassName -ErrorAction SilentlyContinue |
    Remove-WmiObject

    # get local admins
Write-Verbose -Message 'Locating Administrators group members'
$nameList = net.exe localgroup $GroupName |
    Select-Object -Skip 6 |
    Where-Object -FilterScript { $_ -and $_ -notmatch "completed successfully" }

    # add admins to CIM
foreach ($Name in $nameList) {
    $fullName = $Name
    $parts = $Name.split('\')
    if ($parts.length -eq 2) {
        $Name = $parts[1]
        $Domain = $parts[0]
    } else {
        $fullName = '{0}\{1}' -f $env:COMPUTERNAME, $n
        $Domain = $env:COMPUTERNAME
    }

    $ObjectProps = @{
        Name         = $Name
        Caption      = $fullName
        Domain       = $Domain
        LocalAccount = $false
        # SID          = ''
        Type         = 'Unknown'
    }

    $result = Get-WmiObject -Class Win32_Account -Filter "name='$Name'"

    if ($result) {
        $ObjectProps.Caption = $result.Caption
        $ObjectProps.Domain = $result.Domain
        $ObjectProps.LocalAccount = $result.LocalAccount
        # $ObjectProps.SID = $result.SID
        $ObjectProps.Type = switch -wildcard ($result.ClassPath.ClassName) {
            '*User*' { 'User' }
            '*Group' { 'Group' }
            '*System*' { 'System' }
            Default { 'Unknown' }
        }
    }

    Write-Verbose -Message ('Saving member: {0}' -f $ObjectProps.Caption)
    $WmiObject = Set-WmiInstance -Namespace $NameSpace -Class $ClassName -Arguments $ObjectProps
    # New-Object -TypeName PSObject -Property $ObjectProps

    if ($PassThru) {
        $WmiObject
    }
}

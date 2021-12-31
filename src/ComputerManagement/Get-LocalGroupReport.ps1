#Requires -Version 3.0

<#PSScriptInfo
    .VERSION 1.1.1
    .GUID 29e09416-4881-4cbc-ac7e-bf91adc25e9b

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2019.  All rights reserved.

    .TAGS group, report, remote, PSEdition_Desktop, Windows
    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.1.1] - 2021.12.31 - Moved script to Github
        [1.1.0] - 2019.10.28 - changed minimum Powershell version to 3.0
                             - if report file exists, the results are appended to end of file
        [1.0.0] - 2019.10.28 - initial release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Generates local group members report for local computer
    .DESCRIPTION
        This script connects to remote computers and generates local group
        members report.  The result is saved to CSV file.

        If report file already exists, the new data is appended to the end of the file.
    .EXAMPLE
        Get-LocalGroupReport.ps1 -Group Administrators -Path .\report.csv

        Report the members of Administrators group to file 'report.csv'
    .LINK
        Get-LocalGroupMember - https://docs.microsoft.com/powershell/module/Microsoft.PowerShell.LocalAccounts/Get-LocalGroupMember
    .LINK
        net localgroup - https://docs.microsoft.com/previous-versions/windows/it-pro/windows-server-2012-R2-and-2012/cc725622(v=ws.11)
#>

[CmdletBinding()]
Param(
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'The name of the group to report'
        )]
        [ValidateNotNullOrEmpty()]
        [string[]]
        # Specifies the name of the local group from which this script gets members.
    $Group,
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'The name of the report file'
        )]
        [Alias('FileName', 'Multiple')]
        [string]
        # Specifies report file path.
    $Path,
        [switch]
        # Adds Timestamp to report file name.
    $ReportFileNameTimeStamp
)

if (-not (Get-Command -Name Get-LocalGroupMember -ErrorAction SilentlyContinue) ) {
    function Get-LocalGroupMember {
        [CmdletBinding()]
        param (
            [Parameter(
                Mandatory = $true,
                Position = 0,
                ValueFromPipeline = $true,
                ValueFromPipelineByPropertyName = $true
            )]
            [ValidateNotNullOrEmpty()]
            [String]
            $Name
        )

        begin {
            Add-Type -AssemblyName System.DirectoryServices.AccountManagement
            $NameIdentity = [DirectoryServices.AccountManagement.IdentityType]::Name
            $DomainSource = [DirectoryServices.AccountManagement.ContextType]::Domain
            $localMachine = [DirectoryServices.AccountManagement.ContextType]::Machine
            $LocalContext = [DirectoryServices.AccountManagement.PrincipalContext]$localMachine
            $originalErrorAction = $ErrorActionPreference
            $ErrorActionPreference = 'Stop'
            try {
                $domainContext = [DirectoryServices.AccountManagement.PrincipalContext]$DomainSource
            } catch {
                $domainContext = $null
            }
            $ErrorActionPreference = $originalErrorAction
        }

        process {
            Write-Verbose -Message 'Selecting group'

            $result = [DirectoryServices.AccountManagement.GroupPrincipal]::FindByIdentity($LocalContext, $NameIdentity, $Name)
            if ($result) {
                $Group = $result
            } else {
                $errorProps = @{
                    Message          = 'Group not found'
                    Category         = [System.Management.Automation.ErrorCategory]::ObjectNotFound
                    CategoryActivity = 'Get-LocalGroupMember'
                    TargetObject     = $Name
                    Exception        = New-Object -TypeName 'System.Management.Automation.ItemNotFoundException'
                }
                Write-Error @errorProps -ErrorAction Stop
            }

            $memberError = $false
            $memberList = New-Object System.Collections.Generic.List[System.Object]
            $originalErrorAction = $ErrorActionPreference
            $ErrorActionPreference = 'Stop'
            try {
                Write-Verbose -Message 'Getting members from group'
                foreach ($m in $Group.Members) {
                    $objProps = @{
                        PSTypeName = 'Microsoft.PowerShell.Commands.LocalPrincipal'
                        # Name       = $m.Name
                        Name       = $m.SamAccountName
                        Sid        = $m.Sid
                    }
                    $objProps.PrincipalSource = switch ($m.ContextType) {
                        'Domain' { 'ActiveDirectory' }
                        'Machine' { 'Local' }
                    }
                    $objProps.ObjectClass = switch -Wildcard ($m.gettype().Name) {
                        'Group*' { 'Group' }
                        'User*' { 'User' }
                        'Computer*' { 'Computer' }
                    }
                    $member = New-Object -TypeName psobject -Property $objProps
                    $memberList.Add($member)
                }
            } catch <# [System.Runtime.InteropServices.COMException] #> {
                Write-Verbose -Message $_.exception.message
                # if ($_.exception.ErrorCode -eq -2147024843) { # "network path not found" error code
                $memberError = $true
                $memberList.Clear()
                # } else {
                #    Write-Error -Message $_.exception.Message -ErrorAction $originalErrorAction
                # }
            }
            $ErrorActionPreference = $originalErrorAction

            if ($memberError) {
                Write-Verbose -Message 'Failed to get members, using "net localgroup"'
                $nameList = net.exe localgroup $Name |
                    Select-Object -Skip 6 |
                    Where-Object -FilterScript { $_ -and $_ -notmatch "completed successfully" }
                foreach ($n in $nameList) {
                    $parts = $n.split('\')
                    if ($parts.length -eq 2) {
                        $fullName = $n
                        $n = $parts[-1]
                        if ($parts[0] -like 'NT AUTHORITY') {
                            # system account
                            $tryMethod = 'Wmi'
                        } else {
                            $tryMethod = 'Domain'
                            # $tryMethod = 'Wmi'
                        }
                    } else {
                        $tryMethod = 'local'
                        $fullName = '{0}\{1}' -f $env:COMPUTERNAME, $n
                    }

                    Write-Verbose -Message ('Searching for: {0}' -f $fullName)
                    switch ($tryMethod) {
                        'local' {
                            Write-Verbose -Message 'trying local search'
                            $result = [DirectoryServices.AccountManagement.Principal]::FindByIdentity($LocalContext, $NameIdentity, $n)
                        }
                        'Domain' {
                            if ($domainContext) {
                                Write-Verbose -Message 'trying domain search'
                                try {
                                    $result = [DirectoryServices.AccountManagement.Principal]::FindByIdentity($domainContext, $NameIdentity, $n)
                                } catch {
                                    $result = $null
                                }
                            } else {
                                # no domain context available
                                $result = $null
                            }
                        }
                        'Wmi' {
                            Write-Verbose -Message 'trying WMI'
                            $result = Get-CimInstance -ClassName Win32_Account -Filter "name='$n'"
                        }
                    }
                    if ($result) {
                        $objProps = @{
                            PSTypeName = 'Microsoft.PowerShell.Commands.LocalPrincipal'
                            Sid        = $result.Sid
                        }
                        switch ($tryMethod) {
                            'wmi' {
                                $objProps.Name = $result.Caption
                                $objProps.PrincipalSource = 'Local'
                                $objProps.ObjectClass = switch -Wildcard ($result.ClassPath) {
                                    '*group' { 'Group' }
                                    '*User*' { 'User' }
                                    '*SystemAccount' { 'System Account' }
                                }
                            }
                            Default {
                                $objProps.Name = $fullName
                                $objProps.PrincipalSource = switch ($m.ContextType) {
                                    'Domain' { 'ActiveDirectory' }
                                    'Machine' { 'Local' }
                                }
                                $objProps.ObjectClass = switch -Wildcard ($result.gettype().Name) {
                                    'Group*' { 'Group' }
                                    'User*' { 'User' }
                                    'Computer*' { 'Computer' }
                                }
                            }
                        }
                    } else {
                        Write-Verbose -Message 'not found, creating generic object'
                        $objProps = @{
                            PSTypeName      = 'Microsoft.PowerShell.Commands.LocalPrincipal'
                            Name            = $fullName
                            ObjectClass     = 'Unknown'
                            PrincipalSource = 'ActiveDirectory'
                            Sid             = $null
                        }
                    }

                    $member = New-Object -TypeName psobject -Property $objProps
                    $memberList.Add($member)
                }
            }

            $memberList #| Sort-Object -Property Sid -Unique
        }
    }
}

$ComputerName = @{
    Name       = 'ComputerName'
    Expression = { $env:COMPUTERNAME }
}
$GroupName = @{
    Name       = 'GroupName'
    Expression = { $name }
}

$resultSet = foreach ($name in $Group) {
    Write-Verbose -Message ('Collecting data for group: {0}' -f $name)

    Get-LocalGroupMember -Name $name |
        Select-Object -Property $ComputerName, $GroupName, Name, ObjectClass, PrincipalSource, SID
}

Write-Verbose -Message 'Saving results'


if ($ReportFileNameTimeStamp) {
    $FileTimeSuffix = '_' + (Get-Date -Format s).Replace(':', '.')
} else {
    $FileTimeSuffix = ''
}

$FolderName = Split-Path -Path $Path -Parent
$FileName = Split-Path -Path $Path -Leaf
$null = $FileName -match '(.*)\.csv'
$FileName = '{0}{1}.csv' -f $Matches[1], $FileTimeSuffix

$CsvProps = @{
    UseCulture        = $true
    Encoding          = 'utf8'
    NoTypeInformation = $true
    Path              = Join-Path -Path $FolderName -ChildPath $FileName
    Append            = $true
}

$resultSet | Export-Csv @CsvProps

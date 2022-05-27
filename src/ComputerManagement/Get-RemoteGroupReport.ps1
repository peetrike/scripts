#Requires -Version 2.0

<#PSScriptInfo
    .VERSION 1.0.1
    .GUID b592fe2f-d64a-4370-8ce5-ca241cb9c5f2

    .AUTHOR Meelis Nigols
    .COMPANYNAME Telia Eesti AS
    .COPYRIGHT (c) Telia Eesti AS 2019.  All rights reserved.

    .TAGS group, report, remote
    .LICENSEURI https://opensource.org/licenses/MIT
    .PROJECTURI https://github.com/peetrike/scripts
    .ICONURI

    .EXTERNALMODULEDEPENDENCIES
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES

    .RELEASENOTES
        [1.1.1] - 2021.12.31 - Moved script to Github
        [1.0.0] - 2019.10.17 - initial release

    .PRIVATEDATA
#>

<#
    .SYNOPSIS
        Generates local group members report for remote computers
    .DESCRIPTION
        This script connects to remote computers and generates local group
        members report.  The result is saved to CSV file with name
        GroupReport.csv .

        If several groups are reported, then every group membership can be
        saved into separate file.  If you specify -OutputType Multiple, then
        report files are named after group name.

        If report file already exists, the file is overwritten.  To get
        guaranteed new file, you can specify -ReportFileNameTimeStamp on
        command line.  That appends current datetime to filename, ensuring
        unique filename for every script run.
    .EXAMPLE
        Get-RemoteGroupReport.ps1 -ComputerName $env:COMPUTERNAME -Group Administrators

        Connect to local computer and report the members of Administrators group
    .EXAMPLE
        Get-Content computers.txt | Get-RemoteGroupReport.ps1 -Group Users -Credential 'domain\user'

        Take computer names from computers.txt file and report members of group Users.
        Use 'domain\user' credential to connect to remote computers.
    .EXAMPLE
        Get-RemoteGroupReport.ps1 -CN server1 -Group Users, Administrators -OutputType Multiple

        Connect to remote computer and report the members in two groups into separate file for each group.
    .EXAMPLE
        Get-RemoteGroupReport.ps1 -ComputerName server1 -Group Administrators -ReportFileNameTimeStamp

        Connect to remote computer and report the members of group Administrators.
        Have current datetime included in filename.
    .LINK
        Get-LocalGroupMember
    .LINK
        https://docs.microsoft.com/previous-versions/windows/it-pro/windows-server-2012-R2-and-2012/cc725622(v=ws.11)
#>

[CmdletBinding()]
param(
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'Remote computer name(s) to connect',
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNullOrEmpty()]
        [Alias('CN')]
        [string[]]
        # Specifies the computers on which the command runs.
    $ComputerName,
        [PSCredential]
        [Management.Automation.Credential()]
        # specifies credential for connecting to remote computers
    $Credential = [Management.Automation.PSCredential]::Empty,
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'The name of the group to report'
        )]
        [ValidateNotNullOrEmpty()]
        [string[]]
        # Specifies the name of the local group from which this script gets members.
    $Group,
        [ValidateSet('Single', 'Multiple')]
        [string]
        # Specifies whether to create single report file or separate file for every group.
        # Possible values: Single, Multiple.
    $OutputType = 'Single',
        [switch]
        # Adds Timestamp to report file name.
    $ReportFileNameTimeStamp
)

begin {
    $RemoteFunction = {
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
                                    # $tryMethod = 'Domain'
                                    $tryMethod = 'Wmi'
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
                                    $result = Get-WmiObject -Class Win32_Account -Filter "name='$n'"
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
    }

    $RemoteCode = {
        param (
            $Group
        )
        Get-LocalGroupMember -Name $Group
    }
    $InvokeProps = @{
        ScriptBlock = $RemoteCode
    }

    $ResultSet = @{}
    foreach ($name in $Group) {
        $ResultSet.$name = New-Object System.Collections.Generic.List[System.Object]
    }
}

process {
    Write-Verbose -Message ('Establishing remote session to: {0}' -f ($ComputerName -join ';'))
    $Session = New-PSSession -ComputerName $ComputerName -Credential $Credential
    Invoke-Command -Session $Session -ScriptBlock $RemoteFunction
    $InvokeProps.Session = $Session

    foreach ($name in $Group) {
        Write-Verbose -Message ('Collecting data for group: {0}' -f $name)
        $InvokeProps.ArgumentList = $name

        Invoke-Command @InvokeProps |
            Select-Object -Property PSComputerName, Name, ObjectClass, PrincipalSource, SID |
            ForEach-Object {
                $ResultSet.$name.Add($_)
            }
    }
    Remove-PSSession -Session $Session
}

end {
    Write-Verbose -Message 'Saving results'

    $CsvProps = @{
        UseCulture        = $true
        Encoding          = 'UTF8'
        NoTypeInformation = $true
        # Append            = $true
    }
    if ($PSVersionTable.PSVersion.Major -gt 5) {
        $CsvProps.Encoding = 'utf8BOM'
    }

    if ($ReportFileNameTimeStamp) {
        $FileTimeSuffix = '_' + (Get-Date -Format s).Replace(':', '.')
    } else {
        $FileTimeSuffix = ''
    }

    switch ($OutputType) {
        'Single' {
            $GroupName = @{
                Name       = 'GroupName'
                Expression = { $name }
            }
            $memberList = foreach ($name in $Group) {
                $ResultSet.$name |
                    Select-Object -Property $GroupName, *
            }

            $CsvName = 'GroupReport{0}.csv' -f $FileTimeSuffix
            $CsvProps.Path = Join-Path -Path $PWD -ChildPath $CsvName

            $memberList |
                Export-Csv @CsvProps
        }
        'Multiple' {
            foreach ($name in $Group) {
                $CsvName = '{0}{1}.csv' -f
                    ($name.Split([io.path]::GetInvalidFileNameChars()) -join '_'),
                    $FileTimeSuffix
                $CsvProps.Path = Join-Path -Path $PWD -ChildPath $CsvName

                $ResultSet.$name |
                    Export-Csv @CsvProps
            }
        }
    }
}

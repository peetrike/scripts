#Requires -Version 7
#Requires -Modules Devolutions.PowerShell

[CmdletBinding()]
param (
        [ValidateScript({
            Get-RDMDataSource -Name $_
        })]
        [string]
        # RDM Data Source to be used
    $DataSource = (Get-RDMCurrentDataSource).Name
)

if ($DataSource) {
    Get-RDMDataSource -Name $DataSource | Set-RDMCurrentDataSource
}

Write-Verbose -Message ('Working with Data Source: {0}' -f $DataSource)

Get-RDMUser |
    Select-Object -Property Name, Description, Email, HasAccessRdm, IsEnabled, @{
        Name       = 'Database'
        Expression = { $DataSource }
    }

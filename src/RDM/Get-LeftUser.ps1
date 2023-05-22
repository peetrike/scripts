#Requires -Version 7
# Requires -Modules Devolutions.PowerShell

[CmdletBinding()]
param (
        [string[]]
    $DataSource = (Get-RDMDataSource | Where-Object Type -like 'SQLServer').Name
)

foreach ($Source in $DataSource) {
    Get-RDMDataSource -Name $Source | Set-RDMCurrentDataSource
    #Update-RDMUI

    Get-RDMUser |
        Where-Object Name -like 'et\*' |
        ForEach-Object {
            $user = $_
            Write-Verbose -Message ('Checking user: {0}' -f $user.Name)
            try {
                $AdUser = Get-ADUser $user.Name.Split('\')[-1] -ErrorAction Stop
                if (-not $AdUser.Enabled) {
                    $user
                }
            } catch {
                $user
            }
        } |
        Select-Object -Property Name, Description, Email, @{
            Name       = 'Database'
            Expression = { (Get-RDMCurrentDataSource).Name }
        }
}

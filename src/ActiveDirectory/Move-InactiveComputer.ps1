[CmdletBinding(
    SupportsShouldProcess
)]
param (
        [Parameter(
            Mandatory
        )]
        [string]
    $Destination,
        [int]
    $DaysAgo = 90,
        [switch]
    $IncludeServer,
        [switch]
    $UsePwdDate
)

$startDate = (Get-Date).AddDays(-$DaysAgo)

$filter = @(
    'Enabled -eq $true'
    if ($UsePwdDate) {
        'PasswordLastSet -lt $startDate'
    } else {
        'LastLogonDate -lt $startDate'
    }
    if (-not $IncludeServer) { 'OperatingSystem -notlike "*Server*"' }
) -join ' -and '

$propertyList = @(
    'OperatingSystem'
    'LastLogonDate'
)

foreach ($Computer in Get-ADComputer -Filter $filter -Properties $propertyList) {
    if ($PSCmdlet.ShouldProcess($Computer.Name, 'Disable and move computer')) {
        Disable-ADAccount -Identity $Computer.DistinguishedName -PassThru |
            Move-ADObject -TargetPath $Destination -PassThru
    }
}

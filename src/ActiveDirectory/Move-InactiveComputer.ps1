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
    $DaysAgo = 90
)

$startDate = (Get-Date).AddDays(-$DaysAgo)
$filter = {
    LastLogonDate -lt $startDate -and
    OperatingSystem -notlike '*server*' -and
    Enabled -eq $true
}
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

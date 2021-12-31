#Requires -Version 2

param (
        [ValidateScript({
            Test-Path -Path $_
        })]
        [string]
        # local path for filtering events from Event Log
    $Path,
        [string]
        # CSV file to use for report
    $ReportFile,
        [int]
        # Number of days to look back in Event Log
    $Days = 14
)

$AccountName = @{
    Name       = 'AccountName'
    Expression = {
        (Get-ADUser -Identity $_.Properties[1].Value).Name
    }
}
# $AccountDomain = @{Name = 'AccountDomain'; e={$_.Properties[2].Value}}
$ObjectName = @{Name = 'ObjectName'; e = { $_.Properties[6].Value } }
# $ProcessId = @{Name = 'ProcessId'; e={$_.Properties[10].Value}}
$ProcessName = @{Name = 'ProcessName'; e = { $_.Properties[11].Value } }
$AccessList =  @{Name = 'AccessList'; e = { $_.Properties[8].Value.Trim(' ') } }
$AccessMask =  @{
    Name       = 'AccessMask'
    Expression = {
        switch ($_.Properties[9].Value) {
            { $_ -band 0x1 } { 'ReadData' }
            { $_ -band 0x2 } { 'WriteData' }
            { $_ -band 0x4 } { 'AppendData' }
            { $_ -band 0x20 } { 'Execute' }
            { $_ -band 0x40 } { 'DeleteChild' }
            { $_ -band 0x10000 } { 'Delete' }
            { $_ -band 0x40000 } { 'Write DAC' }
            { $_ -band 0x80000 } { 'Write Owner' }
            default { 'other rights' }
        } #-join ', '
    }
}
$KeyWords = @{Name = 'Keywords'; e = { $_.KeywordsDisplayNames | ForEach-Object { $_ } } }

<# $idList = 4656,4658,4660,4663,4664,4670

$secEvents = Get-WinEvent -ListProvider "microsoft-windows-security-auditing"

$secEvents.Events | Where-Object ID -EQ 4663 | select -First 1
$secEvents.Events | Where-Object ID -EQ 4656 | select -First 1 #>

$EventFilter = @{
    LogName   = 'Security'
    ID        = 4663
    StartTime = (Get-Date).AddDays(-$Days)
}

$EventList = Get-WinEvent -FilterHashtable $EventFilter |
    Where-Object { $_.Properties[6].Value -like "$Path*" } |
    Select-Object -Property $KeyWords, TimeCreated, $AccountName, MachineName, $ObjectName, $ProcessName, $AccessMask, $AccessList

if ($ReportFile) {
    $EventList |
        Export-Csv -UseCulture -Encoding utf8 -NoTypeInformation -Path $ReportFile
} else {
    $EventList | Out-GridView -Title ('Audit events for path: {0}' -f $Path)
}

#Requires -Version 3.0
#Requires -Modules DhcpServer

[CmdletBinding(
    SupportsShouldProcess
)]
param(
        [parameter(
            ValueFromPipeline
        )]
        [string[]]
    $DnsSuffix,
        [parameter(
            Mandatory
        )]
        [ipaddress]
    $ScopeId
)

begin {
    $OptionId = 119
    $domainSearchListHexArray = New-Object -TypeName 'System.Collections.Generic.List[System.Byte]'
}

process {
    $domainSearchListHexArray += foreach ($domain in $DnsSuffix) {
        foreach ($domainPart in $domain.split('.')) {
            $domainPart.Length
            [byte[]]$domainPart.ToCharArray()
        }

        0x00
    }
}

end {
    Write-Verbose -Message 'DnsSuffix:'
    Write-Verbose -Message ($domainSearchListHexArray -join ',')
    Set-DhcpServerv4OptionValue -ScopeId $ScopeId -OptionId $OptionId -Value $domainSearchListHexArray
}

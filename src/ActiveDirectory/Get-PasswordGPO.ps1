function Get-PasswordGPO {
    [CmdletBinding()]
    param (
            [switch]
        $AsInt
    )

    $domainname = [DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().Name

    $GpoPath = '\\{0}\sysvol\{0}\policies\' -f $domainname
    $ProblemGpo = Get-ChildItem -Path $GpoPath -Directory -Filter '{*}' | Where-Object {
        Get-ChildItem -Path $_.FullName -Filter *.xml -Recurse -File | Select-String 'cpassword="[^"]+"' -List
    } | ForEach-Object {
        $Gpo = Get-GPO -Guid $_.Name
        if ($Gpo.GpoStatus -ne 0) {
            $GpoXml = [xml] (Get-GPOReport -Guid $Gpo.Id -ReportType xml)
            if ($GpoXml.GPO.LinksTo | Where-Object Enabled -eq 'true') {
                $Gpo
            } else {
                Write-Verbose -Message ('GPO not linked: {0}' -f $gpo.DisplayName)
            }
        } else {
            Write-Verbose -Message ('GPO: {0} - Status: {1}' -f $gpo.DisplayName, $Gpo.GpoStatus)
        }
    }

    if ($AsInt) {
        @($ProblemGpo).Count
    } else {
        $ProblemGpo
    }
}

Get-PasswordGPO

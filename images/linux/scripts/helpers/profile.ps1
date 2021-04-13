Get-Content -LiteralPath '/etc/environment' | ForEach-Object {
    $Name, $Value = $_ -split '='
    $Name = $Name.Trim('"')
    [System.Environment]::SetEnvironmentVariable($Name, $Value)
}

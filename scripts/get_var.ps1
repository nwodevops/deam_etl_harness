param(
    [Parameter(Mandatory = $true)][string]$ConfigPath,
    [Parameter(Mandatory = $true)][string]$Name,
    [string]$Default = ""
)

# Imprime una variable de project-config.json. Uso desde init.bat con for /f.
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    Write-Output $Default
    exit 0
}

try {
    $cfg = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
} catch {
    Write-Output $Default
    exit 0
}

$var = @($cfg.config.variables) | Where-Object { $_.name -eq $Name } | Select-Object -First 1
if ($null -eq $var -or $null -eq $var.value) {
    Write-Output $Default
} else {
    Write-Output $var.value
}
exit 0

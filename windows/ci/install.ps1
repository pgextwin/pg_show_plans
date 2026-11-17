[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PgRoot,

    [Parameter(Mandatory = $true)]
    [string]$UpstreamDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$control = Join-Path $UpstreamDir "pg_show_plans.control"
$extensionDir = Join-Path $PgRoot "share\extension"

if (-not (Test-Path $control -PathType Leaf)) {
    throw "Required pg_show_plans file was not found: $control"
}
if (-not (Test-Path $extensionDir -PathType Container)) {
    throw "PostgreSQL extension directory was not found: $extensionDir"
}

$sqlFiles = @(Get-ChildItem -Path $UpstreamDir -File -Filter "pg_show_plans--*.sql")
if ($sqlFiles.Count -ne 4) {
    throw "Expected 4 pg_show_plans SQL files, found $($sqlFiles.Count)."
}

Copy-Item $control (Join-Path $extensionDir "pg_show_plans.control") -Force
foreach ($sqlFile in $sqlFiles) {
    Copy-Item $sqlFile.FullName (Join-Path $extensionDir $sqlFile.Name) -Force
}

Write-Host "Installed native pg_show_plans control and $($sqlFiles.Count) SQL files into $extensionDir"

Copy-Item (Join-Path $UpstreamDir "pg_show_plans.dll") (Join-Path $PgRoot "lib/pg_show_plans.dll") -Force

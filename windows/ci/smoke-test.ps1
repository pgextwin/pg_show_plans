[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$PgRoot, [Parameter(Mandatory=$true)][int]$PgPort, [Parameter(Mandatory=$true)][int]$PostgreSqlMajor)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$data = Join-Path $env:RUNNER_TEMP "pg_show_plans-$PostgreSqlMajor-data"
$log = Join-Path $env:RUNNER_TEMP "pg_show_plans-$PostgreSqlMajor.log"
& "$PgRoot/bin/initdb.exe" -D $data -U postgres -A trust --encoding=UTF8 --no-locale
if ($LASTEXITCODE -ne 0) { throw 'initdb failed' }
$started = $false
try {
    & "$PgRoot/bin/pg_ctl.exe" -D $data -l $log -o "-p $PgPort -c listen_addresses=127.0.0.1 -c shared_preload_libraries=pg_show_plans" start
    if ($LASTEXITCODE -ne 0) { throw 'Preload startup failed' }
    $started = $true
    & "$PgRoot/bin/psql.exe" -h 127.0.0.1 -p $PgPort -U postgres -d postgres -X -v ON_ERROR_STOP=1 -c "CREATE EXTENSION pg_show_plans; SELECT extversion FROM pg_extension WHERE extname='pg_show_plans'; SELECT count(*) FROM pg_show_plans(); SELECT count(*) FROM pg_show_plans_q;"
    if ($LASTEXITCODE -ne 0) { throw 'pg_show_plans SQL smoke failed' }
    Write-Host "PASS: pg_show_plans PG$PostgreSqlMajor functional smoke test"
} finally {
    if (Test-Path $log) { Get-Content $log -Tail 80 }
    if ($started) { & "$PgRoot/bin/pg_ctl.exe" -D $data -m immediate stop }
}

[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$PgRoot, [Parameter(Mandatory=$true)][string]$UpstreamDir)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$source = (Resolve-Path $UpstreamDir).Path
$runTemp = $env:RUNNER_TEMP
$actual = (& git -C $source rev-parse HEAD).Trim()
if ($actual -cne '92ecb21f8f2307a4bc7db8f01623599e75930fc2') { throw 'Upstream identity mismatch' }
$file = Join-Path $source 'pg_show_plans.c'
$raw = [IO.File]::ReadAllText($file)
$old = 'Datum pg_show_plans(PG_FUNCTION_ARGS);'
if (($raw.Split(@($old), [StringSplitOptions]::None).Count - 1) -ne 1) { throw 'Unexpected MSVC prototype' }
[IO.File]::WriteAllText($file, $raw.Replace($old, '/* MSVC: PG_FUNCTION_INFO_V1 supplies the exported function declaration. */'), [Text.UTF8Encoding]::new($false))
$vswhere = Join-Path ([Environment]::GetFolderPath('ProgramFilesX86')) 'Microsoft Visual Studio/Installer/vswhere.exe'
if (-not (Test-Path $vswhere)) { throw 'MSVC discovery tool missing' }
$vs = @(& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath |
    Select-Object -First 1)
if (-not $vs -or -not $vs[0].Trim()) { throw 'MSVC x64 toolchain missing' }
$devCmd = Join-Path $vs[0].Trim() 'Common7/Tools/VsDevCmd.bat'
if (-not (Test-Path $devCmd)) { throw 'VsDevCmd unavailable' }

$exports = @('Pg_magic_func', '_PG_init', 'pg_show_plans', 'pg_finfo_pg_show_plans')
$def = Join-Path $source 'pg_show_plans.def'
@('LIBRARY pg_show_plans','EXPORTS') + ($exports | ForEach-Object { "    $_" }) |
    Set-Content -Path $def -Encoding ascii
$dll = Join-Path $source 'pg_show_plans.dll'
$obj = Join-Path $source 'pg_show_plans.obj'
$sourceFile = Join-Path $source 'pg_show_plans.c'
$pgVersion = (& (Join-Path $PgRoot "bin\pg_config.exe") --version).Trim()
if ($pgVersion -notmatch '^PostgreSQL\s+(14|15|16|17|18|19)(?:\.|\s)') { throw "Unsupported PostgreSQL version: $pgVersion" }
$clStdLine = if ([int]$Matches[1] -ge 19) { 'set "CL=/std:c11"' } else { '' }
$buildCmd = Join-Path $runTemp 'pg-show-plans-private-build.cmd'
@"
@echo off
call "$devCmd" -arch=x64 -host_arch=x64 >nul
$clStdLine
if errorlevel 1 exit /b %errorlevel%
cl /nologo /O2 /MD /DWIN32 /DWIN32_NO_STATUS /D_CRT_SECURE_NO_WARNINGS ^
 /I"$pgRoot\include\server\port\win32_msvc" ^
 /I"$pgRoot\include\server\port\win32" ^
 /I"$pgRoot\include\server" /I"$pgRoot\include" ^
 /c "$sourceFile" /Fo"$obj"
if errorlevel 1 exit /b %errorlevel%
link /nologo /DLL /OUT:"$dll" /DEF:"$def" ^
 "$obj" "$pgRoot\lib\postgres.lib" "$pgRoot\lib\libintl.lib"
if errorlevel 1 exit /b %errorlevel%
dumpbin /nologo /exports "$dll"
if errorlevel 1 exit /b %errorlevel%
"@ | Set-Content -Path $buildCmd -Encoding ascii
$buildLog = @(& cmd.exe /d /c $buildCmd 2>&1)
$buildLog | ForEach-Object { Write-Host "$_" }
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $dll)) { throw 'Pinned native MSVC DLL compile/link failed' }
$exportDump = $buildLog -join [Environment]::NewLine
foreach ($name in $exports) {
    if ($exportDump -notmatch "(?m)\b$([regex]::Escape($name))\b") {
        throw "Required Windows DLL export absent: $name"
    }
}

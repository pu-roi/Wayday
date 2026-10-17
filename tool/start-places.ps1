param([ValidateSet('postgis', 'file')][string]$Mode = 'postgis')
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$apiPython = Join-Path $repositoryRoot '.tools/api-venv/Scripts/python.exe'
$catalogPath = Join-Path $repositoryRoot 'data/generated/pasig-places.json'
if (-not (Test-Path -LiteralPath $apiPython)) {
    throw 'Run .\tool\prepare-places.ps1 from the repository root first.'
}
$Mode = $Mode.ToLowerInvariant()
$existing = $null
try {
    $existing = Invoke-RestMethod http://127.0.0.1:8780/health -TimeoutSec 2
} catch { }
if ($existing.status -eq 'ready' -and $existing.source_date) {
    if ($existing.catalog_mode -ne $Mode) {
        throw "A Wayday API is already running in '$($existing.catalog_mode)' mode. Stop it before changing modes."
    }
    Write-Host "Wayday place service is already ready ($Mode)."
    return
}
if ($Mode -eq 'postgis') {
    . (Join-Path $PSScriptRoot 'places-environment.ps1')
    Set-WaydayDatabaseEnvironment -RepositoryRoot $repositoryRoot
} elseif (-not (Test-Path -LiteralPath $catalogPath)) {
    throw 'Run .\tool\prepare-places.ps1 to generate the file catalog first.'
}
New-Item -ItemType Directory -Force (Join-Path $repositoryRoot 'data/local') | Out-Null
# File mode is opt-in only; a PostGIS failure never enables it.
$env:WAYDAY_CATALOG_MODE = $Mode
$env:WAYDAY_CATALOG_PATH = $catalogPath
$apiProcess = Start-Process -FilePath $apiPython -WorkingDirectory $repositoryRoot -WindowStyle Hidden -PassThru `
    -ArgumentList @('-m','uvicorn','wayday_api.app:app','--app-dir','services/api/src','--host','127.0.0.1','--port','8780','--no-access-log') `
    -RedirectStandardOutput (Join-Path $repositoryRoot 'data/local/places-out.log') `
    -RedirectStandardError (Join-Path $repositoryRoot 'data/local/places-error.log')
$apiProcess.Id | Set-Content -LiteralPath (Join-Path $repositoryRoot 'data/local/places-api.pid')
for ($attempt = 0; $attempt -lt 15; $attempt++) {
    Start-Sleep -Seconds 1
    if ($apiProcess.HasExited) { throw 'Place service exited. See data/local/places-error.log.' }
    try {
        $ready = Invoke-RestMethod http://127.0.0.1:8780/health -TimeoutSec 1
        if ($ready.status -eq 'ready' -and $ready.catalog_mode -eq $Mode) {
            Write-Host "Wayday places ready on localhost:8780 ($($ready.catalog_mode), data $($ready.source_date))."
            return
        }
    } catch { }
}
throw 'Place service did not become ready. See data/local/places-error.log.'

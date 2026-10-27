$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $PSScriptRoot 'places-environment.ps1')
Set-WaydayDatabaseEnvironment -RepositoryRoot $repositoryRoot
$apiPython = Join-Path $repositoryRoot '.tools/api-venv/Scripts/python.exe'
Push-Location $repositoryRoot
$previousTestUrl = $env:WAYDAY_TEST_DATABASE_URL
try {
    # Tests create/drop only unique synthetic databases on this local server.
    $env:WAYDAY_TEST_DATABASE_URL = $env:WAYDAY_DATABASE_URL
    & $apiPython -m pytest services/api -q
    if ($LASTEXITCODE) { throw 'PostGIS/API verification failed.' }
    $health = Invoke-RestMethod http://127.0.0.1:8780/health -TimeoutSec 8
    if ($health.status -ne 'ready' -or $health.catalog_mode -ne 'postgis') {
        throw 'The running API is not ready in PostGIS mode.'
    }
    Write-Host "Live PostGIS API ready; source date $($health.source_date)."
} finally {
    $env:WAYDAY_TEST_DATABASE_URL = $previousTestUrl
    Pop-Location
}

$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$apiPython = Join-Path $repositoryRoot '.tools/api-venv/Scripts/python.exe'
if (-not (Test-Path -LiteralPath $apiPython) -or
    -not (Test-Path -LiteralPath (Join-Path $repositoryRoot 'data/generated/pasig-places.json'))) {
    throw 'Run .\tool\prepare-places.ps1 to prepare the Python environment and catalog first.'
}
. (Join-Path $PSScriptRoot 'places-environment.ps1')
Set-WaydayDatabaseEnvironment -RepositoryRoot $repositoryRoot -PromptAndSave
Push-Location $repositoryRoot
try {
    docker compose -f services/api/compose.yaml up -d
    if ($LASTEXITCODE) { throw 'Could not start the local Wayday database. Check Docker Desktop.' }
    $ready = $false
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        docker compose -f services/api/compose.yaml exec -T places-db pg_isready -U wayday -d wayday *> $null
        if ($LASTEXITCODE -eq 0) { $ready = $true; break }
        Start-Sleep -Seconds 1
    }
    if (-not $ready) { throw 'The Wayday database did not become ready.' }
    & $apiPython services/api/tools/import_postgis.py
    if ($LASTEXITCODE) { throw 'Database import failed; inspect the error before restarting search.' }
    Write-Host 'Wayday PostGIS catalog prepared. Start the API with .\tool\start-places.ps1.'
} finally { Pop-Location }

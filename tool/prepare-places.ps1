param([switch]$Refresh)
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Push-Location $repositoryRoot
try {
    $apiPython = Join-Path $repositoryRoot '.tools/api-venv/Scripts/python.exe'
    if (-not (Test-Path -LiteralPath $apiPython)) {
        python -m venv .tools/api-venv
        if ($LASTEXITCODE) { throw 'Could not create the local API environment.' }
    }
    & $apiPython -m pip install -r services/api/requirements.lock
    if ($LASTEXITCODE) { throw 'Could not install API dependencies.' }
    if ($Refresh -or -not (Test-Path -LiteralPath 'data/generated/pasig-places.json')) {
        & $apiPython services/api/tools/download_extract.py
        if ($LASTEXITCODE) { throw 'Extract download failed; previous catalog retained.' }
        & $apiPython services/api/tools/import_places.py data/downloads/metro_manila.osm.pbf --metadata data/downloads/metro_manila.osm.json
        if ($LASTEXITCODE) { throw 'Catalog import failed; previous catalog retained.' }
    }
    Write-Host 'Pilot snapshot prepared. Next run .\tool\prepare-places-db.ps1, then .\tool\start-places.ps1.'
} finally { Pop-Location }

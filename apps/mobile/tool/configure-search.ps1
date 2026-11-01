param()
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$environmentFile = Join-Path $repositoryRoot '.env.local'
$values = @{}
if (Test-Path -LiteralPath $environmentFile) {
    foreach ($line in [IO.File]::ReadAllLines($environmentFile)) {
        if ($line -match '^\s*(GEOAPIFY_API_KEY|LOCATIONIQ_API_KEY|GOOGLE_MAPS_ANDROID_API_KEY|GOOGLE_ROUTES_API_KEY)\s*=\s*(.*?)\s*$') {
            $values[$Matches[1]] = $Matches[2].Trim('"', "'")
        }
    }
}
$configurationFolder = Join-Path $repositoryRoot '.tools'
New-Item -ItemType Directory -Path $configurationFolder -Force | Out-Null
$configurationPath = Join-Path $configurationFolder 'search-defines.json'
[IO.File]::WriteAllText($configurationPath, (ConvertTo-Json -InputObject $values), [Text.UTF8Encoding]::new($false))
Write-Output $configurationPath

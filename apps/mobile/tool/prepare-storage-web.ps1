# Pinned, checksummed browser runtime for Drift 2.35.2. Generated assets stay
# ignored; run after pub get and before flutter run/build for the web preview.
$ErrorActionPreference = 'Stop'
$mobileRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$lockText = Get-Content -LiteralPath (Join-Path $mobileRoot 'pubspec.lock') -Raw
if ($lockText -notmatch '(?ms)^  drift:\r?\n.*?^    version: "2\.35\.2"') {
    throw 'Review the pinned web assets after changing the locked Drift version.'
}
$storageAssets = @(
    @{ Name = 'drift_worker.js'; Sha256 = '191fc9db018d2bbecb1723e81118fcf2c5c094df8644c2fcba2ed51df061e90a' },
    @{ Name = 'sqlite3.wasm'; Sha256 = 'fbcd2e8214f9231ea961e1b7706a22dd1194cfbfe6f26f13841b5aa7a0be1a1f' }
)
foreach ($storageAsset in $storageAssets) {
    $storagePath = Join-Path $mobileRoot "web/$($storageAsset.Name)"
    if (Test-Path -LiteralPath $storagePath) {
        if ((Get-FileHash -LiteralPath $storagePath -Algorithm SHA256).Hash.ToLowerInvariant() -eq $storageAsset.Sha256) { continue }
    }
    $downloadPath = "$storagePath.download"
    try {
        Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/simolus3/drift/releases/download/drift-2.35.2/$($storageAsset.Name)" -OutFile $downloadPath
        if ((Get-FileHash -LiteralPath $downloadPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $storageAsset.Sha256) {
            throw "Checksum mismatch for $($storageAsset.Name)."
        }
        Move-Item -LiteralPath $downloadPath -Destination $storagePath -Force
    } finally {
        if (Test-Path -LiteralPath $downloadPath) { Remove-Item -LiteralPath $downloadPath }
    }
}
Write-Output 'Pinned Drift browser assets are ready.'

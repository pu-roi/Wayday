param([string]$TargetPlatform = 'android-x64')
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$tools = Join-Path $root '.tools'
New-Item -ItemType Directory -Force -Path $tools | Out-Null
$signing = Join-Path $tools ('distribution-check-' + [Guid]::NewGuid().ToString('N') + '.jks')
$defines = Join-Path $tools 'distribution-public-defines.json'
$flutter = Join-Path $tools 'flutter/bin/flutter.bat'
if (-not (Test-Path -LiteralPath $flutter)) { $flutter = (Get-Command flutter -ErrorAction Stop).Source }
$keytool = if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME 'bin/keytool.exe' } else { '' }
if (-not (Test-Path -LiteralPath $keytool)) { $keytool = Join-Path $env:ProgramFiles 'Android/Android Studio/jbr/bin/keytool.exe' }
if (-not (Test-Path -LiteralPath $keytool)) { $keytool = (Get-Command keytool -ErrorAction Stop).Source }
$previous = @{}
foreach ($key in @('WAYDAY_RELEASE_STORE_FILE','WAYDAY_RELEASE_STORE_PASSWORD','WAYDAY_RELEASE_KEY_ALIAS','WAYDAY_RELEASE_KEY_PASSWORD','PUB_CACHE','GRADLE_USER_HOME','GRADLE_OPTS')) {
    $previous[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
}
try {
    $env:WAYDAY_RELEASE_STORE_FILE = $signing
    $env:WAYDAY_RELEASE_STORE_PASSWORD = [Guid]::NewGuid().ToString('N')
    $env:WAYDAY_RELEASE_KEY_PASSWORD = $env:WAYDAY_RELEASE_STORE_PASSWORD
    $env:WAYDAY_RELEASE_KEY_ALIAS = 'disposable-check'
    $env:PUB_CACHE = Join-Path $tools 'pub-cache'
    $env:GRADLE_USER_HOME = Join-Path $tools 'gradle'
    $env:GRADLE_OPTS = '-Dorg.gradle.jvmargs=-Xmx3g -Dorg.gradle.workers.max=2'
    & $keytool -genkeypair -keystore $signing -alias disposable-check -storepass:env WAYDAY_RELEASE_STORE_PASSWORD -keypass:env WAYDAY_RELEASE_KEY_PASSWORD -dname 'CN=Disposable build verification' -keyalg RSA -validity 2
    if ($LASTEXITCODE -ne 0) { throw 'Disposable signing generation failed.' }
    py -3 (Join-Path $PSScriptRoot 'release.py') defines --fixture --output $defines
    if ($LASTEXITCODE -ne 0) { throw 'Public fixture configuration failed.' }
    Push-Location (Join-Path $root 'apps/mobile')
    try {
        & $flutter --suppress-analytics build apk --release --target-platform $TargetPlatform "--dart-define-from-file=$defines"
        if ($LASTEXITCODE -ne 0) { throw 'Release verification build failed.' }
    } finally { Pop-Location }
} finally {
    foreach ($key in $previous.Keys) { [Environment]::SetEnvironmentVariable($key, $previous[$key], 'Process') }
    if (Test-Path -LiteralPath $signing) { Remove-Item -LiteralPath $signing }
}

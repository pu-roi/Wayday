param(
    [string]$TestGatewayUrl,
    [string]$PublicConfiguration,
    [int]$VersionCode = 100005,
    [switch]$PrepareOnly,
    [string]$OutputDirectory,
    [switch]$SyncPublished
)

# Builds only the registered, release-signed Wayday Test application.
# Never installs, uninstalls, clears data, deploys or reads private provider keys.
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$ignoredRoot = [IO.Path]::GetFullPath((Join-Path $repositoryRoot '.tools'))
if ($SyncPublished) {
    & (Join-Path $ignoredRoot 'distribution-venv/Scripts/python.exe') (Join-Path $repositoryRoot 'tool/distribution/sync_test_release.py')
    if ($LASTEXITCODE -ne 0) { throw 'Published test synchronization did not complete. No phone operation occurred; inspect the verified binary and sync report before Run.' }
    return
}
if (-not $PublicConfiguration) { $PublicConfiguration = Join-Path $ignoredRoot 'public-full-test/public-defines.json' }
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $ignoredRoot 'alternative-navigation-phone' }
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
if (-not $OutputDirectory.StartsWith($ignoredRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Generated test configuration and APKs must remain inside the ignored repository .tools directory.'
}
$gatewayUri = $null
if (-not [Uri]::TryCreate($TestGatewayUrl, [UriKind]::Absolute, [ref]$gatewayUri) -or
    $gatewayUri.Scheme -ne 'https' -or -not $gatewayUri.Host -or $gatewayUri.UserInfo -or
    $gatewayUri.Query -or $gatewayUri.Fragment -or $gatewayUri.AbsolutePath -ne '/' -or
    -not $gatewayUri.IsDefaultPort) { throw 'Use the reviewed HTTPS origin of the isolated test gateway.' }
if ($gatewayUri.Host -eq 'wayday-gateway-793890374960.asia-southeast1.run.app') {
    throw 'The production gateway is not the reviewed isolated navigation test revision.'
}
if ($VersionCode -le 100004 -or $VersionCode -gt 2100000000) { throw 'Use a test version code newer than the existing 100004 test APK.' }
$configuration = Get-Content -Raw -LiteralPath $PublicConfiguration | ConvertFrom-Json
$required = @('WAYDAY_PUBLIC_BUILD','WAYDAY_GATEWAY_URL','GOOGLE_MAPS_ANDROID_API_KEY','WAYDAY_FIREBASE_APP_ID','WAYDAY_FIREBASE_API_KEY','WAYDAY_FIREBASE_PROJECT_ID','WAYDAY_RECAPTCHA_SITE_KEY')
$names = @($configuration.PSObject.Properties.Name)
if ($names.Count -ne $required.Count -or ($names | Where-Object { $_ -notin $required }) -or
    ($required | Where-Object { [string]::IsNullOrWhiteSpace([string]$configuration.$_) }) -or
    $configuration.WAYDAY_PUBLIC_BUILD -ne 'true' -or
    $configuration.WAYDAY_FIREBASE_APP_ID -ne '1:793890374960:android:dbe21167436a082af974f5' -or
    $configuration.WAYDAY_FIREBASE_PROJECT_ID -ne 'wayday-513016') {
    throw 'Use the existing seven-field public configuration for the registered Wayday Test identity. Private provider keys and production app identity are rejected.'
}
$prepared = [ordered]@{}
foreach ($name in $required) { $prepared[$name] = [string]$configuration.$name }
$prepared['WAYDAY_GATEWAY_URL'] = $TestGatewayUrl.TrimEnd('/')
$prepared['WAYDAY_PUBLIC_TEST'] = 'true'
$profile = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'tool/distribution/release-profile.json') | ConvertFrom-Json
foreach ($feature in $profile.features.PSObject.Properties) { $prepared[$feature.Name] = [string]$feature.Value }
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$definesPath = Join-Path $OutputDirectory 'public-defines.json'
[IO.File]::WriteAllText($definesPath, ($prepared | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
if ($PrepareOnly) { Write-Host 'Prepared the separate test-app configuration only. No build, device action, network request or deployment occurred.'; return }

$previousEnvironment = @{}
$environmentNames = @('JAVA_HOME','ANDROID_HOME','PUB_CACHE','GRADLE_USER_HOME','GRADLE_OPTS','WAYDAY_RELEASE_STORE_FILE','WAYDAY_RELEASE_STORE_PASSWORD','WAYDAY_RELEASE_KEY_ALIAS','WAYDAY_RELEASE_KEY_PASSWORD','ORG_GRADLE_PROJECT_WAYDAY_MAP_TEST')
foreach ($name in $environmentNames) { $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
try {
    if ($previousEnvironment['ORG_GRADLE_PROJECT_WAYDAY_MAP_TEST'] -eq 'true') { throw 'The public phone test cannot use the disposable .maptest identity.' }
    $env:JAVA_HOME = 'C:/Program Files/Android/Android Studio/jbr'
    $env:ANDROID_HOME = Join-Path $env:LOCALAPPDATA 'Android/Sdk'
    $adb = Join-Path $env:ANDROID_HOME 'platform-tools/adb.exe'
    $devices = & $adb devices
    foreach ($line in $devices) {
        if ($line -match '^(\S+)\s+device$') {
            $deviceId = $Matches[1]
            $installed = & $adb -s $deviceId shell dumpsys package dev.wayday.wayday.publictest 2>$null
            if ($LASTEXITCODE -eq 0 -and ($installed -join "`n") -match 'versionCode=(\d+)') {
                $VersionCode = [Math]::Max($VersionCode, [int]$Matches[1] + 1)
            }
        }
    }
    $env:PUB_CACHE = Join-Path $ignoredRoot 'pub-cache'
    $env:GRADLE_USER_HOME = Join-Path $ignoredRoot 'gradle'
    $env:GRADLE_OPTS = '-Dorg.gradle.jvmargs=-Xmx3g -Dorg.gradle.workers.max=2'
    $env:WAYDAY_RELEASE_STORE_FILE = 'E:/Files/WaydaySigning/wayday-release.p12'
    $env:WAYDAY_RELEASE_KEY_ALIAS = 'wayday-release'
    if (-not (Test-Path -LiteralPath $env:WAYDAY_RELEASE_STORE_FILE)) { throw 'The existing permanent release signing file is unavailable.' }
    Write-Host 'Build only: Wayday Test, package dev.wayday.wayday.publictest. Nothing will be installed.'
    $securePassword = Read-Host 'Enter the existing release-keystore password locally (not saved)' -AsSecureString
    $credential = New-Object Management.Automation.PSCredential('wayday-release', $securePassword)
    $env:WAYDAY_RELEASE_STORE_PASSWORD = $credential.GetNetworkCredential().Password
    $env:WAYDAY_RELEASE_KEY_PASSWORD = $env:WAYDAY_RELEASE_STORE_PASSWORD
    $certificate = & (Join-Path $env:JAVA_HOME 'bin/keytool.exe') -list -v -keystore $env:WAYDAY_RELEASE_STORE_FILE -alias $env:WAYDAY_RELEASE_KEY_ALIAS -storepass:env WAYDAY_RELEASE_STORE_PASSWORD 2>&1
    if ($LASTEXITCODE -ne 0 -or ($certificate -join "`n") -notmatch '8B:02:32:DD:12:85:3D:9B:D3:5B:19:8F:A9:C1:D3:65:6E:14:BA:E1:ED:0B:50:ED:EF:3F:A9:FA:D3:55:41:51') {
        throw 'The existing registered signing certificate could not be verified.'
    }
    $flutter = Join-Path $ignoredRoot 'flutter/bin/flutter.bat'
    $buildLog = Join-Path $OutputDirectory 'build.log'
    Push-Location (Join-Path $repositoryRoot 'apps/mobile')
    try {
        & $flutter --suppress-analytics build apk --release --target=lib/main.dart --build-name=0.1.0-navigation-test.3 "--build-number=$VersionCode" "--dart-define-from-file=$definesPath" *> $buildLog
        if ($LASTEXITCODE -ne 0) { throw 'The separate test build failed. See its ignored build.log; no installation occurred.' }
    } finally { Pop-Location }
    $builtApk = Join-Path $repositoryRoot 'apps/mobile/build/app/outputs/flutter-apk/app-release.apk'
    $analyzer = Join-Path $env:ANDROID_HOME 'cmdline-tools/latest/bin/apkanalyzer.bat'
    $applicationId = & $analyzer manifest application-id $builtApk 2>$null
    if ($LASTEXITCODE -ne 0 -or ($applicationId -join '').Trim() -ne 'dev.wayday.wayday.publictest') {
        throw 'The built APK did not verify as the isolated Wayday Test package. Do not install it.'
    }
    $actualVersion = & $analyzer manifest version-code $builtApk 2>$null
    if ($LASTEXITCODE -ne 0 -or ($actualVersion -join '').Trim() -ne [string]$VersionCode) {
        throw 'The APK version code did not match the requested test upgrade. Do not install it.'
    }
    $actualName = & $analyzer manifest version-name $builtApk 2>$null
    if ($LASTEXITCODE -ne 0 -or ($actualName -join '').Trim() -ne '0.1.0-navigation-test.3') {
        throw 'The APK version name did not match this test build. Do not install it.'
    }
    $badging = & (Join-Path $env:ANDROID_HOME 'build-tools/36.0.0/aapt2.exe') dump badging $builtApk 2>$null
    if ($LASTEXITCODE -ne 0 -or ($badging -join "`n") -notmatch "application-label:'Wayday Test'") {
        throw 'The APK label did not verify as Wayday Test. Do not install it.'
    }
    $signature = & (Join-Path $env:ANDROID_HOME 'build-tools/36.0.0/apksigner.bat') verify --verbose --print-certs $builtApk 2>&1
    if ($LASTEXITCODE -ne 0 -or ($signature -join "`n") -notmatch '8b0232dd12853d9bd35b198fa9c1d3656e14bae1ed0b50edef3fa9fad3554151') {
        throw 'The APK signature did not match the existing registered test identity.'
    }
    & (Join-Path $ignoredRoot 'distribution-venv/Scripts/python.exe') (Join-Path $repositoryRoot 'tool/distribution/check_navigation_reflection.py') --apk $builtApk --mapping (Join-Path $repositoryRoot 'apps/mobile/build/app/outputs/mapping/release/mapping.txt') *> (Join-Path $OutputDirectory 'navigation-reflection.json')
    if ($LASTEXITCODE -ne 0) { throw 'The minified Google Navigation access check failed. Do not install this APK.' }
    $testApk = Join-Path $OutputDirectory "wayday-navigation-test-$VersionCode.apk"
    Copy-Item -LiteralPath $builtApk -Destination $testApk
    # Android Studio launches this stable alias only after package/signature
    # checks have passed. It never falls back to the normal project build.
    Copy-Item -LiteralPath $testApk -Destination (Join-Path $OutputDirectory 'wayday-navigation-test.apk')
    $verified = [ordered]@{
        package='dev.wayday.wayday.publictest'; label='Wayday Test'; versionCode=$VersionCode;
        versionName='0.1.0-navigation-test.3'; sha256=(Get-FileHash -LiteralPath $testApk -Algorithm SHA256).Hash.ToLowerInvariant();
        bytes=(Get-Item -LiteralPath $testApk).Length; gateway=$TestGatewayUrl.TrimEnd('/');
        uiKitNavigationTargets=$true; navigationReflection='passed'; installed=$false
    }
    [IO.File]::WriteAllText((Join-Path $OutputDirectory 'verification.json'), ($verified | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
    & (Join-Path $PSScriptRoot 'configure-navigation-test-ide.ps1') -ApplicationBinary (Join-Path $OutputDirectory 'wayday-navigation-test.apk')
    Write-Host "Verified Wayday Test APK: $testApk"
    Write-Host 'The deployed Wayday application has not been replaced, uninstalled or modified.'
} finally {
    foreach ($name in $environmentNames) { [Environment]::SetEnvironmentVariable($name, $previousEnvironment[$name], 'Process') }
    $credential = $null
    $securePassword = $null
}

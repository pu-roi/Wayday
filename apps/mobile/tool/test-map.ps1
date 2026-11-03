param(
    [Parameter(Mandatory = $true)][string]$DeviceId,
    [string]$Target = 'integration_test/online_pin_test.dart',
    [switch]$GoogleSingleSample,
    [switch]$GoogleRealMap,
    [switch]$RecommendationRehearsal,
    [switch]$PlacesOnly,
    [switch]$UiKitIdProbe
)

$ErrorActionPreference = 'Stop'
if ($Target -eq 'integration_test/trip_place_ui_kit_probe_test.dart' -and
    (-not $UiKitIdProbe -or $DeviceId -notmatch '^emulator-[0-9]+$')) {
    throw 'The single UI Kit ID probe requires explicit -UiKitIdProbe and a disposable emulator.'
}
$adbExecutable = Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe'
if (-not (Test-Path -LiteralPath $adbExecutable)) { $adbExecutable = (Get-Command adb -ErrorAction Stop).Source }
# The Flutter launcher can uninstall a stale pre-build application identity on
# startup, independently of --no-uninstall (which controls test cleanup).
# Never launch this harness while the personal-data package is installed.
$personalPackage = & $adbExecutable -s $DeviceId shell pm list packages --user 0 dev.wayday.wayday 2>$null
if ($LASTEXITCODE -ne 0) { throw 'Could not verify personal-app isolation. Integration test stopped.' }
if ($personalPackage -match '^package:dev\.wayday\.wayday$') {
    throw 'The personal Wayday package is installed. Use a disposable emulator without that package; this test harness is blocked to protect its data.'
}
$previousMapTest = [Environment]::GetEnvironmentVariable('ORG_GRADLE_PROJECT_WAYDAY_MAP_TEST', 'Process')
try {
    $env:ORG_GRADLE_PROJECT_WAYDAY_MAP_TEST = 'true'
    $testArguments = @('test', $Target, '-d', $DeviceId, '--no-uninstall')
    if ($Target -eq 'integration_test/trip_place_ui_kit_probe_test.dart') {
        # Only the already-restricted native SDK key enters this debug fixture.
        # Do not copy private REST-provider credentials or released app identity.
        $repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
        $public = Get-Content -Raw (Join-Path $repositoryRoot '.tools/public-full-test/public-defines.json') | ConvertFrom-Json
        if ($public.WAYDAY_FIREBASE_APP_ID -ne '1:793890374960:android:dbe21167436a082af974f5' -or
            [string]::IsNullOrWhiteSpace($public.GOOGLE_MAPS_ANDROID_API_KEY)) {
            throw 'The existing public-test SDK configuration is unavailable.'
        }
        $configuration = Join-Path $repositoryRoot '.tools/trip-switch-qualification/sdk-defines.json'
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $configuration) | Out-Null
        [IO.File]::WriteAllText($configuration, (@{GOOGLE_MAPS_ANDROID_API_KEY=$public.GOOGLE_MAPS_ANDROID_API_KEY} | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
        $testArguments += '--dart-define-from-file=' + $configuration
        $testArguments += '--dart-define=WAYDAY_LIVE_UI_KIT_ID_PROBE=true'
    }
    if ($Target -eq 'integration_test/recommendation_live_test.dart') {
        if (-not $RecommendationRehearsal) { throw 'The live recommendation rehearsal must be requested explicitly.' }
        $configuration = & (Join-Path $PSScriptRoot 'configure-search.ps1')
        $testArguments += '--dart-define-from-file=' + $configuration
        $testArguments += '--dart-define=WAYDAY_LIVE_RECOMMENDATION_REHEARSAL=true'
        if ($PlacesOnly) { $testArguments += '--dart-define=WAYDAY_LIVE_PLACES_ONLY=true' }
    }
    if ($Target -in @('integration_test/google_search_test.dart', 'integration_test/planning_google_map_test.dart')) {
        $configuration = & (Join-Path $PSScriptRoot 'configure-search.ps1')
        $testArguments += '--dart-define-from-file=' + $configuration
        if ($GoogleSingleSample) { $testArguments += '--dart-define=WAYDAY_GOOGLE_SINGLE_SAMPLE=true' }
        if ($GoogleRealMap) { $testArguments += '--dart-define=WAYDAY_GOOGLE_REAL_MAP=true' }
    }
    # Flutter can retain the pre-build package ID during cleanup. Keep cleanup
    # disabled as well as isolating the built APK from the personal-data app.
    & (Join-Path $PSScriptRoot 'flutter.ps1') -FlutterArguments $testArguments
    $testExitCode = $LASTEXITCODE
} finally {
    [Environment]::SetEnvironmentVariable('ORG_GRADLE_PROJECT_WAYDAY_MAP_TEST', $previousMapTest, 'Process')
}
exit $testExitCode

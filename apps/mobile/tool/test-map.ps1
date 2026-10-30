param(
    [Parameter(Mandatory = $true)][string]$DeviceId,
    [string]$Target = 'integration_test/regional_map_test.dart',
    [switch]$GoogleSingleSample,
    [switch]$GoogleRealMap
)

$ErrorActionPreference = 'Stop'
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

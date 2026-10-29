param(
    [Parameter(Mandatory = $true)][string]$DeviceId,
    [string]$Target = 'integration_test/regional_map_test.dart',
    [switch]$GoogleSingleSample,
    [switch]$GoogleRealMap
)

$ErrorActionPreference = 'Stop'
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

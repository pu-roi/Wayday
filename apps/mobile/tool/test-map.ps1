param([Parameter(Mandatory = $true)][string]$DeviceId, [string]$Target = 'integration_test/regional_map_test.dart')

$ErrorActionPreference = 'Stop'
$previousMapTest = [Environment]::GetEnvironmentVariable('ORG_GRADLE_PROJECT_WAYDAY_MAP_TEST', 'Process')
try {
    $env:ORG_GRADLE_PROJECT_WAYDAY_MAP_TEST = 'true'
    # Flutter can retain the pre-build package ID during cleanup. Keep cleanup
    # disabled as well as isolating the built APK from the personal-data app.
    & (Join-Path $PSScriptRoot 'flutter.ps1') -FlutterArguments @(
        'test', $Target, '-d', $DeviceId, '--no-uninstall'
    )
    $testExitCode = $LASTEXITCODE
} finally {
    [Environment]::SetEnvironmentVariable('ORG_GRADLE_PROJECT_WAYDAY_MAP_TEST', $previousMapTest, 'Process')
}
exit $testExitCode

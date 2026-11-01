param(
    [Parameter(Mandatory = $true)][string]$DeviceId,
    [Parameter(Mandatory = $true)][ValidateSet('before','after')][string]$Variant,
    [string]$ApplicationBinary
)
$ErrorActionPreference = 'Stop'
$taskAdb = Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe'
if ($DeviceId -notmatch '^emulator-\d+$') { throw 'Map profiling is restricted to a disposable emulator.' }
$personal = & $taskAdb -s $DeviceId shell pm list packages --user 0 dev.wayday.wayday 2>$null
if ($LASTEXITCODE -ne 0 -or $personal -match '^package:dev\.wayday\.wayday$') {
    throw 'Could not establish personal-app isolation. Profiling stopped.'
}
if ($ApplicationBinary) {
    $ApplicationBinary = (Resolve-Path -LiteralPath $ApplicationBinary).Path
    $taskAapt = Join-Path $env:LOCALAPPDATA 'Android/Sdk/build-tools/36.0.0/aapt.exe'
    $binaryInfo = & $taskAapt dump badging $ApplicationBinary 2>$null
    if ($LASTEXITCODE -ne 0 -or -not ($binaryInfo -match "^package: name='dev\.wayday\.wayday\.maptest' ")) {
        throw 'Only a disposable maptest binary may be profiled.'
    }
}
$previous = [Environment]::GetEnvironmentVariable('ORG_GRADLE_PROJECT_WAYDAY_MAP_TEST','Process')
$previousDevice = [Environment]::GetEnvironmentVariable('WAYDAY_PROFILE_DEVICE','Process')
try {
    $env:ORG_GRADLE_PROJECT_WAYDAY_MAP_TEST = 'true'
    $env:WAYDAY_PROFILE_DEVICE = $DeviceId
    & $taskAdb -s $DeviceId shell dumpsys gfxinfo dev.wayday.wayday.maptest reset > $null
    $binaryArgs = @()
    if ($ApplicationBinary) { $binaryArgs = @("--use-application-binary=$ApplicationBinary") }
    # Keep the package/data even on driver failure; drive's default stop uninstalls.
    & (Join-Path $PSScriptRoot 'flutter.ps1') drive --profile --keep-app-running `
        --driver=test_driver/map_profile_driver.dart --target=integration_test/map_profile_test.dart `
        "--device-id=$DeviceId" "--dart-define=WAYDAY_PROFILE_VARIANT=$Variant" @binaryArgs
    $result = $LASTEXITCODE
} finally {
    [Environment]::SetEnvironmentVariable('ORG_GRADLE_PROJECT_WAYDAY_MAP_TEST',$previous,'Process')
    [Environment]::SetEnvironmentVariable('WAYDAY_PROFILE_DEVICE',$previousDevice,'Process')
}
exit $result

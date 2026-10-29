param([Parameter(ValueFromRemainingArguments = $true)][string[]]$FlutterArguments)

$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$localTools = Join-Path $repositoryRoot '.tools'
$localFlutter = Join-Path $localTools 'flutter/bin/flutter.bat'
if (Test-Path -LiteralPath $localFlutter) {
    $flutterExecutable = $localFlutter
    $env:PUB_CACHE = Join-Path $localTools 'pub-cache'
    $env:GRADLE_USER_HOME = Join-Path $localTools 'gradle'
    $localAndroid = Join-Path $localTools 'android-sdk'
    if (Test-Path -LiteralPath $localAndroid) { $env:ANDROID_HOME = $localAndroid }
    $localJdk = Get-ChildItem -LiteralPath (Join-Path $localTools 'jdk') -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $localJdk) { $env:JAVA_HOME = $localJdk.FullName }
} else {
    $flutterExecutable = (Get-Command flutter -ErrorAction Stop).Source
}

if ($FlutterArguments.Count -gt 0 -and $FlutterArguments[0] -in @('run', 'build', 'drive')) {
    $searchConfiguration = & (Join-Path $PSScriptRoot 'configure-search.ps1')
    $FlutterArguments += '--dart-define-from-file=' + $searchConfiguration
}

Push-Location (Join-Path $PSScriptRoot '..')
try {
    & $flutterExecutable --suppress-analytics @FlutterArguments
    $flutterExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $flutterExitCode

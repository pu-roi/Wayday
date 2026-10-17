$ErrorActionPreference = 'Stop'

$temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$fixtureRoot = Join-Path $temporaryRoot ('wayday-flutter-wrapper-' + [guid]::NewGuid().ToString('N'))
$fixtureTool = Join-Path $fixtureRoot 'apps/mobile/tool'
$fixtureFlutter = Join-Path $fixtureRoot '.tools/flutter/bin'

try {
    New-Item -ItemType Directory -Force $fixtureTool, $fixtureFlutter | Out-Null
    $wrapper = Join-Path $fixtureTool 'flutter.ps1'
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'flutter.ps1') -Destination $wrapper
    @'
@echo off
:next
if "%~1"=="" goto done
echo ARG:%~1
shift
goto next
:done
exit /b 37
'@ | Set-Content -LiteralPath (Join-Path $fixtureFlutter 'flutter.bat') -Encoding ASCII

    $shells = @(
        (Get-Command powershell.exe -ErrorAction Stop).Source
        (Get-Command pwsh.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
    ) | Where-Object { $_ } | Select-Object -Unique
    $cases = @(
        @{ Arguments = @('run', '--no-pub', '-d', 'emulator-5554') }
        @{ Arguments = @('devices', '-v') }
        @{ Arguments = @('build', 'apk', '--debug', '--target-platform', 'android-x64') }
        @{ Arguments = @('run', '--dart-define', 'NOTE=Weekend errands', '-d', 'emulator-5554') }
    )

    foreach ($shell in $shells) {
        foreach ($case in $cases) {
            $arguments = $case.Arguments
            $output = @(& $shell -NoProfile -ExecutionPolicy Bypass -File $wrapper @arguments)
            $exitCode = $LASTEXITCODE
            $actual = @($output | Where-Object { $_ -like 'ARG:*' } | ForEach-Object { $_.Substring(4) })
            $expected = @('--suppress-analytics') + $arguments
            if (($actual -join "`n") -cne ($expected -join "`n")) {
                throw "Flutter arguments changed in $shell. Expected [$($expected -join ', ')]; received [$($actual -join ', ')]."
            }
            if ($exitCode -ne 37) {
                throw "Flutter exit code changed in $shell. Expected 37; received $exitCode."
            }
        }
        Write-Output "PASS: $shell preserves Flutter flags, spaced values, argument order, and exit codes."
    }
} finally {
    $resolvedFixture = [IO.Path]::GetFullPath($fixtureRoot)
    $tempPrefix = $temporaryRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $resolvedFixture.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Refusing cleanup outside the temporary directory.'
    }
    if (Test-Path -LiteralPath $resolvedFixture) {
        Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
    }
}

param([string]$ProjectDirectory, [string]$ApplicationBinary)

# Run the registered test binary through Android Studio without rebuilding it
# with the IDE's ordinary debug certificate or private search configuration.
$ErrorActionPreference = 'Stop'
$mobileRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
if (-not $ProjectDirectory) { $ProjectDirectory = $mobileRoot }
$ProjectDirectory = [IO.Path]::GetFullPath($ProjectDirectory)
if ($ProjectDirectory -ne $mobileRoot -and -not $ProjectDirectory.StartsWith((Join-Path $repositoryRoot '.tools') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Use the mobile project or an ignored tooling-fixture project.'
}
if (-not $ApplicationBinary) { $ApplicationBinary = Join-Path $repositoryRoot '.tools/alternative-navigation-phone/wayday-navigation-test.apk' }
$binaryPath = [IO.Path]::GetFullPath($ApplicationBinary)
if (-not $binaryPath.StartsWith((Join-Path $repositoryRoot '.tools') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetExtension($binaryPath) -ne '.apk') {
    throw 'The prebuilt test APK must be inside the ignored repository .tools directory.'
}
$arguments = '--release --no-pub --use-application-binary="' + $binaryPath.Replace('\','/') + '"'
$encodedArguments = [Security.SecurityElement]::Escape($arguments)
$configuration = @'
<component name="ProjectRunConfigurationManager">
  <configuration default="false" name="Wayday Test" type="FlutterRunConfigurationType" factoryName="Flutter">
    <option name="additionalArgs" value="{ARGS}" />
    <option name="filePath" value="$PROJECT_DIR$/lib/main.dart" />
    <method v="2" />
  </configuration>
</component>
'@
$directory = Join-Path $ProjectDirectory '.idea/runConfigurations'
New-Item -ItemType Directory -Force -Path $directory | Out-Null
$output = Join-Path $directory 'Wayday_Test.xml'
[IO.File]::WriteAllText($output, $configuration.Replace('{ARGS}', $encodedArguments), (New-Object Text.UTF8Encoding($false)))
Write-Host 'Prepared Android Studio Run configuration: Wayday Test (prebuilt release APK).'
Write-Host 'The signed, verified test APK must exist before Run. This command does not build or touch a device.'

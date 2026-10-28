$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$pidPath = Join-Path $repositoryRoot 'data/local/places-api.pid'
if (-not (Test-Path -LiteralPath $pidPath)) { Write-Host 'No managed Wayday places process recorded.'; return }
$apiProcessId = [int](Get-Content -LiteralPath $pidPath -Raw)
$apiProcess = Get-CimInstance Win32_Process -Filter "ProcessId=$apiProcessId"
$expectedPython = Join-Path $repositoryRoot '.tools/api-venv/Scripts/python.exe'
if ($apiProcess -and $apiProcess.CommandLine -match 'uvicorn wayday_api.app:app' -and
    [IO.Path]::GetFullPath($apiProcess.ExecutablePath) -eq [IO.Path]::GetFullPath($expectedPython)) {
    # A Windows venv launcher can have a separate Python child owning the port.
    $children = Get-CimInstance Win32_Process -Filter "ParentProcessId=$apiProcessId"
    foreach ($child in $children) {
        if ($child.CommandLine -match 'uvicorn wayday_api.app:app' -and
            [IO.Path]::GetFileName($child.ExecutablePath) -in @('python.exe', 'pythonw.exe')) {
            Stop-Process -Id $child.ProcessId -ErrorAction SilentlyContinue
        }
    }
    Stop-Process -Id $apiProcessId -ErrorAction SilentlyContinue
    Write-Host 'Stopped the managed Wayday places API.'
} elseif ($apiProcess) {
    throw 'Recorded PID belongs to another command; nothing was stopped.'
}

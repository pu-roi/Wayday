param(
    [Parameter(Position = 0, Mandatory = $true)]
    [ValidateSet("list", "start", "done")]
    [string]$Command,

    [Parameter(Position = 1)]
    [string]$TaskId,

    [Parameter()]
    [string]$Notes = ""
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$pythonScript = Join-Path $scriptDir "track_task.py"

# Discover python or py launcher
if (Get-Command py -ErrorAction SilentlyContinue) {
    $pyExe = "py"
} elseif (Get-Command python -ErrorAction SilentlyContinue) {
    $pyExe = "python"
} else {
    Write-Error "Python 3 or the 'py' launcher was not found on PATH."
    exit 1
}

$argsList = @($pythonScript, $Command)
if ($TaskId) {
    $argsList += $TaskId
}
if ($Notes) {
    $argsList += "--notes"
    $argsList += $Notes
}

& $pyExe $argsList
exit $LASTEXITCODE

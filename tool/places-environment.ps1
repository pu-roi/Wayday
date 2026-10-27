# Shared local configuration. Credentials are never command-line arguments.
function Set-WaydayDatabaseEnvironment {
    param([string]$RepositoryRoot, [switch]$PromptAndSave)
    $credentialPath = Join-Path $RepositoryRoot 'data/local/places-db.credential.xml'
    if (Test-Path -LiteralPath $credentialPath) {
        # Export-Clixml encrypts SecureString with Windows DPAPI for this user.
        $credential = Import-Clixml -LiteralPath $credentialPath
    } elseif ($PromptAndSave) {
        $securePassword = if ($env:WAYDAY_DB_PASSWORD) {
            ConvertTo-SecureString $env:WAYDAY_DB_PASSWORD -AsPlainText -Force
        } else {
            Read-Host 'Local Wayday database password' -AsSecureString
        }
        $credential = [PSCredential]::new('wayday', $securePassword)
        New-Item -ItemType Directory -Force (Split-Path -Parent $credentialPath) | Out-Null
        $credential | Export-Clixml -LiteralPath $credentialPath
    } elseif ($env:WAYDAY_DB_PASSWORD) {
        $credential = [PSCredential]::new('wayday', (ConvertTo-SecureString $env:WAYDAY_DB_PASSWORD -AsPlainText -Force))
    } else {
        throw 'Run .\tool\prepare-places-db.ps1 to configure the local database first.'
    }
    if ($credential -isnot [PSCredential] -or $credential.UserName -ne 'wayday') {
        throw 'The local Wayday database credential is invalid.'
    }
    $env:WAYDAY_DB_PASSWORD = $credential.GetNetworkCredential().Password
    if (-not $env:WAYDAY_DB_PASSWORD) { throw 'The database password must not be empty.' }
    $encoded = [Uri]::EscapeDataString($env:WAYDAY_DB_PASSWORD)
    $env:WAYDAY_DATABASE_URL = "postgresql+psycopg://wayday:${encoded}@127.0.0.1:55432/wayday"
}

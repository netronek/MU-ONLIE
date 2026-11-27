$ErrorActionPreference = 'Stop'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Spustte PowerShell jako spravce.' }
$state = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'stav-server-test.json') -Raw | ConvertFrom-Json
foreach ($record in $state.files) {
    $target = Join-Path $state.serverRoot $record.path
    if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $record.newHash) {
        throw "Soubor byl po instalaci zmenen: $target. Nic neobnoveno; je nutna rucni kontrola."
    }
    if ($record.existed -and -not (Test-Path -LiteralPath (Join-Path $state.backup $record.path))) { throw "Chybi zaloha: $($record.path)" }
}
foreach ($record in $state.files) {
    $target = Join-Path $state.serverRoot $record.path
    if ($record.existed) { Copy-Item -LiteralPath (Join-Path $state.backup $record.path) -Destination $target -Force }
    else { Remove-Item -LiteralPath $target -Force }
}
Write-Host 'OBNOVENY PUVODNI SERVEROVE SOUBORY. Dalsi krok: Reload Item a Reload Script.' -ForegroundColor Green
Write-Host 'Klientsky main.premium a item_eng.bmd je nutne vratit samostatne z klientskych zaloh.'

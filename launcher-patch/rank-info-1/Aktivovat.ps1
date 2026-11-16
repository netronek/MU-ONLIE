$ErrorActionPreference = 'Stop'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Spustte Windows PowerShell jako spravce (Spustit jako spravce), pak skript zopakujte.' }
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$root = 'C:\AternixUpdates'
$state = Get-Content (Join-Path $PSScriptRoot 'stav.json') -Raw | ConvertFrom-Json
$active = Join-Path $root 'manifest.json'
$next = Join-Path $root 'manifest.NEW.json'
if ((Get-FileHash $active -Algorithm SHA256).Hash -ne $state.previousManifestHash -or (Get-FileHash $next -Algorithm SHA256).Hash -ne $state.nextManifestHash) { throw 'Manifest byl zmenen. Je nutna nova kontrola.' }
$manifest = Get-Content $next -Raw | ConvertFrom-Json
$temp = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString('N') + '.bin')
try {
    foreach ($item in $manifest.files) {
        $downloadPath = $item.path
        if ($item.path -ceq 'main.premium') { $downloadPath = 'main.premium.rank-info-1.premium' }
        $url = 'https://patch.aternixmu.eu/files/' + $downloadPath + '?verify=' + [guid]::NewGuid().ToString('N')
        Invoke-WebRequest -Uri $url -OutFile $temp -UseBasicParsing -TimeoutSec 60
        if ((Get-Item $temp).Length -ne $item.size -or (Get-FileHash $temp -Algorithm SHA256).Hash -ne $item.sha256) { throw "Nesouhlasi soubor pres HTTPS: $($item.path)" }
        Write-Host "OK: $($item.path)" -ForegroundColor Green
    }
    if ((Get-FileHash $active -Algorithm SHA256).Hash -ne $state.previousManifestHash -or (Get-FileHash $next -Algorithm SHA256).Hash -ne $state.nextManifestHash) { throw 'Manifest se behem kontroly zmenil.' }
    $payload = Join-Path $root 'files\main.premium'
    $staged = Join-Path $root 'files\main.premium.rank-info-1.premium'
    $entry = @($manifest.files | Where-Object { $_.path -ceq 'main.premium' })[0]
    if ((Get-Item $staged).Length -ne $entry.size -or (Get-FileHash $staged -Algorithm SHA256).Hash -ne $entry.sha256) { throw 'Pripraveny main.premium se zmenil.' }
    $oldEntry = @((Get-Content $active -Raw | ConvertFrom-Json).files | Where-Object { $_.path -ceq 'main.premium' })[0]
    if ((Get-Item $payload).Length -ne $oldEntry.size -or (Get-FileHash $payload -Algorithm SHA256).Hash -ne $oldEntry.sha256) { throw 'Aktivni main.premium neodpovida puvodnimu manifestu.' }
    $payloadBackup = Join-Path $state.backup ('main-before-activation-' + [guid]::NewGuid().ToString('N') + '.premium')
    [IO.File]::Replace($staged, $payload, $payloadBackup)
    try {
        [IO.File]::Replace($next, $active, (Join-Path $state.backup ('manifest-at-activation-' + [guid]::NewGuid().ToString('N') + '.json')))
    } catch {
        [IO.File]::Replace($payloadBackup, $payload, (Join-Path $state.backup ('failed-new-' + [guid]::NewGuid().ToString('N') + '.premium')))
        throw
    }
    Write-Host "PATCH AKTIVNI: $($manifest.version), $(@($manifest.files).Count) souboru." -ForegroundColor Green
} finally {
    Remove-Item $temp -Force -ErrorAction SilentlyContinue
}

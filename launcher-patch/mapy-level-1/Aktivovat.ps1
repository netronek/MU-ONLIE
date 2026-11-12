$ErrorActionPreference = 'Stop'
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
        $url = 'https://patch.aternixmu.eu/files/' + $item.path + '?verify=' + [guid]::NewGuid().ToString('N')
        Invoke-WebRequest -Uri $url -OutFile $temp -UseBasicParsing -TimeoutSec 60
        if ((Get-Item $temp).Length -ne $item.size -or (Get-FileHash $temp -Algorithm SHA256).Hash -ne $item.sha256) { throw "Nesouhlasi soubor pres HTTPS: $($item.path)" }
        Write-Host "OK: $($item.path)" -ForegroundColor Green
    }
    if ((Get-FileHash $active -Algorithm SHA256).Hash -ne $state.previousManifestHash -or (Get-FileHash $next -Algorithm SHA256).Hash -ne $state.nextManifestHash) { throw 'Manifest se behem kontroly zmenil.' }
    [IO.File]::Replace($next, $active, (Join-Path $state.backup ('manifest-at-activation-' + [guid]::NewGuid().ToString('N') + '.json')))
    Write-Host "PATCH AKTIVNI: $($manifest.version), $(@($manifest.files).Count) souboru." -ForegroundColor Green
} finally {
    Remove-Item $temp -Force -ErrorAction SilentlyContinue
}

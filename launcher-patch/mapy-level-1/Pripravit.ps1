$ErrorActionPreference = 'Stop'
$root = 'C:\AternixUpdates'
$source = $PSScriptRoot
$expected = Get-Content (Join-Path $source 'base-manifest.json') -Raw | ConvertFrom-Json
$current = Get-Content (Join-Path $root 'manifest.json') -Raw | ConvertFrom-Json
if ($current.version -ne $expected.version -or @($current.files).Count -ne @($expected.files).Count) { throw 'Manifest se mezitim zmenil. Nic nebylo zmeneno.' }
foreach ($item in $expected.files) {
    $match = @($current.files | Where-Object { $_.path -ceq $item.path })
    if ($match.Count -ne 1 -or $match[0].size -ne $item.size -or $match[0].sha256 -ne $item.sha256) { throw "Manifest se lisi: $($item.path)" }
}
$new = Get-Content (Join-Path $source 'manifest.NEW.json') -Raw | ConvertFrom-Json
$entry = @($new.files | Where-Object { $_.path -ceq 'main.premium' })[0]
$payload = Join-Path $source 'files\main.premium'
if ((Get-Item $payload).Length -ne $entry.size -or (Get-FileHash $payload -Algorithm SHA256).Hash -ne $entry.sha256) { throw 'Nesouhlasi kontrolni soucet main.premium.' }
$backup = Join-Path 'C:\Tools\AternixPatchBackups' ('mapy-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $backup | Out-Null
Copy-Item (Join-Path $root 'manifest.json') (Join-Path $backup 'manifest.json')
Copy-Item (Join-Path $root 'web.config') (Join-Path $backup 'web.config')
$target = Join-Path $root 'files\main.premium'
if (Test-Path $target) { Copy-Item $target (Join-Path $backup 'main.premium') }
[xml]$config = Get-Content (Join-Path $root 'web.config') -Raw
$static = $config.SelectSingleNode('/configuration/system.webServer/staticContent')
if ($null -eq $static) { throw 'V web.config chybi staticContent. Je nutna rucni kontrola.' }
foreach ($node in @($static.SelectNodes("*[@fileExtension='.premium']"))) { [void]$static.RemoveChild($node) }
$remove = $config.CreateElement('remove'); $remove.SetAttribute('fileExtension','.premium'); [void]$static.AppendChild($remove)
$mime = $config.CreateElement('mimeMap'); $mime.SetAttribute('fileExtension','.premium'); $mime.SetAttribute('mimeType','application/octet-stream'); [void]$static.AppendChild($mime)
$config.Save((Join-Path $root 'web.config'))
Copy-Item $payload $target -Force
Copy-Item (Join-Path $source 'manifest.NEW.json') (Join-Path $root 'manifest.NEW.json') -Force
$state = @{ backup = $backup; previousManifestHash = (Get-FileHash (Join-Path $root 'manifest.json') -Algorithm SHA256).Hash; nextManifestHash = (Get-FileHash (Join-Path $root 'manifest.NEW.json') -Algorithm SHA256).Hash }
$state | ConvertTo-Json | Set-Content (Join-Path $source 'stav.json') -Encoding UTF8
Write-Host 'PRIPRAVENO. Aktivni manifest zustava puvodni.' -ForegroundColor Green
Write-Host "Zaloha: $backup"

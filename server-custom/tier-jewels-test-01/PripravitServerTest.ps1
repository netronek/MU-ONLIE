param([string]$ServerRoot = 'C:\MU ONLINE\MuServer_Season_6_Update_42')
$ErrorActionPreference = 'Stop'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Otevrete Windows PowerShell jako spravce a skript zopakujte.'
}
$package = $PSScriptRoot
$checks = Get-Content -LiteralPath (Join-Path $package 'package-manifest.json') -Raw | ConvertFrom-Json
$rules = Get-Content -LiteralPath (Join-Path $package 'verification.json') -Raw | ConvertFrom-Json
foreach ($entry in $checks.files) {
    $file = Join-Path $package ($entry.path.Replace('/', '\'))
    if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $entry.sha256) {
        throw "Poskozeny balik: $($entry.path)"
    }
}
$expected = @{
    'Data\Item\Item.txt' = $rules.original_hashes.'server_Item.txt'
    'Data\Custom\CustomJewel.txt' = $rules.original_hashes.'server_CustomJewel.txt'
}
foreach ($path in $expected.Keys) {
    $file = Join-Path $ServerRoot $path
    if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $expected[$path]) {
        throw "Aktualni soubor se lisi od zaslaneho podkladu: $file. Nic nebylo zmeneno. Poslete aktualni kopii ke slouceni."
    }
}
$loader = Join-Path $ServerRoot 'Data\Script\ScriptMain.lua'
$lines = @(Get-Content -LiteralPath $loader | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith('--') })
if ($lines.Count -ne 2 -or $lines[0] -cne "require('System\\ScriptCore')" -or $lines[1] -cne "require('Scripts\\AternixTierProbe')") {
    throw 'ScriptMain.lua neodpovida dvouradkove funkcni diagnostice. Nic nebylo zmeneno; je nutna kontrola slouceni.'
}
$common = Join-Path $ServerRoot 'GameServer\Data\GameServerInfo - Common.dat'
if (-not (Select-String -LiteralPath $common -Pattern '^\s*ScriptSystemEnable\s*=\s*1\s*(;.*)?$' -Quiet)) {
    throw 'Lua neni zapnuta v Common.dat. Nic nebylo zmeneno.'
}
$paths = @(
    'Data\Item\Item.txt',
    'Data\Custom\CustomJewel.txt',
    'Data\Script\ScriptMain.lua',
    'Data\Script\Scripts\AternixTierJewels.lua',
    'Data\Script\Scripts\AternixTierJewelsConfig.lua'
)
$backup = Join-Path 'C:\Tools\AternixJewelBackups' ('tier-test-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $backup | Out-Null
$records = @()
foreach ($path in $paths) {
    $target = Join-Path $ServerRoot $path
    $saved = Join-Path $backup $path
    $exists = Test-Path -LiteralPath $target
    if ($exists) {
        New-Item -ItemType Directory -Path (Split-Path $saved -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $target -Destination $saved
    }
    $source = Join-Path (Join-Path $package 'server') $path
    $records += [pscustomobject]@{ path=$path; existed=$exists; newHash=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash }
}
$state = [pscustomobject]@{ serverRoot=$ServerRoot; backup=$backup; files=$records }
$state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $package 'stav-server-test.json') -Encoding UTF8
try {
    foreach ($record in $records) {
        $target = Join-Path $ServerRoot $record.path
        New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path (Join-Path $package 'server') $record.path) -Destination $target -Force
        if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $record.newHash) { throw "Chyba zapisu: $target" }
    }
} catch {
    foreach ($record in $records) {
        $target = Join-Path $ServerRoot $record.path
        if ($record.existed) { Copy-Item -LiteralPath (Join-Path $backup $record.path) -Destination $target -Force }
        elseif (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Force }
    }
    throw
}
Write-Host 'SERVEROVE SOUBORY PRIPRAVENY. Zatim NEBYL proveden Reload ani restart.' -ForegroundColor Green
Write-Host "Zaloha: $backup"
Write-Host 'Nepublikovat klientsky patch hracum. Dalsi krok je kontrolovane lokalni testovani.'

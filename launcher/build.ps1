$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe'
if (-not (Test-Path $compiler)) { throw 'Chybí .NET Framework 4.8.' }
$output = Join-Path $here 'build'
New-Item -ItemType Directory -Force $output | Out-Null
$arguments = @('/nologo', '/target:winexe', '/platform:x86', '/optimize+', '/warnaserror+',
    '/reference:System.dll', '/reference:System.Core.dll', '/reference:System.Drawing.dll', '/reference:System.Windows.Forms.dll',
    ('/out:' + (Join-Path $output 'AternixMU.Launcher.exe')), (Join-Path $here 'EclipseLauncher.cs'))
& $compiler @arguments
if ($LASTEXITCODE -ne 0) { throw 'Sestavení selhalo.' }
# Keep a unique internal assembly name: the engine's original identity is MuLauncher.
Copy-Item (Join-Path $output 'AternixMU.Launcher.exe') (Join-Path $output 'MuLauncher.exe') -Force
Write-Host 'HOTOVO - build\MuLauncher.exe. Pouzijte s Aternix.Engine.dll a assets z Eclipse ZIPu.'

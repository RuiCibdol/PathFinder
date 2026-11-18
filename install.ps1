# Copies PathFinder into the WoW client's AddOns folder. Usage: .\install.ps1 [-Wow "D:\Games\World of Warcraft"] [-Flavor _forever_]
param(
    [string]$Wow,
    [string]$Flavor
)
$ErrorActionPreference = 'Stop'
$candidates = @(@($Wow, "C:\Program Files (x86)\World of Warcraft", "C:\Program Files\World of Warcraft") | Where-Object { $_ -and (Test-Path $_) })
if (-not $candidates) { throw "World of Warcraft folder not found. Pass it with -Wow <folder>." }
$root = $candidates[0]
$flavors = if ($Flavor) { @($Flavor) } else { @('_forever_', '_classic_beta_') }
$client = $flavors | ForEach-Object { Join-Path $root $_ } | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $client) { throw "No client folder ($($flavors -join ', ')) under $root." }
$dest = Join-Path $client 'Interface\AddOns\PathFinder'
New-Item -ItemType Directory -Force $dest | Out-Null
$src = $PSScriptRoot
Get-ChildItem $src -Force | Where-Object { $_.Name -notin @('.git', '.gitignore', 'install.ps1', 'README.md') } |
    ForEach-Object { Copy-Item $_.FullName $dest -Recurse -Force }
Write-Host "Installed to $dest"
Write-Host "Next: install AutoHotkey v2 and run $dest\AHK\PathFinder.ahk (leave it running)."

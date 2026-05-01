$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

$toolsRoot = Join-Path $repoRoot ".tools"
$hererocksRoot = Join-Path $toolsRoot "hererocks54"
$luarocksBat = Join-Path $hererocksRoot "bin/luarocks.bat"
$styluaDir = Join-Path $toolsRoot "stylua"
$styluaExe = Join-Path $styluaDir "stylua.exe"
$luaLsDir = Join-Path $toolsRoot "lua-language-server"
$luaLsExe = Join-Path $luaLsDir "bin/lua-language-server.exe"

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
  throw "python was not found in PATH. Install Python 3 first."
}

Write-Host "[1/6] Ensuring hererocks is available..."
$hasHererocks = $true
try {
  & python -m hererocks --help *> $null
} catch {
  $hasHererocks = $false
}

if (-not $hasHererocks) {
  & python -m pip install --user hererocks
}

Write-Host "[2/6] Ensuring local Lua + LuaRocks environment..."
if (-not (Test-Path $luarocksBat)) {
  & python -m hererocks $hererocksRoot -l 5.4 -r latest
}

$configPath = Join-Path $hererocksRoot "luarocks/config-5.4.lua"
if (Test-Path $configPath) {
  $configContent = Get-Content -Raw -Path $configPath
  $patchedConfig = $configContent -replace "MSVCRT = 'MSVCR80'", "MSVCRT = 'msvcrt'"
  if ($patchedConfig -ne $configContent) {
    Set-Content -Path $configPath -Value $patchedConfig -Encoding ASCII
  }
}

Write-Host "[3/6] Ensuring luacheck is installed..."
$luacheckInstalled = $false
try {
  $luacheckInstalled = (& $luarocksBat list --porcelain luacheck 2>$null) -match "^luacheck\s"
} catch {
  $luacheckInstalled = $false
}

if (-not $luacheckInstalled) {
  & $luarocksBat install luacheck
}

Write-Host "[4/6] Ensuring Stylua binary is installed..."
if (-not (Test-Path $styluaExe)) {
  $release = Invoke-RestMethod -Uri "https://api.github.com/repos/JohnnyMorganz/StyLua/releases/latest" -Headers @{ "User-Agent" = "WhisperMessenger" }
  $asset = $release.assets | Where-Object { $_.name -match "windows-x86_64\.zip$" } | Select-Object -First 1

  if (-not $asset) {
    throw "Could not find windows-x86_64 Stylua release asset."
  }

  New-Item -ItemType Directory -Path $styluaDir -Force | Out-Null

  $tmpZip = Join-Path $env:TEMP $asset.name
  $tmpExtract = Join-Path $env:TEMP ("stylua-" + [Guid]::NewGuid().ToString())

  Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tmpZip
  Expand-Archive -Path $tmpZip -DestinationPath $tmpExtract -Force

  $downloadedExe = Get-ChildItem -Path $tmpExtract -Recurse -Filter "stylua.exe" | Select-Object -First 1
  if (-not $downloadedExe) {
    throw "Downloaded Stylua archive did not contain stylua.exe"
  }

  Copy-Item -Path $downloadedExe.FullName -Destination $styluaExe -Force

  Remove-Item -Path $tmpZip -Force -ErrorAction SilentlyContinue
  Remove-Item -Path $tmpExtract -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "[5/6] Ensuring LuaLS binary is installed..."
if (-not (Test-Path $luaLsExe)) {
  $release = Invoke-RestMethod -Uri "https://api.github.com/repos/LuaLS/lua-language-server/releases/latest" -Headers @{ "User-Agent" = "WhisperMessenger" }
  $asset = $release.assets | Where-Object { $_.name -match "(win32|windows).*(x64|x86_64).*\.zip$" } | Select-Object -First 1

  if (-not $asset) {
    throw "Could not find x64 Windows LuaLS release asset."
  }

  New-Item -ItemType Directory -Path $luaLsDir -Force | Out-Null

  $tmpZip = Join-Path $env:TEMP $asset.name

  Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tmpZip
  Expand-Archive -Path $tmpZip -DestinationPath $luaLsDir -Force

  if (-not (Test-Path $luaLsExe)) {
    throw "LuaLS archive extraction did not produce $luaLsExe"
  }

  Remove-Item -Path $tmpZip -Force -ErrorAction SilentlyContinue
}

Write-Host "[6/6] Done."
Write-Host "Run lint with: bash scripts/lint.sh"
Write-Host "Auto-fix formatting with: bash scripts/lint.sh --fix"

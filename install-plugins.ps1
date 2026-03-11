$ErrorActionPreference = 'Stop'
$pluginsDir = Join-Path $PSScriptRoot 'plugins'
if (-not (Test-Path $pluginsDir)) { New-Item -ItemType Directory -Path $pluginsDir | Out-Null }
$failed = @()

function Invoke-Download($url, $outPath) {
  Write-Host "Downloading: $url"
  & curl.exe -L --retry 10 --retry-delay 2 --retry-all-errors --connect-timeout 20 --max-time 180 "$url" -o "$outPath"
  if (-not (Test-Path $outPath) -or (Get-Item $outPath).Length -lt 1024) {
    throw "Download failed or too small: $outPath"
  }
}

function Remove-Pattern($pattern) {
  Get-ChildItem -Path $pluginsDir -Filter $pattern -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
}

function Get-ModrinthFile($slug, $loaders = @('paper','purpur','spigot','bukkit'), $preferVersionRegex = '^1\.21') {
  $versions = $null
  if ($loaders -and $loaders.Count -gt 0) {
    foreach ($loader in $loaders) {
      $api = "https://api.modrinth.com/v2/project/$slug/version?loaders=%5B%22$loader%22%5D"
      $json = & curl.exe -L --retry 6 --retry-delay 2 --retry-all-errors --connect-timeout 15 --max-time 60 $api
      $versions = $json | ConvertFrom-Json
      if ($versions) { break }
    }
  }
  if (-not $versions) { throw "Modrinth: no versions for $slug" }
  $candidates = $versions | Where-Object { $_.game_versions -match $preferVersionRegex }
  if (-not $candidates) { $candidates = $versions }
  $pick = $candidates | Where-Object { $_.version_type -eq 'release' } | Select-Object -First 1
  if (-not $pick) { $pick = $candidates | Select-Object -First 1 }
  $file = $pick.files | Where-Object { $_.primary -eq $true } | Select-Object -First 1
  if (-not $file) { $file = $pick.files | Select-Object -First 1 }
  return @{ url = $file.url; filename = $file.filename }
}

function Get-GitHubLatestAsset($owner, $repo, $nameRegex) {
  $api = "https://api.github.com/repos/$owner/$repo/releases/latest"
  $json = & curl.exe -L --retry 6 --retry-delay 2 --retry-all-errors --connect-timeout 15 --max-time 60 $api
  $rel = $json | ConvertFrom-Json
  $asset = $rel.assets | Where-Object { $_.name -match $nameRegex } | Select-Object -First 1
  if (-not $asset) { throw "GitHub asset not found: $owner/$repo ($nameRegex)" }
  return $asset.browser_download_url
}


# Modrinth-based plugins
$modrinth = @(
  @{slug='breweryx'; pattern='BreweryX*.jar'},
  @{slug='chunky'; pattern='Chunky-*.jar'},
  @{slug='customcrafting'; pattern='customcrafting-*.jar'},
  @{slug='wolfyutils'; pattern='wolfyutils-*.jar'},
  @{slug='furniturelib'; pattern='FurnitureLib-*.jar'},
  @{slug='executableitems'; pattern='ExecutableItems-*.jar'},
  @{slug='myfurniture'; pattern='MyFurniture-*.jar'},
  @{slug='score'; pattern='SCore-*.jar'},
  @{slug='quickshop-hikari'; pattern='QuickShop-Hikari-*.jar'},
  @{slug='clickvillagers'; pattern='ClickVillagers-*.jar'},
  @{slug='levelledmobs'; pattern='LevelledMobs-*.jar'},
  @{slug='packetevents'; pattern='packetevents-*.jar'},
  @{slug='emotecraft'; pattern='emotecraft-*.jar'},
  @{slug='infinite-villager-trading'; pattern='instantrestock*.jar'},
  @{slug='thewaystones'; pattern='Waystones-*.jar'},
  @{slug='veinminer'; pattern='veinminer-paper-*.jar'},
  @{slug='luckperms'; pattern='LuckPerms-*.jar'},
  @{slug='skinsrestorer'; pattern='SkinsRestorer*.jar'},
  @{slug='oneplayersleepgg'; pattern='OnePlayerSleep-*.jar'}
)

foreach ($p in $modrinth) {
  try {
    $fileInfo = Get-ModrinthFile $p.slug
    Remove-Pattern $p.pattern
    Invoke-Download $fileInfo.url (Join-Path $pluginsDir $fileInfo.filename)
  } catch {
    $failed += "Modrinth/$($p.slug): $($_.Exception.Message)"
    Write-Warning "Failed: Modrinth/$($p.slug)"
  }
}

# EssentialsX latest from GitHub
try {
  Remove-Pattern 'EssentialsX-*.jar'
  $essUrl = Get-GitHubLatestAsset 'EssentialsX' 'Essentials' 'EssentialsX-.*\.jar'
  Invoke-Download $essUrl (Join-Path $pluginsDir (Split-Path $essUrl -Leaf))
} catch {
  $failed += "EssentialsX: $($_.Exception.Message)"
  Write-Warning "Failed: EssentialsX"
}

# Vault latest from GitHub
try {
  Remove-Pattern 'Vault*.jar'
  $vaultUrl = Get-GitHubLatestAsset 'MilkBowl' 'Vault' 'Vault.*\.jar'
  Invoke-Download $vaultUrl (Join-Path $pluginsDir (Split-Path $vaultUrl -Leaf))
} catch {
  $failed += "Vault: $($_.Exception.Message)"
  Write-Warning "Failed: Vault"
}

# NBT-API (Item NBT API) latest 2.15.5 via Spigot resource download
try {
  Remove-Pattern 'item-nbt-api-plugin-*.jar'
  Invoke-Download 'https://api.spiget.org/v2/resources/7939/download' (Join-Path $pluginsDir 'item-nbt-api-plugin-2.15.5.jar')
} catch {
  $failed += "ItemNBTAPI: $($_.Exception.Message)"
  Write-Warning "Failed: ItemNBTAPI"
}

# Geyser & Floodgate from official downloads
try {
  Remove-Pattern 'Geyser-Spigot*.jar'
  Invoke-Download 'https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot' (Join-Path $pluginsDir 'Geyser-Spigot.jar')
  Remove-Pattern 'floodgate-spigot*.jar'
  Invoke-Download 'https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot' (Join-Path $pluginsDir 'floodgate-spigot.jar')
} catch {
  $failed += "Geyser/Floodgate: $($_.Exception.Message)"
  Write-Warning "Failed: Geyser/Floodgate"
}

# ViaVersion / ViaBackwards / ViaRewind from GitHub releases
try {
  Remove-Pattern 'ViaVersion*.jar'
  $vvUrl = Get-GitHubLatestAsset 'ViaVersion' 'ViaVersion' 'ViaVersion-.*\.jar'
  Invoke-Download $vvUrl (Join-Path $pluginsDir (Split-Path $vvUrl -Leaf))

  Remove-Pattern 'ViaBackwards*.jar'
  $vbUrl = Get-GitHubLatestAsset 'ViaVersion' 'ViaBackwards' 'ViaBackwards-.*\.jar'
  Invoke-Download $vbUrl (Join-Path $pluginsDir (Split-Path $vbUrl -Leaf))

  Remove-Pattern 'ViaRewind*.jar'
  $vrUrl = Get-GitHubLatestAsset 'ViaVersion' 'ViaRewind' 'ViaRewind-.*\.jar'
  Invoke-Download $vrUrl (Join-Path $pluginsDir (Split-Path $vrUrl -Leaf))
} catch {
  $failed += "ViaVersion/ViaBackwards/ViaRewind: $($_.Exception.Message)"
  Write-Warning "Failed: ViaVersion/ViaBackwards/ViaRewind"
}

# ProtocolLib latest from GitHub
try {
  Remove-Pattern 'ProtocolLib*.jar'
  $plUrl = Get-GitHubLatestAsset 'dmulloy2' 'ProtocolLib' 'ProtocolLib.*\.jar'
  Invoke-Download $plUrl (Join-Path $pluginsDir (Split-Path $plUrl -Leaf))
} catch {
  $failed += "ProtocolLib: $($_.Exception.Message)"
  Write-Warning "Failed: ProtocolLib"
}

# GSit latest from Hangar (pinned)
try {
  Remove-Pattern 'GSit-*.jar'
  $gsitVersion = '3.1.0'
  $gsitUrl = "https://hangar.papermc.io/api/v1/projects/Gecolay/GSit/versions/$gsitVersion/PAPER/download"
  Invoke-Download $gsitUrl (Join-Path $pluginsDir ("GSit-$gsitVersion.jar"))
} catch {
  $failed += "GSit: $($_.Exception.Message)"
  Write-Warning "Failed: GSit"
}

# DiceFurniture latest from Hangar (pinned)
try {
  Remove-Pattern 'DiceFurniture-*.jar'
  $diceVersion = '3.9.3'
  $diceUrl = "https://hangar.papermc.io/api/v1/projects/Ste3et_C0st/DiceFurniture/versions/$diceVersion/PAPER/download"
  Invoke-Download $diceUrl (Join-Path $pluginsDir ("DiceFurniture-$diceVersion.jar"))
} catch {
  $failed += "DiceFurniture: $($_.Exception.Message)"
  Write-Warning "Failed: DiceFurniture"
}

# ChestSort latest from Hangar (pinned)
try {
  Remove-Pattern 'ChestSort-*.jar'
  $csVersion = '0.2.0'
  $csUrl = "https://hangar.papermc.io/api/v1/projects/UrAvgCode/chestsort/versions/$csVersion/PAPER/download"
  Invoke-Download $csUrl (Join-Path $pluginsDir ("ChestSort-$csVersion.jar"))
} catch {
  $failed += "ChestSort: $($_.Exception.Message)"
  Write-Warning "Failed: ChestSort"
}

if ($failed.Count -gt 0) {
  Write-Warning "Some downloads failed:"
  $failed | ForEach-Object { Write-Warning " - $_" }
} else {
  Write-Host "All downloads completed."
}

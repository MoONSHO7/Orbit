param([switch]$Force)

$LibsDir = Join-Path $PSScriptRoot "..\Orbit\Core\Libs"
$CacheDir = Join-Path $LibsDir ".cache"

# We use wowace-clone mirrors for SVN libraries to allow easy local fetching.
$Externals = @(
    @{ Name = "LibDeflate"; Url = "https://github.com/SafeteeWoW/LibDeflate.git" },
    @{ Name = "LibSerialize"; Url = "https://github.com/rossnichols/LibSerialize.git"; Tag = "v1.0.0" },
    @{ Name = "LibCustomGlow-1.0"; Url = "https://github.com/Stanzilla/LibCustomGlow.git" },
    @{ Name = "LibStub"; Url = "https://github.com/wowace-clone/LibStub.git" },
    @{ Name = "CallbackHandler-1.0"; Url = "https://github.com/wowace-clone/CallbackHandler-1.0.git"; SubDir = "CallbackHandler-1.0" },
    @{ Name = "LibSharedMedia-3.0"; Url = "https://github.com/wowace-clone/LibSharedMedia-3.0.git"; SubDir = "LibSharedMedia-3.0" },
    @{ Name = "LibDBIcon-1.0"; Url = "https://github.com/wowace-clone/LibDBIcon-1.0.git" }
)

# Ensure cache dir exists
if (-not (Test-Path $CacheDir)) {
    New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null
}

foreach ($lib in $Externals) {
    if ($lib.SubDir) {
        $dest = Join-Path $CacheDir $lib.Name
        $finalDest = Join-Path $LibsDir $lib.Name
    } else {
        $dest = Join-Path $LibsDir $lib.Name
        $finalDest = $dest
    }

    $exists = Test-Path $dest

    if ($Force -and $exists) {
        Write-Host "  [clean] $($lib.Name)" -ForegroundColor Yellow
        Remove-Item -Recurse -Force $dest
        if ($lib.SubDir -and (Test-Path $finalDest)) {
            Remove-Item -Recurse -Force $finalDest
        }
        $exists = $false
    }

    $gitDir = Join-Path $dest ".git"
    if ($exists -and (Test-Path $gitDir)) {
        Write-Host "  [pull]  $($lib.Name)" -ForegroundColor Green
        git -C $dest pull --quiet 2>&1 | Out-Null
    }
    elseif (-not $exists) {
        Write-Host "  [clone] $($lib.Name)" -ForegroundColor Cyan
        if ($lib.Tag) {
            git clone --depth 1 --branch $lib.Tag $lib.Url $dest 2>&1 | Out-Null
        }
        else {
            git clone --depth 1 $lib.Url $dest 2>&1 | Out-Null
        }
    }
    else {
        Write-Host "  [skip]  $($lib.Name)" -ForegroundColor DarkGray
    }

    if ($lib.SubDir) {
        # Emulate .pkgmeta by extracting just the sub-directory
        if (-not (Test-Path $finalDest)) {
            New-Item -ItemType Directory -Force -Path $finalDest | Out-Null
        }
        $sourceDir = Join-Path $dest $lib.SubDir
        if (Test-Path $sourceDir) {
            Copy-Item -Recurse -Force "$sourceDir\*" $finalDest
        }
    }
}

Write-Host ""
Write-Host "Done." -ForegroundColor Green

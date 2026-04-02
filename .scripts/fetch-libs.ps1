param([switch]$Force)

$LibsDir = Join-Path $PSScriptRoot "..\Orbit\Core\Libs"

# Only libraries with GitHub repos. SVN-only libs (LibStub, CallbackHandler,
# LibSharedMedia, LibDBIcon) are committed to git and rarely need updating.
$Externals = @(
    @{ Name = "LibDeflate"; Url = "https://github.com/SafeteeWoW/LibDeflate.git" },
    @{ Name = "LibSerialize"; Url = "https://github.com/rossnichols/LibSerialize.git"; Tag = "v1.0.0" },
    @{ Name = "LibCustomGlow-1.0"; Url = "https://github.com/Stanzilla/LibCustomGlow.git" }
)

foreach ($lib in $Externals) {
    $dest = Join-Path $LibsDir $lib.Name
    $exists = Test-Path $dest

    if ($Force -and $exists) {
        Write-Host "  [clean] $($lib.Name)" -ForegroundColor Yellow
        Remove-Item -Recurse -Force $dest
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
}

Write-Host ""
Write-Host "Done." -ForegroundColor Green

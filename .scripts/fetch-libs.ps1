param([switch]$Force)

$LibsDir = Join-Path $PSScriptRoot "..\Orbit\Core\Libs"
$CacheDir = Join-Path $LibsDir ".cache"

# We download these as ZIP archives to skip git/svn tracking. This prevents "branch switching" 
# or parent repo `git clean` operations from destroying partial library checkouts.
$Externals = @(
    @{ Name = "LibDeflate"; Repo = "SafeteeWoW/LibDeflate"; Branch = "master" },
    @{ Name = "LibSerialize"; Repo = "rossnichols/LibSerialize"; Branch = "refs/tags/v1.0.0" },
    @{ Name = "LibCustomGlow-1.0"; Repo = "Stanzilla/LibCustomGlow"; Branch = "master" },
    @{ Name = "LibStub"; Repo = "wowace-clone/LibStub"; Branch = "master" },
    @{ Name = "CallbackHandler-1.0"; Repo = "wowace-clone/CallbackHandler-1.0"; Branch = "master"; SubDir = "CallbackHandler-1.0" },
    @{ Name = "LibSharedMedia-3.0"; Repo = "wowace-clone/LibSharedMedia-3.0"; Branch = "master"; SubDir = "LibSharedMedia-3.0" },
    @{ Name = "LibDBIcon-1.0"; Repo = "wowace-clone/LibDBIcon-1.0"; Branch = "master" }
)

if (-not (Test-Path $CacheDir)) {
    New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null
}

foreach ($lib in $Externals) {
    if ($lib.SubDir) {
        $finalDest = Join-Path $LibsDir $lib.Name
    } else {
        $finalDest = Join-Path $LibsDir $lib.Name
    }

    $exists = Test-Path $finalDest

    if ($Force -or -not $exists) {
        Write-Host "  [download] $($lib.Name)" -ForegroundColor Cyan
        
        # Clean destination if it has been corrupted or we are forcing
        if (Test-Path $finalDest) {
            Remove-Item -Recurse -Force $finalDest
        }

        $zipPath = Join-Path $CacheDir "$($lib.Name).zip"
        $extractPath = Join-Path $CacheDir "$($lib.Name)-extract"
        
        if (Test-Path $extractPath) {
            Remove-Item -Recurse -Force $extractPath
        }

        # Build GitHub archive URL
        $url = "https://github.com/$($lib.Repo)/archive/"
        if ($lib.Branch -match "^refs/tags/") {
            $url += $lib.Branch + ".zip"
        } else {
            $url += "refs/heads/$($lib.Branch).zip"
        }

        try {
            Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
            Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
            
            # The archive extracts to a folder like "LibDeflate-master", so select the first directory
            $extractedDir = Get-ChildItem -Directory -Path $extractPath | Select-Object -First 1

            if ($lib.SubDir) {
                # Copy from SubDir (e.g. CallbackHandler-1.0/CallbackHandler-1.0)
                $sourceDir = Join-Path $extractedDir.FullName $lib.SubDir
                New-Item -ItemType Directory -Force -Path $finalDest | Out-Null
                Copy-Item -Recurse -Force "$sourceDir\*" $finalDest
            } else {
                # Move the entire extracted directory to destination
                Move-Item -Path $extractedDir.FullName -Destination $finalDest -Force
            }

            # Cleanup
            Remove-Item -Recurse -Force $extractPath
            Remove-Item -Force $zipPath

        } catch {
            Write-Host "  [error] failed to download $($lib.Name): $_" -ForegroundColor Red
        }
    } else {
        Write-Host "  [skip]     $($lib.Name)" -ForegroundColor DarkGray
    }
}

Write-Host "`nDone." -ForegroundColor Green

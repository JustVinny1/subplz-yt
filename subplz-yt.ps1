<#
.SYNOPSIS
    Download a YouTube video, generate subtitles with SubPlz, and embed them.
.USAGE
    subplz-yt "https://www.youtube.com/watch?v=VIDEO_ID"
    subplz-yt "https://www.youtube.com/watch?v=VIDEO_ID" -Model large
    subplz-yt "https://www.youtube.com/watch?v=VIDEO_ID" -SubsOnly
    subplz-yt -Setup
.CONFIGURATION
    Set the SUBPLZ_PATH environment variable to your SubPlz installation directory.
    Defaults to C:\Tools\SubPlz if not set.
#>

param(
    [Parameter(Mandatory=$false, Position=0)]
    [string]$Url,

    [Parameter()]
    [string]$Model = "turbo",

    [switch]$SubsOnly,

    [switch]$Setup
)

$ErrorActionPreference = "Stop"

# --- Setup / Auto-Configuration Mode ---
if ($Setup) {
    Write-Host "--- subplz-yt Setup ---" -ForegroundColor Cyan
    
    $CurrentPath = $PSScriptRoot
    $DefaultSubPlz = "C:\Tools\SubPlz"
    
    Write-Host "1. Adding script directory to User Path..." -ForegroundColor Gray
    $UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($UserPath -notlike "*$CurrentPath*") {
        [Environment]::SetEnvironmentVariable("Path", $UserPath + ";$CurrentPath", "User")
        Write-Host "   Done. (Note: You may need to restart your terminal)" -ForegroundColor Green
    } else {
        Write-Host "   Already in Path." -ForegroundColor Green
    }

    Write-Host "2. Configuring SUBPLZ_PATH..." -ForegroundColor Gray
    if (-not $env:SUBPLZ_PATH) {
        if (Test-Path $DefaultSubPlz) {
            [Environment]::SetEnvironmentVariable("SUBPLZ_PATH", $DefaultSubPlz, "User")
            Write-Host "   Set to $DefaultSubPlz" -ForegroundColor Green
        } else {
            Write-Host "   Warning: $DefaultSubPlz not found. Please set SUBPLZ_PATH manually." -ForegroundColor Yellow
        }
    } else {
        Write-Host "   SUBPLZ_PATH already set to $($env:SUBPLZ_PATH)" -ForegroundColor Green
    }

    Write-Host "`nSetup checks complete. Restart your terminal if this is your first time." -ForegroundColor Cyan
    exit 0
}

if (-not $Url) {
    Write-Error "URL is required. Usage: subplz-yt <URL>"
    exit 1
}

$CallingDir = (Get-Location).Path
$SubPlzRoot = if ($env:SUBPLZ_PATH) { $env:SUBPLZ_PATH } else { "C:\Tools\SubPlz" }
$SubPlzExe = Join-Path $SubPlzRoot ".venv\Scripts\subplz.exe"
$TempDir = Join-Path $env:TEMP "subplz-work-$(Get-Random)"

# --- Preflight checks ---
Write-Host "Checking dependencies..." -ForegroundColor Gray

# 1. yt-dlp check
if (-not (Get-Command "yt-dlp" -ErrorAction SilentlyContinue)) {
    Write-Error "yt-dlp not found on PATH. Install it with: uv tool install yt-dlp"
    exit 1
}
try {
    & yt-dlp --version | Out-Null
} catch {
    Write-Error "yt-dlp is present but failing to run. Try: uv tool install yt-dlp --reinstall"
    exit 1
}

# 2. ffmpeg check
if (-not (Get-Command "ffmpeg" -ErrorAction SilentlyContinue)) {
    Write-Error "ffmpeg not found on PATH. Install it via winget or your preferred manager."
    exit 1
}

# 3. SubPlz check
if (-not (Test-Path $SubPlzExe)) {
    Write-Error "SubPlz not found at $SubPlzExe. Set SUBPLZ_PATH or install it to C:\Tools\SubPlz."
    exit 1
}
try {
    # Check if the environment is healthy by trying to run it
    & $SubPlzExe --help | Out-Null
} catch {
    Write-Error "SubPlz environment is broken. Try running this in your SubPlz folder:`n.venv\Scripts\pip.exe install `"setuptools<78`" torch torchaudio"
    exit 1
}

if ($SubsOnly) {
    $TotalSteps = 2
} else {
    $TotalSteps = 3
}

try {
    # --- Step 1: Download ---
    Write-Host "`n[1/$TotalSteps] Downloading $(if ($SubsOnly) {'audio'} else {'video'})..." -ForegroundColor Cyan
    if (-not (Test-Path $TempDir)) { New-Item -ItemType Directory -Path $TempDir -Force | Out-Null }

    if ($SubsOnly) {
        & yt-dlp -o "$TempDir\%(title)s.%(ext)s" -x --audio-format mp3 --no-playlist $Url
    } else {
        & yt-dlp -o "$TempDir\%(title)s.%(ext)s" --merge-output-format mkv --no-playlist $Url
    }
    if ($LASTEXITCODE -ne 0) { throw "yt-dlp failed." }

    $MediaFile = Get-ChildItem -Path $TempDir -File | Where-Object { $_.Extension -match '\.(mkv|mp4|webm|avi|mp3|m4a|opus|wav)$' } | Select-Object -First 1
    if (-not $MediaFile) { throw "No media file found after download." }

    $BaseName = $MediaFile.BaseName
    Write-Host "  Downloaded: $($MediaFile.Name)" -ForegroundColor Green

    # --- Step 2: Generate subtitles ---
    Write-Host "`n[2/$TotalSteps] Generating subtitles (model: $Model)..." -ForegroundColor Cyan
    & $SubPlzExe gen -d $TempDir --model $Model --vad --stable-ts

    # SubPlz may return non-zero even on success, so check for actual output
    $SrtFile = Get-ChildItem -Path $TempDir -Filter "*.srt" | Select-Object -First 1
    if (-not $SrtFile) { throw "No subtitle file generated. SubPlz may have failed." }
    Write-Host "  Generated: $($SrtFile.Name)" -ForegroundColor Green

    # Ensure output filenames are unique in the calling directory
    $FinalBase = $BaseName
    $Counter = 1
    while ((Test-Path (Join-Path $CallingDir "$FinalBase.mkv")) -or (Test-Path (Join-Path $CallingDir "$FinalBase.srt"))) {
        $FinalBase = "$BaseName ($Counter)"
        $Counter++
    }

    if ($SubsOnly) {
        $OutputSrt = Join-Path $CallingDir "$FinalBase.srt"
        Copy-Item -Path $SrtFile.FullName -Destination $OutputSrt -Force
        Write-Host "  Subs: $OutputSrt" -ForegroundColor Green
    } else {
        # --- Step 3: Embed subtitles ---
        Write-Host "`n[3/$TotalSteps] Embedding subtitles..." -ForegroundColor Cyan
        $OutputFile = Join-Path $CallingDir "$FinalBase.mkv"
        $OutputSrt = Join-Path $CallingDir "$FinalBase.srt"

        $MuxTemp = Join-Path $TempDir "_muxed_$($MediaFile.Name)"
        
        & ffmpeg -y -i $MediaFile.FullName -i $SrtFile.FullName -c copy -c:s srt $MuxTemp 2>$null
        if ($LASTEXITCODE -ne 0) { throw "ffmpeg muxing failed." }

        Move-Item -Path $MuxTemp -Destination $OutputFile -Force
        Copy-Item -Path $SrtFile.FullName -Destination $OutputSrt -Force
        Write-Host "  Video: $OutputFile" -ForegroundColor Green
        Write-Host "  Subs:  $OutputSrt" -ForegroundColor Green
    }

    Write-Host "`nDone!" -ForegroundColor Green

} catch {
    Write-Host "`nError: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    if (Test-Path $TempDir) {
        Remove-Item -Recurse -Force $TempDir -ErrorAction SilentlyContinue
    }
}

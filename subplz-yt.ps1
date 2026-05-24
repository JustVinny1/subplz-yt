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

    [switch]$Setup,

    [Parameter()]
    [string]$SubPlzPath
)

$ErrorActionPreference = "Stop"

# --- Discovery Logic for SubPlz ---
function Get-SubPlzExe {
    # 1. Check if a path was passed directly via -SubPlzPath
    if ($SubPlzPath) {
        $exe = Join-Path $SubPlzPath ".venv\Scripts\subplz.exe"
        if (Test-Path $exe) { return $exe }
    }

    # 2. Check Environment Variable
    if ($env:SUBPLZ_PATH) {
        $exe = Join-Path $env:SUBPLZ_PATH ".venv\Scripts\subplz.exe"
        if (Test-Path $exe) { return $exe }
    }

    # 3. Check for Child/Sibling Directory
    $ChildDir = Join-Path $PSScriptRoot "SubPlz"
    $SiblingDir = Join-Path $PSScriptRoot "..\SubPlz"
    
    foreach ($dir in @($ChildDir, $SiblingDir)) {
        $exe = Join-Path $dir ".venv\Scripts\subplz.exe"
        if (Test-Path $exe) { return $exe }
    }

    # 4. Check Default Location
    $DefaultDir = "C:\Tools\SubPlz"
    $exe = Join-Path $DefaultDir ".venv\Scripts\subplz.exe"
    if (Test-Path $exe) { return $exe }

    # 5. Check if 'subplz' is already on the PATH (e.g. via global install or manual venv activation)
    $cmd = Get-Command "subplz" -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    return $null
}

# --- Setup / Auto-Configuration Mode ---
if ($Setup) {
    Write-Host "`n--- subplz-yt Full Setup ---" -ForegroundColor Cyan
    
    # 1. Install System Dependencies
    Write-Host "`n[1/4] Checking system tools (winget)..." -ForegroundColor Gray
    $Tools = @("Git.Git", "astral-sh.uv", "ffmpeg")
    foreach ($tool in $Tools) {
        if (-not (Get-Command $tool.Split('.')[-1] -ErrorAction SilentlyContinue)) {
            Write-Host "   Installing $tool..." -ForegroundColor Gray
            & winget install $tool --accept-source-agreements --accept-package-agreements | Out-Null
        } else {
            Write-Host "   $($tool.Split('.')[-1]) is already installed." -ForegroundColor Green
        }
    }

    # 2. Install yt-dlp
    Write-Host "`n[2/4] Checking yt-dlp..." -ForegroundColor Gray
    if (-not (Get-Command "yt-dlp" -ErrorAction SilentlyContinue)) {
        Write-Host "   Installing yt-dlp via uv..." -ForegroundColor Gray
        & uv tool install yt-dlp | Out-Null
    } else {
        Write-Host "   yt-dlp is already installed." -ForegroundColor Green
    }

    # 3. Install/Configure SubPlz
    Write-Host "`n[3/4] Checking SubPlz..." -ForegroundColor Gray
    $SubPlzRoot = Join-Path $PSScriptRoot "SubPlz"
    if (-not (Test-Path $SubPlzRoot)) {
        Write-Host "   Cloning SubPlz into $SubPlzRoot..." -ForegroundColor Gray
        & git clone https://github.com/kanjieater/SubPlz.git $SubPlzRoot | Out-Null
    }

    $SubPlzExe = Join-Path $SubPlzRoot ".venv\Scripts\subplz.exe"
    if (-not (Test-Path $SubPlzExe)) {
        Write-Host "   Setting up SubPlz virtual environment (this may take a minute)..." -ForegroundColor Gray
        Push-Location $SubPlzRoot
        try {
            & uv venv --python 3.11 .venv | Out-Null
            & .\.venv\Scripts\uv pip install -e . | Out-Null
            & .\.venv\Scripts\pip.exe install "setuptools<78" | Out-Null
            
            # Check for NVIDIA GPU
            if (Get-Command "nvidia-smi" -ErrorAction SilentlyContinue) {
                Write-Host "   NVIDIA GPU detected. Installing CUDA-enabled PyTorch..." -ForegroundColor Gray
                & .\.venv\Scripts\pip.exe install torch torchaudio --index-url https://download.pytorch.org/whl/cu128 --force-reinstall | Out-Null
            }
        } finally {
            Pop-Location
        }
    }
    
    # Configure Environment Variable
    [Environment]::SetEnvironmentVariable("SUBPLZ_PATH", $SubPlzRoot, "User")
    $env:SUBPLZ_PATH = $SubPlzRoot
    Write-Host "   SubPlz configured at $SubPlzRoot" -ForegroundColor Green

    # 4. Path Configuration
    Write-Host "`n[4/4] Configuring User PATH..." -ForegroundColor Gray
    $UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($UserPath -notlike "*$PSScriptRoot*") {
        [Environment]::SetEnvironmentVariable("Path", $UserPath + ";$PSScriptRoot", "User")
        Write-Host "   Added $PSScriptRoot to User Path." -ForegroundColor Green
    } else {
        Write-Host "   Script directory is already in Path." -ForegroundColor Green
    }

    Write-Host "`nSetup Complete! Please RESTART your terminal to apply all changes." -ForegroundColor Cyan
    exit 0
}

if (-not $Url) {
    Write-Error "URL is required. Usage: subplz-yt <URL>`nOr run: subplz-yt -Setup"
    exit 1
}

$SubPlzExe = Get-SubPlzExe
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

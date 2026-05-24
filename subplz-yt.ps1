<#
.SYNOPSIS
    Download a YouTube video, generate subtitles with SubPlz, and embed them.
.USAGE
    subplz-yt "https://www.youtube.com/watch?v=VIDEO_ID"
    subplz-yt -Setup
.CONFIGURATION
    Run with -Setup to configure dependencies.
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

# --- Helper Function for Interactive Confirmation ---
function Confirm-Action {
    param([string]$Message)
    $host.ui.Write("`n$Message [Y/N]: ")
    $choice = $host.ui.ReadLine()
    return ($choice -match '^[yY]')
}

# --- Discovery Logic for SubPlz ---
function Get-SubPlzExe {
    if ($SubPlzPath) {
        $exe = Join-Path $SubPlzPath ".venv\Scripts\subplz.exe"
        if (Test-Path $exe) { return $exe }
    }
    if ($env:SUBPLZ_PATH) {
        $exe = Join-Path $env:SUBPLZ_PATH ".venv\Scripts\subplz.exe"
        if (Test-Path $exe) { return $exe }
    }
    $ChildDir = Join-Path $PSScriptRoot "SubPlz"
    $SiblingDir = Join-Path $PSScriptRoot "..\SubPlz"
    foreach ($dir in @($ChildDir, $SiblingDir)) {
        $exe = Join-Path $dir ".venv\Scripts\subplz.exe"
        if (Test-Path $exe) { return $exe }
    }
    $cmd = Get-Command "subplz" -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

# --- Setup / Auto-Configuration Mode ---
if ($Setup) {
    Write-Host "`n--- subplz-yt Setup ---" -ForegroundColor Cyan
    Write-Host "This guide will check for dependencies and ask before making system-wide changes." -ForegroundColor Gray
    
    # 1. System Tools (Global)
    Write-Host "`n[1/4] Checking system tools..." -ForegroundColor Cyan
    $Tools = @{ "Git.Git" = "git"; "astral-sh.uv" = "uv"; "ffmpeg" = "ffmpeg" }
    foreach ($pkg in $Tools.Keys) {
        $cmdName = $Tools[$pkg]
        if (-not (Get-Command $cmdName -ErrorAction SilentlyContinue)) {
            Write-Host "  - $cmdName is NOT installed." -ForegroundColor Yellow
            if (Confirm-Action "Install $cmdName via winget (global)?") {
                Write-Host "    Installing $pkg..." -ForegroundColor Gray
                & winget install $pkg --accept-source-agreements --accept-package-agreements | Out-Null
                Write-Host "    Successfully installed $cmdName." -ForegroundColor Green
            }
        } else {
            Write-Host "  - $cmdName is already installed." -ForegroundColor Green
        }
    }

    # 2. yt-dlp (Global via uv)
    Write-Host "`n[2/4] Checking yt-dlp..." -ForegroundColor Cyan
    if (-not (Get-Command "yt-dlp" -ErrorAction SilentlyContinue)) {
        Write-Host "  - yt-dlp is NOT installed." -ForegroundColor Yellow
        if (Confirm-Action "Install yt-dlp via uv (global)?") {
            & uv tool install yt-dlp | Out-Null
            Write-Host "    Successfully installed yt-dlp." -ForegroundColor Green
        }
    } else {
        Write-Host "  - yt-dlp is already installed." -ForegroundColor Green
    }

    # 3. SubPlz (Local)
    Write-Host "`n[3/4] Checking SubPlz (AI engine)..." -ForegroundColor Cyan
    $DetectedExe = Get-SubPlzExe
    $SubPlzRoot = ""

    if ($DetectedExe) {
        $SubPlzRoot = Split-Path (Split-Path (Split-Path $DetectedExe -Parent) -Parent) -Parent
        Write-Host "  - SubPlz found at: $SubPlzRoot" -ForegroundColor Green
    } else {
        Write-Host "  - SubPlz not found in standard locations." -ForegroundColor Yellow
        $DefaultSubPlz = Join-Path $PSScriptRoot "SubPlz"
        if (Confirm-Action "Clone SubPlz into a local subdirectory ($DefaultSubPlz)?") {
            Write-Host "    Cloning SubPlz..." -ForegroundColor Gray
            & git clone https://github.com/kanjieater/SubPlz.git $DefaultSubPlz | Out-Null
            $SubPlzRoot = $DefaultSubPlz
        }
    }

    if ($SubPlzRoot -and (Test-Path $SubPlzRoot)) {
        $SubPlzExe = Join-Path $SubPlzRoot ".venv\Scripts\subplz.exe"
        if (-not (Test-Path $SubPlzExe)) {
            Write-Host "  - SubPlz virtual environment needs setup (contains AI libraries)." -ForegroundColor Yellow
            if (Confirm-Action "Set up the local environment (~2GB download)?") {
                Write-Host "    Building environment..." -ForegroundColor Gray
                Push-Location $SubPlzRoot
                try {
                    & uv venv --python 3.11 .venv | Out-Null
                    & .\.venv\Scripts\uv pip install -e . | Out-Null
                    & .\.venv\Scripts\pip.exe install "setuptools<78" | Out-Null
                    if (Get-Command "nvidia-smi" -ErrorAction SilentlyContinue) {
                        Write-Host "    NVIDIA GPU detected. Installing CUDA support..." -ForegroundColor Gray
                        & .\.venv\Scripts\pip.exe install torch torchaudio --index-url https://download.pytorch.org/whl/cu128 --force-reinstall | Out-Null
                    }
                    Write-Host "    Environment setup complete." -ForegroundColor Green
                } finally {
                    Pop-Location
                }
            }
        } else {
            if ($DetectedExe) {
                Write-Host "  - SubPlz environment is ready." -ForegroundColor Green
            }
        }
        
        # Configure Environment Variable
        [Environment]::SetEnvironmentVariable("SUBPLZ_PATH", $SubPlzRoot, "User")
        $env:SUBPLZ_PATH = $SubPlzRoot
    }

    # 4. Path Configuration (Global)
    Write-Host "`n[4/4] Finalizing configuration..." -ForegroundColor Cyan
    $UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($UserPath -notlike "*$PSScriptRoot*") {
        if (Confirm-Action "Add this script to your User PATH (allows running 'subplz-yt' from any folder)?") {
            [Environment]::SetEnvironmentVariable("Path", $UserPath + ";$PSScriptRoot", "User")
            Write-Host "    Added to User Path." -ForegroundColor Green
        }
    } else {
        Write-Host "  - Script folder is already in Path." -ForegroundColor Green
    }

    Write-Host "`nSetup process finished. Please RESTART your terminal to apply changes." -ForegroundColor Cyan
    exit 0
}

if (-not $Url) {
    Write-Error "URL is required. Usage: subplz-yt <URL>`nOr run: subplz-yt -Setup"
    exit 1
}

$CallingDir = (Get-Location).Path
$SubPlzExe = Get-SubPlzExe
$TempDir = Join-Path $env:TEMP "subplz-work-$(Get-Random)"

# --- Preflight checks ---
Write-Host "Checking dependencies..." -ForegroundColor Gray

if (-not (Get-Command "yt-dlp" -ErrorAction SilentlyContinue)) {
    Write-Error "yt-dlp not found. Run 'subplz-yt -Setup' to install it."
    exit 1
}
try { & yt-dlp --version | Out-Null } catch {
    Write-Error "yt-dlp is broken. Try: uv tool install yt-dlp --reinstall"
    exit 1
}

if (-not (Get-Command "ffmpeg" -ErrorAction SilentlyContinue)) {
    Write-Error "ffmpeg not found. Run 'subplz-yt -Setup' to install it."
    exit 1
}

if (-not $SubPlzExe) {
    Write-Error "SubPlz not found. Run 'subplz-yt -Setup' to configure it."
    exit 1
}
try { & $SubPlzExe --help | Out-Null } catch {
    Write-Error "SubPlz environment is broken. Run 'subplz-yt -Setup' to attempt a repair."
    exit 1
}

if ($SubsOnly) { $TotalSteps = 2 } else { $TotalSteps = 3 }

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

    $SrtFile = Get-ChildItem -Path $TempDir -Filter "*.srt" | Select-Object -First 1
    if (-not $SrtFile) { throw "No subtitle file generated. SubPlz may have failed." }
    Write-Host "  Generated: $($SrtFile.Name)" -ForegroundColor Green

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
    if (Test-Path $TempDir) { Remove-Item -Recurse -Force $TempDir -ErrorAction SilentlyContinue }
}

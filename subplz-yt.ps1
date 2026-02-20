<#
.SYNOPSIS
    Download a YouTube video, generate subtitles with SubPlz, and embed them.
.USAGE
    subplz-yt "https://www.youtube.com/watch?v=VIDEO_ID"
    subplz-yt "https://www.youtube.com/watch?v=VIDEO_ID" -Model large
    subplz-yt "https://www.youtube.com/watch?v=VIDEO_ID" -SubsOnly
.CONFIGURATION
    Set the SUBPLZ_PATH environment variable to your SubPlz installation directory.
    Defaults to C:\Tools\SubPlz if not set.
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Url,

    [Parameter()]
    [string]$Model = "turbo",

    [switch]$SubsOnly
)

$ErrorActionPreference = "Stop"
$CallingDir = (Get-Location).Path
$SubPlzRoot = if ($env:SUBPLZ_PATH) { $env:SUBPLZ_PATH } else { "C:\Tools\SubPlz" }
$SubPlzExe = Join-Path $SubPlzRoot ".venv\Scripts\subplz.exe"
$TempDir = Join-Path $env:TEMP "subplz-work-$(Get-Random)"

# --- Preflight checks ---
foreach ($cmd in @("yt-dlp", "ffmpeg")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Error "$cmd is not installed or not on PATH."
        exit 1
    }
}
if (-not (Test-Path $SubPlzExe)) {
    Write-Error "SubPlz not found at $SubPlzExe. Set the SUBPLZ_PATH environment variable to your SubPlz installation directory."
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
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

    if ($SubsOnly) {
        yt-dlp -o "$TempDir\%(title)s.%(ext)s" -x --audio-format mp3 $Url
    } else {
        yt-dlp -o "$TempDir\%(title)s.%(ext)s" --merge-output-format mkv $Url
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

    if ($SubsOnly) {
        # --- Subs only: just copy the .srt ---
        $OutputSrt = Join-Path $CallingDir "$BaseName.srt"
        Copy-Item -Path $SrtFile.FullName -Destination $OutputSrt -Force
        Write-Host "  Subs: $OutputSrt" -ForegroundColor Green
    } else {
        # --- Step 3: Embed subtitles and copy .srt ---
        Write-Host "`n[3/$TotalSteps] Embedding subtitles..." -ForegroundColor Cyan
        $OutputFile = Join-Path $CallingDir "$BaseName.mkv"
        $OutputSrt = Join-Path $CallingDir "$BaseName.srt"

        # Avoid collision with temp file if CallingDir == TempDir
        $MuxTemp = Join-Path $TempDir "_muxed_$BaseName.mkv"

        ffmpeg -y -i $MediaFile.FullName -i $SrtFile.FullName -c copy -c:s srt $MuxTemp
        if ($LASTEXITCODE -ne 0) { throw "ffmpeg muxing failed." }

        Move-Item -Path $MuxTemp -Destination $OutputFile -Force
        Copy-Item -Path $SrtFile.FullName -Destination $OutputSrt -Force
        Write-Host "  Video: $OutputFile" -ForegroundColor Green
        Write-Host "  Subs:  $OutputSrt" -ForegroundColor Green
    }

    Write-Host "`nDone!" -ForegroundColor Green

} finally {
    # Cleanup temp directory
    if (Test-Path $TempDir) {
        Remove-Item -Recurse -Force $TempDir -ErrorAction SilentlyContinue
    }
}

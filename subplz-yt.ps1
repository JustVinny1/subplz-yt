<#
.SYNOPSIS
    Download a YouTube video, generate subtitles with SubPlz, and embed them.
.USAGE
    subplz-yt "https://www.youtube.com/watch?v=VIDEO_ID"
    subplz-yt "https://www.youtube.com/watch?v=VIDEO_ID" -Model large
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Url,

    [Parameter()]
    [string]$Model = "turbo"
)

$ErrorActionPreference = "Stop"
$CallingDir = (Get-Location).Path
$SubPlzExe = "C:\Tools\SubPlz\.venv\Scripts\subplz.exe"
$TempDir = Join-Path $env:TEMP "subplz-work-$(Get-Random)"

# --- Preflight checks ---
foreach ($cmd in @("yt-dlp", "ffmpeg")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Error "$cmd is not installed or not on PATH."
        exit 1
    }
}
if (-not (Test-Path $SubPlzExe)) {
    Write-Error "SubPlz not found at $SubPlzExe. Check the path."
    exit 1
}

try {
    # --- Step 1: Download ---
    Write-Host "`n[1/3] Downloading video..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

    # Download as mkv to ensure subtitle-compatible container
    yt-dlp -o "$TempDir\%(title)s.%(ext)s" --merge-output-format mkv $Url
    if ($LASTEXITCODE -ne 0) { throw "yt-dlp failed." }

    $VideoFile = Get-ChildItem -Path $TempDir -File | Where-Object { $_.Extension -match '\.(mkv|mp4|webm|avi)$' } | Select-Object -First 1
    if (-not $VideoFile) { throw "No video file found after download." }

    $BaseName = $VideoFile.BaseName
    Write-Host "  Downloaded: $($VideoFile.Name)" -ForegroundColor Green

    # --- Step 2: Generate subtitles ---
    Write-Host "`n[2/3] Generating subtitles (model: $Model)..." -ForegroundColor Cyan
    & $SubPlzExe gen -d $TempDir --model $Model --vad --stable-ts

    # SubPlz may return non-zero even on success, so check for actual output
    $SrtFile = Get-ChildItem -Path $TempDir -Filter "*.srt" | Select-Object -First 1
    if (-not $SrtFile) { throw "No subtitle file generated. SubPlz may have failed." }
    Write-Host "  Generated: $($SrtFile.Name)" -ForegroundColor Green

    # --- Step 3: Embed subtitles and copy .srt ---
    Write-Host "`n[3/3] Embedding subtitles..." -ForegroundColor Cyan
    $OutputFile = Join-Path $CallingDir "$BaseName.mkv"
    $OutputSrt = Join-Path $CallingDir "$BaseName.srt"

    # Avoid collision with temp file if CallingDir == TempDir
    $MuxTemp = Join-Path $TempDir "_muxed_$BaseName.mkv"

    ffmpeg -y -i $VideoFile.FullName -i $SrtFile.FullName -c copy -c:s srt $MuxTemp
    if ($LASTEXITCODE -ne 0) { throw "ffmpeg muxing failed." }

    Move-Item -Path $MuxTemp -Destination $OutputFile -Force
    Copy-Item -Path $SrtFile.FullName -Destination $OutputSrt -Force
    Write-Host "  Video: $OutputFile" -ForegroundColor Green
    Write-Host "  Subs:  $OutputSrt" -ForegroundColor Green

    Write-Host "`nDone!" -ForegroundColor Green

} finally {
    # Cleanup temp directory
    if (Test-Path $TempDir) {
        Remove-Item -Recurse -Force $TempDir -ErrorAction SilentlyContinue
    }
}

# subplz-yt

A wrapper script that downloads a YouTube video, generates accurate subtitles using [SubPlz](https://github.com/kanjieater/SubPlz), and outputs a video with embedded subs — all in one command.

## What it does

1. Downloads the video with yt-dlp (as MKV for subtitle compatibility)
2. Generates subtitles using SubPlz (Whisper-based, with VAD and stable-ts for accurate timestamps)
3. Soft-embeds the subs into the MKV container with ffmpeg (no re-encoding)
4. Outputs both the video and a standalone `.srt` file to your current directory

With the `-SubsOnly` flag, it downloads just the audio (much faster) and outputs only the `.srt` file.

## Prerequisites

- Windows 10/11
- NVIDIA GPU recommended (CUDA-accelerated transcription is ~10x faster than CPU)

## Installation

This script requires `yt-dlp`, `ffmpeg`, and `SubPlz`. Follow these steps for a robust setup:

### 1. Install Global Dependencies
Open PowerShell as an Administrator (or a standard user if you have `winget` configured) and run:

```powershell
# Install core tools
winget install Git.Git astral-sh.uv ffmpeg

# Install yt-dlp globally via uv
uv tool install yt-dlp
uv tool update-shell
```

*Restart your terminal after this step.*

### 2. Install SubPlz (The Engine)
Clone and set up the SubPlz project. It is recommended to put it in a folder like `C:\Tools\SubPlz`.

```powershell
git clone https://github.com/kanjieater/SubPlz.git C:\Tools\SubPlz
cd C:\Tools\SubPlz

# Create environment and install
uv venv --python 3.11 .venv
.venv\Scripts\activate
uv pip install -e .
.venv\Scripts\pip.exe install "setuptools<78"
```

**NVIDIA GPU Users (Recommended):**
Accelerate transcription by 10x by installing CUDA-enabled PyTorch:
```powershell
.venv\Scripts\pip.exe install torch torchaudio --index-url https://download.pytorch.org/whl/cu128 --force-reinstall
deactivate
```

### 3. Install and Configure this Script
Clone this repository and run the automated setup.

```powershell
git clone https://github.com/JustVinny1/subplz-yt.git C:\Tools\subplz-yt
cd C:\Tools\subplz-yt
.\subplz-yt.ps1 -Setup
```

**The `-Setup` flag will:**
- Automatically detect your SubPlz installation.
- Add this script to your User `PATH` so you can run `subplz-yt` from any folder.
- Configure necessary environment variables.

*If you installed SubPlz in a non-standard location, run: `.\subplz-yt.ps1 -Setup -SubPlzPath "C:\Your\Path"`*

---

## Troubleshooting

### `yt-dlp failed` or `missing python.exe`
If `uv` updates or its cache is cleared, the `yt-dlp` environment can break. Fix it instantly with:
```powershell
uv tool install yt-dlp --reinstall
```

### `SubPlz environment is broken`
If you see errors about `pkg_resources` or `setuptools`, run this inside your SubPlz folder:
```powershell
.venv\Scripts\pip.exe install "setuptools<78"
```

### Script execution is blocked
If Windows prevents running the script, run this once:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Usage

From any directory:

```powershell
# Full pipeline: video with embedded subs + standalone .srt
subplz-yt "https://www.youtube.com/watch?v=VIDEO_ID"

# Subs only: downloads audio only (much faster), outputs just the .srt
subplz-yt "https://www.youtube.com/watch?v=VIDEO_ID" -SubsOnly

# Use a different Whisper model
subplz-yt "https://www.youtube.com/watch?v=VIDEO_ID" -Model large

# Re-run configuration or add to path
subplz-yt -Setup
```

## Improvements in this version

- **Robust Health Checks:** Automatically verifies that `yt-dlp`, `ffmpeg`, and `SubPlz` are functional, not just installed.
- **Self-Healing Hints:** If a dependency is broken (common with `uv` or Python updates), the script provides the exact command to fix it.
- **Smart Naming:** Automatically handles file name collisions by appending numbers (e.g., `Video (1).mkv`).
- **Easy Setup:** The `-Setup` flag automates the environment variable configuration.

Output (default):

```
VideoTitle.mkv   ← video with embedded subtitles
VideoTitle.srt   ← standalone subtitle file
```

Output with `-SubsOnly`:

```
VideoTitle.srt   ← standalone subtitle file
```

To update the script later:

```powershell
cd C:\Tools\subplz-yt
git pull
```

## Troubleshooting

### Script execution blocked

The included `.bat` launcher bypasses execution policy automatically. If you want to run the `.ps1` script directly, either unblock the file:

```powershell
Unblock-File -Path "C:\Tools\subplz-yt\subplz-yt.ps1"
```

Or set the standard developer execution policy (scoped to your user account only):

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### SubPlz falls back to CPU

Ensure PyTorch was installed with CUDA support. Activate the SubPlz virtual environment and verify:

```powershell
cd C:\Tools\SubPlz
.venv\Scripts\activate
python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')"
```

If `False`, reinstall PyTorch with the CUDA index URL as shown in the installation steps.

### `No module named 'pkg_resources'`

Install an older version of setuptools in the SubPlz virtual environment:

```powershell
.venv\Scripts\pip.exe install "setuptools<78"
```

### SubPlz not found

If you installed SubPlz somewhere other than `C:\Tools\SubPlz`, set the `SUBPLZ_PATH` environment variable:

```powershell
[Environment]::SetEnvironmentVariable("SUBPLZ_PATH", "C:\your\path\to\SubPlz", "User")
```

## Optional

- [mpv](https://mpv.io/) — recommended video player with excellent subtitle support. Install via `winget install mpv`.

## License

MIT

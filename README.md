# LITERALLY EVERYTHING WAS VIBECODDED PROCEED WITH CAUTION
# subplz-yt

A simple wrapper script that downloads a YouTube video, generates accurate subtitles using [SubPlz](https://github.com/kanjieater/SubPlz), and outputs a video with embedded subs — all in one command.

## What it does

1. Downloads the video with yt-dlp
2. Generates subtitles using SubPlz (Whisper-based)
3. Soft-embeds the subs into the MKV container with ffmpeg
4. Outputs both the video (with embedded subs) and a standalone `.srt` file
5. Opens the result in mpv

## Prerequisites

- [SubPlz](https://github.com/kanjieater/SubPlz) — installed from source in a Python virtual environment
- [yt-dlp](https://github.com/yt-dlp/yt-dlp)
- [ffmpeg](https://ffmpeg.org/)
- [mpv](https://mpv.io/) (optional, for auto-playback)
- NVIDIA GPU recommended for fast subtitle generation

## Installation

1. Clone this repo:

   ```powershell
   git clone https://github.com/YOUR_USERNAME/subplz-yt.git
   ```

2. Copy the files to `C:\Tools\` (or wherever you prefer):

   ```powershell
   Copy-Item subplz-yt\subplz-yt.ps1 C:\Tools\
   Copy-Item subplz-yt\subplz-yt.bat C:\Tools\
   ```

3. Make sure `C:\Tools` is on your PATH:

   ```powershell
   [Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Tools", "User")
   ```

4. If needed, allow script execution:

   ```powershell
   Set-ExecutionPolicy Unrestricted -Scope CurrentUser
   ```

### SubPlz setup

If you haven't installed SubPlz yet:

```powershell
winget install astral-sh.uv
git clone https://github.com/kanjieater/SubPlz.git C:\Tools\SubPlz
cd C:\Tools\SubPlz
uv venv --python 3.11 .venv
.venv\Scripts\activate
uv pip install -e .
.venv\Scripts\pip.exe install "setuptools<78"
```

For GPU support (NVIDIA), install PyTorch with CUDA:

```powershell
.venv\Scripts\pip.exe install torch torchaudio --index-url https://download.pytorch.org/whl/cu128 --force-reinstall
```

## Usage

From any directory:

```powershell
subplz-yt "https://www.youtube.com/watch?v=VIDEO_ID"
```

Change the Whisper model (default is `turbo`):

```powershell
subplz-yt "https://www.youtube.com/watch?v=VIDEO_ID" -Model large
```

The output files land in your current working directory:

```
VideoTitle.mkv   ← video with embedded subtitles
VideoTitle.srt   ← standalone subtitle file
```

## Configuration

The script expects SubPlz installed at `C:\Tools\SubPlz`. To change this, edit the `$SubPlzExe` path in `subplz-yt.ps1`.

Set the `BASE_PATH` environment variable to avoid SubPlz creating config folders everywhere:

```powershell
[Environment]::SetEnvironmentVariable("BASE_PATH", "C:\Tools\SubPlz\config", "User")
```

## License

MIT

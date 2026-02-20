# subplz-yt

A wrapper script that downloads a YouTube video, generates accurate subtitles using [SubPlz](https://github.com/kanjieater/SubPlz), and outputs a video with embedded subs — all in one command.

## What it does

1. Downloads the video with yt-dlp (as MKV for subtitle compatibility)
2. Generates subtitles using SubPlz (Whisper-based, with VAD and stable-ts for accurate timestamps)
3. Soft-embeds the subs into the MKV container with ffmpeg (no re-encoding)
4. Outputs both the video and a standalone `.srt` file to your current directory

## Prerequisites

- Windows 10/11
- [Git](https://git-scm.com/)
- NVIDIA GPU recommended (CUDA-accelerated transcription is ~10x faster than CPU)

## Installation

### 1. Install dependencies

```powershell
winget install astral-sh.uv
winget install ffmpeg
winget install mpv
```

Install yt-dlp as a global tool via uv:

```powershell
uv tool install yt-dlp
uv tool update-shell
```

Close and reopen your terminal after these installs.

### 2. Install SubPlz from source

```powershell
git clone https://github.com/kanjieater/SubPlz.git
cd SubPlz
uv venv --python 3.11 .venv
.venv\Scripts\activate
uv pip install -e .
.venv\Scripts\pip.exe install "setuptools<78"
```

> **Why setuptools<78?** Newer versions removed `pkg_resources`, which `ctranslate2` (a SubPlz dependency) still requires.

#### GPU support (NVIDIA)

With the virtual environment still active, install PyTorch with CUDA:

```powershell
.venv\Scripts\pip.exe install torch torchaudio --index-url https://download.pytorch.org/whl/cu128 --force-reinstall
```

Verify:

```powershell
python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')"
```

Deactivate when done:

```powershell
deactivate
```

### 3. Set up the wrapper script

Clone this repo and place the scripts somewhere on your PATH:

```powershell
git clone https://github.com/JustVinny1/subplz-yt.git
```

Copy `subplz-yt.ps1` and `subplz-yt.bat` to a directory that's on your PATH. If you don't have one, create one and add it:

```powershell
mkdir C:\Scripts
Copy-Item subplz-yt\subplz-yt.ps1 C:\Scripts\
Copy-Item subplz-yt\subplz-yt.bat C:\Scripts\
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Scripts", "User")
```

### 4. Configure paths

Edit `subplz-yt.ps1` and update the `$SubPlzExe` variable to point to your SubPlz installation:

```powershell
$SubPlzExe = "C:\path\to\SubPlz\.venv\Scripts\subplz.exe"
```

Optionally, set `BASE_PATH` to prevent SubPlz from creating config folders in your working directory:

```powershell
[Environment]::SetEnvironmentVariable("BASE_PATH", "C:\path\to\SubPlz\config", "User")
```

Close and reopen your terminal after making environment variable changes.

## Usage

From any directory:

```powershell
subplz-yt "https://www.youtube.com/watch?v=VIDEO_ID"
```

Change the Whisper model (default is `turbo`):

```powershell
subplz-yt "https://www.youtube.com/watch?v=VIDEO_ID" -Model large
```

Output:

```
VideoTitle.mkv   ← video with embedded subtitles
VideoTitle.srt   ← standalone subtitle file
```

## Troubleshooting

### Script execution blocked

The included `.bat` launcher bypasses execution policy automatically. If you want to run the `.ps1` script directly, either unblock the file:

```powershell
Unblock-File -Path "C:\Scripts\subplz-yt.ps1"
```

Or set the standard developer execution policy (common practice, scoped to your user account only):

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### SubPlz falls back to CPU

Ensure PyTorch was installed with CUDA support. Activate the SubPlz virtual environment and verify:

```powershell
cd path\to\SubPlz
.venv\Scripts\activate
python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')"
```

If `False`, reinstall PyTorch with the CUDA index URL as shown in the installation steps.

### `No module named 'pkg_resources'`

Install an older version of setuptools in the SubPlz virtual environment:

```powershell
.venv\Scripts\pip.exe install "setuptools<78"
```

## License

MIT

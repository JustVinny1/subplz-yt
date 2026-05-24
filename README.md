# subplz-yt

A wrapper script that downloads YouTube videos, generates subtitles via [SubPlz](https://github.com/kanjieater/SubPlz), and embeds them into an MKV container.

## Installation (One-Step)

Clone the repository and run the automated setup flag. This will install all dependencies including `yt-dlp`, `ffmpeg`, and `SubPlz`.

```powershell
git clone https://github.com/JustVinny1/subplz-yt.git
cd subplz-yt
.\subplz-yt.ps1 -Setup
```

**What the setup does:**
- Installs `git`, `uv`, and `ffmpeg` (via winget) if missing.
- Installs `yt-dlp` globally.
- Clones and configures `SubPlz` in a local subdirectory.
- Detects NVIDIA GPUs and installs CUDA-enabled PyTorch automatically.
- Adds the script to your User `PATH` for global access.

*Restart your terminal after setup completes.*

## Usage

```powershell
# Full pipeline (video + embedded subs)
subplz-yt "URL"

# Subtitles only (audio download only)
subplz-yt "URL" -SubsOnly

# Custom Whisper model (default: turbo)
subplz-yt "URL" -Model large
```

## Troubleshooting

- **Broken yt-dlp environment:** `uv tool install yt-dlp --reinstall`
- **Execution Policy:** If Windows blocks the script, run `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`

## License

MIT

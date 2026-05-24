# subplz-yt

A wrapper script that downloads YouTube videos, generates subtitles via [SubPlz](https://github.com/kanjieater/SubPlz), and embeds them into an MKV container.

## Installation

Clone the repository and run the setup flag. The script will guide you through installing any missing dependencies.

```powershell
git clone https://github.com/JustVinny1/subplz-yt.git
cd subplz-yt
.\subplz-yt.ps1 -Setup
```

**The Setup Guide will:**
- Check for system tools (`git`, `uv`, `ffmpeg`) and ask before installing them via `winget`.
- Check for `yt-dlp` and ask before installing it via `uv`.
- Configure the `SubPlz` engine (cloning it into a subdirectory if not found elsewhere).
- Detect NVIDIA GPUs and offer to install CUDA-enabled PyTorch.
- Optionally add the script to your User `PATH` for global access.

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

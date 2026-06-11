# WEM Converter + Video Merger

Convert `.wem` game audio files to MP3/WAV/OGG/FLAC, and merge MP4 video + MP3 audio into a complete video.

## What is WEM?

`.wem` is an audio format used by **Audiokinetic Wwise**, a popular audio middleware in video games. These files use **Wwise Vorbis** codec (`0xFFFF`) wrapped in a RIFF/WAV container.

## Features

- **WEM → Audio**: Convert `.wem` to MP3, WAV, OGG, FLAC
- **Batch processing**: Process entire folders recursively
- **MP4 + MP3 → Video**: Merge a video file with an audio track
- **Cross-platform**: Windows (PowerShell + Python), Linux, Termux (Android)
- **Auto-setup**: Automatically downloads ww2ogg decoder on first run
- **Two modes**: Interactive menu or CLI one-liners

## How it Works

```
.wem → [ww2ogg] → .ogg → [ffmpeg] → .mp3/.wav/.flac/.ogg
.mp4 + .mp3 → [ffmpeg] → .mp4 (merged)
```

| Step | Tool | What it does |
|------|------|-------------|
| 1 | `ww2ogg` | Decodes Wwise Vorbis (`.wem`) to standard Ogg Vorbis |
| 2 | `ffmpeg` | Converts OGG to MP3/WAV/FLAC, or merges MP4+MP3 |

## Requirements

- **Python 3.6+** (Python script)
- **ffmpeg** (`pkg install ffmpeg` on Termux, `choco install ffmpeg` on Windows)
- **ww2ogg** (auto-downloaded on first run)

### Platform-specific

**Termux (Android):**
```bash
pkg update && pkg install ffmpeg python build-essential git
```

**Windows:**
- Install [Python](https://python.org)
- Install [ffmpeg](https://ffmpeg.org/download.html) and add to PATH
  - Or: `choco install ffmpeg`
  - Or: `winget install ffmpeg`

**Linux (Ubuntu/Debian):**
```bash
sudo apt install ffmpeg python3 python3-pip build-essential git
```

## Usage

### Menu Mode (Interactive)
```bash
python convert-wem.py
```

Shows a menu with options:
1. Convert WEM to Audio
2. Merge MP4 + MP3 to Video
3. Help

### CLI Mode (One-liners)

**Convert WEM files:**
```bash
# Convert all .wem in current folder to MP3 (output: ./convert/)
python convert-wem.py -wem .

# Custom folder and format
python convert-wem.py -wem /path/to/wem/files -f flac

# Custom bitrate
python convert-wem.py -wem . -f mp3 -b 320k

# Custom output directory
python convert-wem.py -wem . -o /path/to/output

# All options
python convert-wem.py -wem <folder> -f <format> -b <bitrate> -o <output>
```

**Merge MP4 + MP3:**
```bash
python convert-wem.py -merge video.mp4 audio.mp3
```

### Command-Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `-wem <folder>` | Folder containing .wem files | — |
| `-f, --format` | Output format: mp3, wav, ogg, flac | `mp3` |
| `-b, --bitrate` | Audio bitrate (e.g., 192k, 320k) | `192k` |
| `-o, --output` | Output directory | `<folder>/convert/` |
| `-merge <v> <a>` | Merge MP4 video + MP3 audio | — |
| `-h, --help` | Show help | — |

## PowerShell Script (Windows only)

A PowerShell version is also included for Windows users:

```powershell
.\Convert-Wem.ps1 -Path *.wem -Format mp3 -Bitrate 192000
.\Convert-Wem.ps1 -Help
```

## How ww2ogg is Installed

The Python script automatically handles ww2ogg setup:

- **Windows**: Downloads prebuilt `ww2ogg.exe` + codebooks from GitHub releases
- **Linux/Termux**: Clones source from GitHub and compiles with `g++`

Tools are cached in `~/.wemconverter/tools/`.

## Project Structure

```
convert-wem/
├── convert-wem.py       # Main Python script (cross-platform)
├── Convert-Wem.ps1      # PowerShell script (Windows)
├── README.md            # This file
└── .gitignore
```

## License

MIT

# WEM Converter + Video Merger

Chuyen doi file am thanh game `.wem` sang MP3/WAV/OGG/FLAC, va gop video MP4 + am thanh MP3 thanh mot video hoan chinh.

## WEM la gi?

`.wem` la dinh dang am thanh cua **Audiokinetic Wwise** (middleware am thanh pho bien trong game). Cac file nay su dung codec **Wwise Vorbis** (`0xFFFF`) duoc boc trong container RIFF/WAV.

## Tinh nang

- **WEM sang Audio**: Chuyen `.wem` sang MP3, WAV, OGG, FLAC
- **Xu ly hang loat**: Quet toan bo thu muc con
- **Gop MP4 + MP3**: Ghep file video voi file am thanh
- **Da nen tang**: Windows (PowerShell + Python), Linux, Termux (Android)
- **Tu dong cai dat**: Tai ww2ogg decoder lan chay dau tien
- **Hai che do**: Menu tuong tac hoac CLI

## Co che hoat dong

```
.wem => [ww2ogg] => .ogg => [ffmpeg] => .mp3/.wav/.flac/.ogg
.mp4 + .mp3 => [ffmpeg] => .mp4 (da gop)
```

| Buoc | Cong cu | Chuc nang |
|------|---------|-----------|
| 1 | `ww2ogg` | Giai ma Wwise Vorbis (`.wem`) -> Ogg Vorbis chuan |
| 2 | `ffmpeg` | Chuyen OGG sang MP3/WAV/FLAC, hoac gop MP4+MP3 |

## Yeu cau

- **Python 3.6+**
- **ffmpeg**
- **ww2ogg** (tu dong tai lan chay dau)

### Cai dat theo tung nen tang

**Termux (Android):**
```bash
pkg update && pkg install ffmpeg python build-essential git
```

**Windows:**
- Cai [Python](https://python.org)
- Cai [ffmpeg](https://ffmpeg.org/download.html) va them vao PATH
  - Hoac: `choco install ffmpeg`
  - Hoac: `winget install ffmpeg`

**Linux (Ubuntu/Debian):**
```bash
sudo apt install ffmpeg python3 python3-pip build-essential git
```

## Su dung

### Che do Menu (tuong tac)
```bash
python convert-wem.py
```

Menu hien ra:
1. Chuyen WEM sang Audio
2. Gop MP4 + MP3 thanh Video
3. Huong dan

### Che do CLI (mot dong)

**Chuyen file WEM:**
```bash
# Chuyen tat ca .wem trong thu muc hien tai sang MP3 (xuat ra ./convert/)
python convert-wem.py -wem .

# Thu muc va dinh dang tuy chinh
python convert-wem.py -wem /duong/dan/wem -f flac

# Chinh chat luong
python convert-wem.py -wem . -f mp3 -b 320k

# Chon thu muc xuat
python convert-wem.py -wem . -o /duong/dan/xuat

# Tat ca tuy chon
python convert-wem.py -wem <folder> -f <format> -b <bitrate> -o <output>
```

**Gop MP4 + MP3:**
```bash
python convert-wem.py -merge video.mp4 audio.mp3
```

### Bang tuy chon

| Tuy chon | Mo ta | Mac dinh |
|----------|-------|----------|
| `-wem <folder>` | Thu muc chua file .wem | — |
| `-f, --format` | Dinh dang xuat: mp3, wav, ogg, flac | `mp3` |
| `-b, --bitrate` | Chat luong am thanh (vd: 192k, 320k) | `192k` |
| `-o, --output` | Thu muc xuat ra | `<folder>/convert/` |
| `-merge <v> <a>` | Gop video MP4 + audio MP3 | — |
| `-h, --help` | Huong dan | — |

## Script PowerShell (Windows)

Phien ban PowerShell danh cho Windows:

```powershell
.\Convert-Wem.ps1 -Path *.wem -Format mp3 -Bitrate 192000
.\Convert-Wem.ps1 -Help
```

## Cach ww2ogg duoc cai dat

Python script tu dong xu ly viec cai ww2ogg:

- **Windows**: Tai `ww2ogg.exe` + codebooks tu GitHub
- **Linux/Termux**: Clone source tu GitHub va bien dich voi `g++`

Bo cong cu duoc luu tai `~/.wemconverter/tools/`.

## Cau truc thu muc

```
convert-wem/
├── convert-wem.py       # Script chinh (Python, da nen tang)
├── Convert-Wem.ps1      # Script PowerShell (Windows)
├── README.md            # File huong dan
└── .gitignore
```

## Ghi chu

Vi du du lieu WEM trong repo duoc trich xuat tu cac game pho bien chi voi muc dich minh hoa. Vui long ton trong ban quyen noi dung game.

## Giay phep

MIT

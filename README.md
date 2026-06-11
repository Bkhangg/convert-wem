# WEM Converter + Video Merger

Chuyển đổi file âm thanh game `.wem` sang MP3/WAV/OGG/FLAC, và ghép video MP4 + âm thanh MP3 thành một video hoàn chỉnh.

---

## Bắt đầu nhanh

```bash
# 1. Clone repo
git clone https://github.com/Bkhangg/convert-wem.git
cd convert-wem

# 2. Cài ffmpeg (nếu chưa có)
#   Termux : pkg install ffmpeg
#   Ubuntu : sudo apt install ffmpeg
#   Windows: winget install ffmpeg

# 3. Chạy thử
python convert-wem.py -wem .
```

Kết quả: tất cả file `.wem` trong thư mục hiện tại được chuyển sang MP3, lưu trong thư mục `./convert/`.

---

## WEM là gì?

`.wem` là định dạng âm thanh của **Audiokinetic Wwise** — middleware âm thanh rất phổ biến trong game. Các file này dùng codec **Wwise Vorbis** (`0xFFFF`) được bọc trong container RIFF/WAV.

Trình phát nhạc thông thường và ffmpeg **không** mở được trực tiếp. Cần `ww2ogg` để giải mã — script sẽ tự động tải về ở lần chạy đầu tiên.

## Tính năng

| Tính năng | Mô tả |
|-----------|-------|
| 🎵 **WEM → Audio** | Chuyển `.wem` sang MP3, WAV, OGG, FLAC |
| 📂 **Xử lý hàng loạt** | Quét toàn bộ thư mục con, xử lý tất cả file `.wem` |
| 🎬 **MP4 + MP3 → Video** | Ghép video với nhạc nền, giữ nguyên chất lượng video gốc |
| 💻 **Đa nền tảng** | Windows (PowerShell + Python), Linux, Termux (Android) |
| ⚙️ **Tự động cài đặt** | Tự tải `ww2ogg` + codebook ở lần chạy đầu tiên |
| 🎯 **Hai chế độ** | Menu tương tác hoặc CLI một dòng |

## Cách hoạt động

```
.wem ──→ [ww2ogg] ──→ .ogg ──→ [ffmpeg] ──→ .mp3 / .wav / .flac / .ogg
.mp4 + .mp3 ──────→ [ffmpeg] ──→ .mp4 (đã ghép)
```

| Bước | Công cụ | Chức năng |
|------|---------|-----------|
| 1 | `ww2ogg` | Giải mã Wwise Vorbis (`.wem`) → Ogg Vorbis chuẩn |
| 2 | `ffmpeg` | Chuyển OGG sang MP3/WAV/FLAC, hoặc ghép MP4+MP3 |

## Yêu cầu

- **Python 3.6+**
- **ffmpeg**
- **ww2ogg** (tự động tải ở lần chạy đầu — không cần cài thủ công)

### Cài đặt theo từng nền tảng

<details>
<summary><b>Termux (Android)</b></summary>

```bash
pkg update && pkg install ffmpeg python build-essential git
```
</details>

<details>
<summary><b>Windows</b></summary>

```bash
# Cài Python: https://python.org
# Cài ffmpeg (chọn 1 cách):
winget install ffmpeg
# hoặc: choco install ffmpeg
# hoặc tải manual: https://ffmpeg.org/download.html
```
</details>

<details>
<summary><b>Linux (Ubuntu/Debian)</b></summary>

```bash
sudo apt update
sudo apt install ffmpeg python3 python3-pip build-essential git
```
</details>

## Cách sử dụng

### Chế độ Menu (tương tác)

Chạy không tham số:

```bash
python convert-wem.py
```

Menu hiện ra:
```
  1. Chuyển WEM sang Audio
  2. Ghép MP4 + MP3 thành Video
  3. Hướng dẫn
  0. Thoát
```

Chọn **1**, nhập đường dẫn thư mục chứa file `.wem`, mặc định output ra thư mục `./convert/`.

### Chế độ CLI (một dòng)

**Chuyển file WEM:**

```bash
# Chuyển tất cả .wem trong thư mục hiện tại sang MP3
python convert-wem.py -wem .

# Chọn thư mục và định dạng
python convert-wem.py -wem /đường/dẫn/wem -f flac

# Chất lượng cao
python convert-wem.py -wem . -f mp3 -b 320k

# Xuất ra thư mục riêng
python convert-wem.py -wem . -o /đường/dẫn/xuất
```

**Ghép MP4 + MP3:**

```bash
python convert-wem.py -merge video.mp4 nhac.mp3
```

Kết quả: `./convert/video_merged.mp4`

### Bảng tùy chọn

| Tùy chọn | Mô tả | Mặc định |
|----------|-------|----------|
| `-wem <folder>` | Thư mục chứa file `.wem` | — |
| `-f, --format` | Định dạng xuất: mp3, wav, ogg, flac | `mp3` |
| `-b, --bitrate` | Chất lượng âm thanh (vd: 192k, 320k) | `192k` |
| `-o, --output` | Thư mục xuất ra | `<folder>/convert/` |
| `-merge <v> <a>` | Ghép video MP4 + audio MP3 | — |
| `-h, --help` | Xem hướng dẫn | — |

## Script PowerShell (Windows)

Bao gồm thêm bản PowerShell cho người dùng Windows:

```powershell
.\Convert-Wem.ps1 -Path *.wem -Format mp3 -Bitrate 192000
.\Convert-Wem.ps1 -Help
```

## Cách ww2ogg được cài đặt

Script Python tự động xử lý việc cài `ww2ogg`:

- **Windows**: Tải `ww2ogg.exe` + codebooks từ GitHub releases (bản build sẵn)
- **Linux/Termux**: Clone source từ GitHub và biên dịch với `g++`

Bộ công cụ được lưu tại `~/.wemconverter/tools/`. Lần chạy sau sẽ dùng lại, không cần tải lại.

## Cấu trúc thư mục

```
convert-wem/
├── convert-wem.py       # Script chính (Python, đa nền tảng)
├── Convert-Wem.ps1      # Script PowerShell (Windows)
├── README.md            # File hướng dẫn
└── .gitignore
```

## Giấy phép

MIT

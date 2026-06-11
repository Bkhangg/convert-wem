#!/usr/bin/env python3
import os, sys, struct, shutil, subprocess, tempfile, glob, time
from pathlib import Path

WW2OGG_URL = "https://github.com/hcs64/ww2ogg/archive/refs/heads/master.zip"
CODEBOOK_URL = "https://raw.githubusercontent.com/hcs64/ww2ogg/master/packed_codebooks_aoTuV_603.bin"
TOOL_DIR = Path.home() / ".wemconverter" / "tools"

C = lambda c, t: f"\033[{c}m{t}\033[0m"
info = lambda t: print(f"  {C(36,'>')} {t}")
ok   = lambda t: print(f"  {C(32,'+')} {t}")
err  = lambda t: print(f"  {C(31,'!')} {t}")
warn = lambda t: print(f"  {C(33,'?')} {t}")
dim  = lambda t: print(f"  {C(90,'-')} {t}")

def show_banner():
    print()
    print(C(36,r"   __      _______ _   _ _____  _    _ ____   ___ "))
    print(C(36,r"   \ \    / / ____| \ | |  __ \| |  | / ___| / _ \ "))
    print(C(36,r"    \ \  / / |    |  \| | |  | | |  | \___ \| | | |"))
    print(C(36,r"     \ \/ /| |____| . ` | |__| | |__| |___| | |_| |"))
    print(C(36,r"      \__/  \_____|_|\_|_____/ \____/ \____/ \___/ "))
    print(C(33,"     WEM Converter v2.0  +  MP4+MP3 Merger"))
    print(C(90,"  ============================================"))

MENU = f"""
{C(36,'  +-----------------------------------------------+')}
{C(36,'  |')}  {C(93,'1')}  Chuyen doi WEM sang Audio                 {C(36,'|')}
{C(36,'  |')}  {C(93,'2')}  Gop MP4 + MP3 thanh Video                {C(36,'|')}
{C(36,'  |')}  {C(93,'3')}  Huong dan                               {C(36,'|')}
{C(36,'  |')}  {C(93,'0')}  Thoat                                   {C(36,'|')}
{C(36,'  +-----------------------------------------------+')}
"""

def clear():
    os.system("cls" if os.name == "nt" else "clear")


def get_wem_info(path):
    try:
        with open(path, "rb") as f:
            data = f.read(40)
        if data[0:4] != b"RIFF" or data[8:12] != b"WAVE":
            return None
        fmt_tag = struct.unpack("<H", data[20:22])[0]
        channels = struct.unpack("<H", data[22:24])[0]
        sample_rate = struct.unpack("<I", data[24:28])[0]
        codec_map = {0x0001: "PCM", 0x0002: "ADPCM", 0x0003: "IEEE Float", 0xFFFF: "Wwise Vorbis", 0xFFFE: "Extensible"}
        return {"format_tag": fmt_tag, "codec": codec_map.get(fmt_tag, f"Unknown"), "channels": channels, "sample_rate": sample_rate, "file_size": os.path.getsize(path)}
    except:
        return None


def ensure_ww2ogg():
    is_win = sys.platform.startswith("win")
    exe_name = "ww2ogg.exe" if is_win else "ww2ogg"
    exe = TOOL_DIR / exe_name
    cb = TOOL_DIR / "packed_codebooks_aoTuV_603.bin"

    if exe.exists() and cb.exists():
        return str(exe), str(cb)

    warn("ww2ogg not found, setting up...")
    TOOL_DIR.mkdir(parents=True, exist_ok=True)

    if not cb.exists():
        info("Downloading codebook...")
        try:
            import urllib.request
            urllib.request.urlretrieve(CODEBOOK_URL, cb)
            ok("Codebook downloaded")
        except:
            err("Failed to download codebook"); return None

    if is_win:
        info("Downloading ww2ogg for Windows...")
        tmpdir = Path(tempfile.mkdtemp())
        try:
            import urllib.request, zipfile
            zf = tmpdir / "ww2ogg.zip"
            urllib.request.urlretrieve(
                "https://github.com/hcs64/ww2ogg/releases/download/0.24/ww2ogg024.zip", zf)
            with zipfile.ZipFile(zf) as z:
                z.extractall(tmpdir)
            src = tmpdir
            for f in src.rglob("*"):
                if f.name in ("ww2ogg.exe", "packed_codebooks.bin", "packed_codebooks_aoTuV_603.bin"):
                    shutil.copy2(f, TOOL_DIR / f.name)
            if not exe.exists():
                err("Failed to extract ww2ogg.exe"); return None
            ok("ww2ogg ready"); return str(exe), str(cb)
        except Exception as e:
            err(f"Failed to download ww2ogg: {e}"); return None
        finally:
            shutil.rmtree(tmpdir, ignore_errors=True)
    else:
        tmpdir = Path(tempfile.mkdtemp())
        try:
            if shutil.which("git"):
                subprocess.run(["git", "clone", "--depth", "1", "https://github.com/hcs64/ww2ogg.git",
                               str(tmpdir / "src")], capture_output=True, timeout=60)
                src = tmpdir / "src"
            else:
                import urllib.request, zipfile
                zf = tmpdir / "ww2ogg.zip"
                urllib.request.urlretrieve(WW2OGG_URL, zf)
                zipfile.ZipFile(zf).extractall(tmpdir)
                src = next(tmpdir.glob("ww2ogg-*"))
            if not shutil.which("g++"):
                err("Install build-essential first:"); err("  pkg install build-essential"); return None
            cpp = sorted(Path(src, "src").glob("*.cpp"))
            r = subprocess.run(["g++", "-O2", "-o", str(exe)] + [str(f) for f in cpp]
                               + ["-I", str(src / "src"), "-lm"], capture_output=True, timeout=120)
            if r.returncode != 0:
                r = subprocess.run(["make"], capture_output=True, timeout=120, cwd=src)
                if r.returncode == 0: shutil.copy(src / "ww2ogg", exe)
            if not exe.exists():
                err("Failed to compile ww2ogg"); return None
            for x in src.glob("packed_codebooks*.bin"):
                shutil.copy(x, TOOL_DIR)
            exe.chmod(0o755)
            ok("ww2ogg ready"); return str(exe), str(cb)
        except Exception as e:
            err(f"Setup failed: {e}"); return None
        finally:
            shutil.rmtree(tmpdir, ignore_errors=True)


def wem_to_ogg(wem, ogg, exe, cb):
    r = subprocess.run([exe, wem, "--pcb", cb, "-o", ogg], capture_output=True, timeout=60)
    return r.returncode == 0 and os.path.exists(ogg)


def ffmpeg_convert(inp, out, fmt, bitrate="192k"):
    codec = {"mp3": ["-c:a", "libmp3lame", "-b:a", bitrate], "wav": ["-c:a", "pcm_s16le"],
             "ogg": ["-c:a", "libvorbis", "-b:a", bitrate], "flac": ["-c:a", "flac"]}
    r = subprocess.run(["ffmpeg", "-y", "-i", inp] + codec[fmt] + [out], capture_output=True, timeout=120)
    return r.returncode == 0


def convert_wem(in_dir, out_dir, fmt, bitrate, keep_ogg):
    files = sorted(set(glob.glob(str(Path(in_dir) / "**/*.wem"), recursive=True)))
    if not files:
        err(f"No .wem files found in {in_dir}"); return
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    needs = any((i := get_wem_info(f)) and i["format_tag"] == 0xFFFF for f in files if os.path.isfile(f))
    ww2ogg = None
    if needs:
        is_win = sys.platform.startswith("win")
        exe_name = "ww2ogg.exe" if is_win else "ww2ogg"
        exe = TOOL_DIR / exe_name; cb = TOOL_DIR / "packed_codebooks_aoTuV_603.bin"
        if exe.exists() and cb.exists():
            ww2ogg = (str(exe), str(cb))
        else:
            ww2ogg = ensure_ww2ogg()
    ok(f"Found {len(files)} WEM file(s)")
    dim(f"Input:  {in_dir}")
    dim(f"Output: {out_dir}")
    dim(f"Format: {fmt.upper()}")
    print()
    count = 0
    for f in files:
        if not os.path.isfile(f): continue
        info_data = get_wem_info(f)
        if not info_data:
            err(f"{Path(f).name}: Invalid WEM"); continue
        name = Path(f).stem
        ext = f".{fmt}" if fmt != "mp3" else ".mp3"
        out = out_dir / f"{name}{ext}"
        info(f"{name} : {info_data['codec']} | {info_data['channels']}ch | {info_data['sample_rate']}Hz | {info_data['file_size']/1024:.1f}KB")
        try:
            if info_data["format_tag"] == 0xFFFF:
                if not ww2ogg:
                    err(f"{name}: SKIPPED - no ww2ogg"); continue
                t_ogg = tempfile.NamedTemporaryFile(suffix=".ogg", delete=False).name
                if wem_to_ogg(f, t_ogg, *ww2ogg):
                    if fmt == "ogg":
                        shutil.move(t_ogg, out)
                    elif ffmpeg_convert(t_ogg, out, fmt, bitrate):
                        if not keep_ogg: os.unlink(t_ogg)
                    else:
                        err(f"{name}: Convert failed"); os.unlink(t_ogg); continue
                else:
                    err(f"{name}: ww2ogg failed"); os.unlink(t_ogg); continue
            elif ffmpeg_convert(f, out, fmt, bitrate):
                pass
            else:
                err(f"{name}: Convert failed"); continue
            ok(f"{name}.{fmt} -> {os.path.getsize(out)/1024:.1f}KB")
            count += 1
        except Exception as e:
            err(f"{name}: {e}")
    print()
    ok(f"Converted {count}/{len(files)} file(s)")


def merge_video(video, audio, output):
    if not os.path.isfile(video):
        err("Video file not found"); return
    if not os.path.isfile(audio):
        err("Audio file not found"); return
    output = Path(output)
    info(f"Video: {Path(video).name}")
    info(f"Audio: {Path(audio).name}")
    info(f"Output: {output.name}")
    print()
    r = subprocess.run(["ffmpeg", "-y", "-i", video, "-i", audio,
                        "-c:v", "copy", "-c:a", "aac",
                        "-map", "0:v:0", "-map", "1:a:0",
                        "-shortest", str(output)],
                       capture_output=True, timeout=300)
    if r.returncode == 0:
        ok(f"Merged successfully: {output.name} ({os.path.getsize(output)/1024:.1f}KB)")
    else:
        err("Merge failed")
        stderr = r.stderr.decode(errors="ignore")
        for line in stderr.split("\n"):
            if "error" in line.lower() or "invalid" in line.lower():
                dim(line.strip())


def menu_convert():
    clear()
    show_banner()
    print(C(93,"  CONVERT WEM TO AUDIO"))
    print("  " + "=" * 40)
    default_in = os.getcwd()
    inp = input(f"\n  {C(36,'?')} WEM folder [{default_in}]: ").strip()
    in_dir = inp if inp else default_in
    default_out = str(Path(in_dir) / "convert")
    out = input(f"  {C(36,'?')} Output folder [{default_out}]: ").strip()
    out_dir = out if out else default_out
    fmt = input(f"  {C(36,'?')} Format (mp3/wav/ogg/flac) [mp3]: ").strip().lower() or "mp3"
    if fmt not in ("mp3", "wav", "ogg", "flac"): fmt = "mp3"
    bit = input(f"  {C(36,'?')} Bitrate (e.g. 192k, 320k) [192k]: ").strip() or "192k"
    print()
    convert_wem(in_dir, out_dir, fmt, bit, False)
    input(f"\n  {C(90,'Press Enter...')}")


def menu_merge():
    clear()
    show_banner()
    print(C(93,"  MERGE MP4 + MP3 TO VIDEO"))
    print("  " + "=" * 40)
    video = input(f"\n  {C(36,'?')} Video file (MP4): ").strip()
    audio = input(f"  {C(36,'?')} Audio file (MP3): ").strip()
    default_out = str(Path.cwd() / "convert" / f"{Path(video).stem}_merged.mp4")
    out = input(f"  {C(36,'?')} Output file [{default_out}]: ").strip()
    output = out if out else default_out
    Path(output).parent.mkdir(parents=True, exist_ok=True)
    print()
    merge_video(video, audio, output)
    input(f"\n  {C(90,'Press Enter...')}")


def menu_help():
    clear()
    show_banner()
    print(C(93,"  HELP"))
    print("  " + "=" * 40)
    print("""
  Requirements:
    - ffmpeg (pkg install ffmpeg)
    - python 3

  WEM -> Audio:
    - Put all .wem files in a folder
    - Select that folder when prompted
    - Output goes to <folder>/convert/

  MP4 + MP3 -> Video:
    - Requires 1 video file (.mp4) and 1 audio file (.mp3)
    - Keeps original video quality
    - Audio re-encoded to AAC

  CLI mode (no menu):
    python convert-wem.py -wem <folder> -f mp3
    python convert-wem.py -merge video.mp4 audio.mp3
""")
    input(f"  {C(90,'Press Enter...')}")


# ===== CLI =====
def cli_mode():
    import argparse
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("-wem", type=str, help="Convert WEM from folder")
    parser.add_argument("-f", "--format", default="mp3", choices=["mp3","wav","ogg","flac"])
    parser.add_argument("-b", "--bitrate", default="192k")
    parser.add_argument("-o", "--output", type=str, help="Output directory")
    parser.add_argument("-merge", nargs=2, metavar=("VIDEO", "AUDIO"), help="Merge MP4 + MP3")
    parser.add_argument("-h", "--help", action="store_true")

    args, _ = parser.parse_known_args()

    if args.help or (not args.wem and not args.merge):
        print(f"""  {C(36,'+-----------------------------------------------+')}
  {C(36,'|')}  {C(93,'WEM Converter + Video Merger')}              {C(36,'|')}
  {C(36,'+-----------------------------------------------+')}

  {C(93,'MENU MODE:')}   python {sys.argv[0]}
  {C(93,'CLI MODE:')}    python {sys.argv[0]} -wem <folder> -f mp3 -o ./out
          python {sys.argv[0]} -merge video.mp4 audio.mp3

  {C(93,'WEM -> Audio:')}
    -wem <folder>     Folder containing .wem files
    -f, --format       Format: mp3, wav, ogg, flac (default: mp3)
    -b, --bitrate      Bitrate (default: 192k)
    -o, --output       Output folder (default: <folder>/convert)

  {C(93,'MP4 + MP3 -> Video:')}
    -merge v.mp4 a.mp3  Merge video and audio
""")
        return

    if args.wem:
        in_dir = args.wem
        out_dir = args.output if args.output else str(Path(in_dir) / "convert")
        if not shutil.which("ffmpeg"):
            err("ffmpeg not found"); return
        convert_wem(in_dir, out_dir, args.format, args.bitrate, False)

    if args.merge:
        if not shutil.which("ffmpeg"):
            err("ffmpeg not found"); return
        video, audio = args.merge
        default_out = str(Path.cwd() / "convert" / f"{Path(video).stem}_merged.mp4")
        Path(default_out).parent.mkdir(parents=True, exist_ok=True)
        merge_video(video, audio, default_out)


# ===== MAIN =====
if __name__ == "__main__":
    if len(sys.argv) > 1:
        cli_mode()
    else:
        while True:
            clear()
            show_banner()
            print(MENU)
            choice = input(f"  {C(93,'Chon:')} ").strip()
            if choice == "1":
                menu_convert()
            elif choice == "2":
                menu_merge()
            elif choice == "3":
                menu_help()
            elif choice == "0":
                clear()
                print(f"  {C(93,'Tam biet!')}")
                break

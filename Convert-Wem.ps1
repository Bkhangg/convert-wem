param(
    [Parameter(Position=0)]
    [string[]]$Path,

    [Parameter()]
    [ValidateSet("mp3", "wav", "ogg", "flac")]
    [string]$Format = "mp3",

    [Parameter()]
    [int]$Bitrate = 192000,

    [Parameter()]
    [string]$OutputDir = "",

    [Parameter()]
    [switch]$KeepOgg,

    [Parameter()]
    [switch]$ForceDownload,

    [Parameter()]
    [Alias("h", "?")]
    [switch]$Help
)

if ($Help) {
    Write-Host @"
WEM Audio Converter - Convert .wem/.bnk files to MP3/WAV/OGG/FLAC

USAGE:
  Convert-Wem.ps1 [[-Path] <string[]>] [-Format mp3|wav|ogg|flac] [options]

EXAMPLES:
  .\Convert-Wem.ps1                               # All .wem/.bnk in current dir
  .\Convert-Wem.ps1 -Path *.wem                    # Wildcard selection
  .\Convert-Wem.ps1 -Path folder                   # All .wem/.bnk in folder
  .\Convert-Wem.ps1 a.wem b.wem                   # Multiple specific files
  .\Convert-Wem.ps1 -Path *.bnk                    # All .bnk files
  .\Convert-Wem.ps1 -Format wav                    # Output as WAV
  .\Convert-Wem.ps1 -Format mp3 -Bitrate 320000    # High quality MP3
  .\Convert-Wem.ps1 -OutputDir D:\out -Format flac # Custom output dir

If -Path is not specified, scans current directory for .wem and .bnk files.
BNK (Wwise SoundBank) files are extracted automatically.

"@
    exit
}

function Write-Color {
    param([string]$Text, [string]$Color = "White")
    Write-Host $Text -ForegroundColor $Color
}

function Get-WemFormatInfo {
    param([string]$FilePath)
    try {
        $bytes = [System.IO.File]::ReadAllBytes($FilePath)
        if ([System.Text.Encoding]::ASCII.GetString($bytes[0..3]) -ne "RIFF") { return $null }
        if ([System.Text.Encoding]::ASCII.GetString($bytes[8..11]) -ne "WAVE") { return $null }

        return @{
            FormatTag  = [System.BitConverter]::ToUInt16($bytes, 20)
            Channels   = [System.BitConverter]::ToUInt16($bytes, 22)
            SampleRate = [System.BitConverter]::ToUInt32($bytes, 24)
            BitDepth   = [System.BitConverter]::ToUInt16($bytes, 34)
            FileSize   = [System.BitConverter]::ToUInt32($bytes, 4) + 8
            Codec      = switch ([System.BitConverter]::ToUInt16($bytes, 20)) {
                0x0001 { "PCM" }
                0x0002 { "ADPCM" }
                0x0003 { "IEEE Float" }
                0xFFFF { "Wwise Vorbis" }
                0xFFFE { "Extensible" }
                default { "Unknown (0x{0:X4})" -f $_ }
            }
        }
    } catch { return $null }
}

function Get-ToolPath {
    param([string]$Name)
    $paths = @(
        "$PSScriptRoot\tools\$Name"
        "$env:LOCALAPPDATA\WemConverter\tools\$Name"
    )
    $existing = Get-Command $Name -ErrorAction SilentlyContinue
    if ($existing) { return $existing.Source }
    foreach ($p in $paths) {
        if (Test-Path $p) { return (Resolve-Path $p).Path }
    }
    return $null
}

function Get-ToolDir {
    $dir = "$env:LOCALAPPDATA\WemConverter\tools"
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    return $dir
}

function Install-Ww2ogg {
    param()
    $toolDir = Get-ToolDir
    $exePath = "$toolDir\ww2ogg.exe"

    if ((Test-Path $exePath) -and -not $ForceDownload) {
        return @{ Exe = $exePath; Codebook = "$toolDir\packed_codebooks_aoTuV_603.bin" }
    }

    Write-Color "  -> Downloading ww2ogg v0.24..." -Color Yellow

    $zipUrl = "https://github.com/hcs64/ww2ogg/releases/download/0.24/ww2ogg024.zip"
    $zipFile = "$toolDir\ww2ogg024.zip"
    $extractDir = "$toolDir\ww2ogg_extract"

    try {
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile -UseBasicParsing -ErrorAction Stop

        Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue
        Expand-Archive -Path $zipFile -DestinationPath $extractDir -Force

        $filesToCopy = @("ww2ogg.exe", "packed_codebooks.bin", "packed_codebooks_aoTuV_603.bin")
        foreach ($f in $filesToCopy) {
            $src = Get-ChildItem -Path $extractDir -Recurse -Filter $f | Select-Object -First 1
            if ($src) { Copy-Item $src.FullName -Destination "$toolDir\$f" -Force }
        }

        Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $zipFile -Force -ErrorAction SilentlyContinue

        if (Test-Path $exePath) {
            Write-Color "  -> Downloaded ww2ogg successfully" -Color Green
            return @{ Exe = $exePath; Codebook = "$toolDir\packed_codebooks_aoTuV_603.bin" }
        }
    } catch {
        Write-Color "  -> Failed to download ww2ogg: $_" -Color Red
        Write-Color "       Manual: get ww2ogg from https://github.com/hcs64/ww2ogg/releases" -Color DarkYellow
        return $null
    }
}

function Convert-WemToOgg {
    param(
        [string]$WemPath,
        [string]$OggPath,
        [hashtable]$Ww2ogg
    )
    if (-not $Ww2ogg) { throw "ww2ogg not available" }

    $result = & $Ww2ogg.Exe $WemPath --pcb $Ww2ogg.Codebook -o $OggPath 2>&1
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $OggPath)) {
        throw "ww2ogg failed: $($result -join ' ')"
    }
}

function Convert-Audio {
    param([string]$InputPath, [string]$OutputPath)

    $codecArgs = switch ($Format) {
        "mp3"  { @("-c:a", "libmp3lame", "-b:a", "$Bitrate") }
        "wav"  { @("-c:a", "pcm_s16le") }
        "ogg"  { @("-c:a", "libvorbis", "-b:a", "$Bitrate") }
        "flac" { @("-c:a", "flac") }
    }

    $argStr = "-y -i `"$InputPath`" $($codecArgs -join ' ') `"$OutputPath`""
    $result = cmd /c "ffmpeg.exe $argStr 2>&1"
    if ($LASTEXITCODE -ne 0) {
        throw "ffmpeg failed (exit $LASTEXITCODE)"
    }
}

function Convert-WemFile {
    param(
        [string]$FilePath,
        [hashtable]$Ww2ogg
    )

    $info = Get-WemFormatInfo $FilePath
    if (-not $info) {
        Write-Color "  [!] $(Split-Path $FilePath -Leaf) : Invalid WEM file" -Color Red
        return
    }

    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
    $outDir = if ($OutputDir) { $OutputDir } else { [System.IO.Path]::GetDirectoryName($FilePath) }
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null

    $ext = if ($Format -eq "mp3") { ".mp3" } else { ".$Format" }
    $outputPath = Join-Path $outDir "$fileName$ext"

    Write-Color "  [>] $fileName : $($info.Codec) | $($info.Channels)ch | $($info.SampleRate)Hz | $('{0:N1}' -f ($info.FileSize/1KB))KB" -Color Cyan

    try {
        if ($info.FormatTag -ne 0xFFFF) {
            if ($info.FormatTag -eq 0x0001 -and $Format -eq "wav") {
                Copy-Item $FilePath -Destination $outputPath -Force
                Write-Color "  [+] $fileName : Already WAV PCM" -Color Green
                return
            }
            Convert-Audio -InputPath $FilePath -OutputPath $outputPath
        } else {
            if (-not $Ww2ogg) {
                Write-Color "  [-] $fileName : SKIPPED - need ww2ogg for Wwise Vorbis" -Color Red
                return
            }

            $tempOgg = Join-Path $env:TEMP "$fileName.temp.ogg"
            Convert-WemToOgg -WemPath $FilePath -OggPath $tempOgg -Ww2ogg $Ww2ogg

            if ($Format -eq "ogg") {
                Move-Item $tempOgg -Destination $outputPath -Force
            } else {
                Convert-Audio -InputPath $tempOgg -OutputPath $outputPath
                if (-not $KeepOgg -and (Test-Path $tempOgg)) {
                    Remove-Item $tempOgg -Force -ErrorAction SilentlyContinue
                }
            }
        }

        $size = (Get-Item $outputPath).Length
        Write-Color "  [+] $fileName -> $('{0:N1}' -f ($size/1KB))KB | $Format" -Color Green
    } catch {
        Write-Color "  [X] $fileName : $_" -Color Red
    }
}

# === MAIN ===

$ErrorActionPreference = "Stop"

Write-Color "==============================================" -Color Cyan
Write-Color "  WEM/BNK Audio Converter" -Color Cyan
Write-Color "  Converts .wem/.bnk files to MP3/WAV/OGG/FLAC" -Color Cyan
Write-Color "==============================================" -Color Cyan

$ffmpeg = Get-Command "ffmpeg.exe" -ErrorAction SilentlyContinue
if (-not $ffmpeg) {
    Write-Color "[!] ffmpeg not found. Install from: https://ffmpeg.org/download.html" -Color Red
    exit 1
}
Write-Color "[i] ffmpeg: $($ffmpeg.Source)" -Color DarkYellow

function Parse-Bnk {
    param([string]$BnkPath)
    try {
        $bytes = [System.IO.File]::ReadAllBytes($BnkPath)
        $offset = 0
        $sections = @{}
        while ($offset + 8 -le $bytes.Length) {
            $sid = [System.Text.Encoding]::ASCII.GetString($bytes[$offset..($offset+3)])
            $slen = [System.BitConverter]::ToUInt32($bytes, $offset+4)
            if ($offset + 8 + $slen -gt $bytes.Length) { break }
            $sections[$sid] = @{ Data = $bytes[$offset+8..($offset+8+$slen-1)]; Start = $offset + 8 }
            $offset += 8 + $slen
            if ($slen % 4 -ne 0) { $offset += 4 - ($slen % 4) }
        }
        if (-not $sections.ContainsKey('DIDX') -or -not $sections.ContainsKey('DATA')) { return $null }
        $didx = $sections['DIDX'].Data
        $dataStart = $sections['DATA'].Start
        $entries = @()
        for ($i = 0; $i -lt $didx.Length; $i += 12) {
            if ($i + 12 -gt $didx.Length) { break }
            $id   = [System.BitConverter]::ToUInt32($didx, $i)
            $off  = [System.BitConverter]::ToUInt32($didx, $i+4)
            $sz   = [System.BitConverter]::ToUInt32($didx, $i+8)
            $wemData = $bytes[($dataStart+$off)..($dataStart+$off+$sz-1)]
            $entries += @{ Id = $id; Offset = $off; Size = $sz; Data = $wemData }
        }
        return $entries
    } catch { return $null }
}

function Extract-Bnk {
    param([string]$BnkPath, [string]$OutputDir)
    $entries = Parse-Bnk $BnkPath
    if (-not $entries) {
        Write-Color "  [!] $(Split-Path $BnkPath -Leaf) : Invalid BNK" -Color Red
        return @()
    }
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    $extracted = @()
    $bankName = [System.IO.Path]::GetFileNameWithoutExtension($BnkPath)
    foreach ($e in $entries) {
        $wemPath = Join-Path $OutputDir "$($e.Id).wem"
        [System.IO.File]::WriteAllBytes($wemPath, $e.Data)
        $extracted += $wemPath
    }
    Write-Color "  [+] Extracted $($entries.Count) WEM(s) from $bankName.bnk" -Color Green
    return $extracted
}

$files = @()
$bnkFiles = @()
if ($Path -and $Path.Count -gt 0) {
    foreach ($p in $Path) {
        $resolved = @()
        if (Test-Path $p -PathType Container) {
            $resolved = Get-ChildItem -Path $p -Include "*.wem","*.bnk" -Recurse | Select-Object -ExpandProperty FullName
        } elseif (Test-Path $p -PathType Leaf) {
            $resolved = @((Resolve-Path $p).Path)
        } else {
            $resolved = Get-ChildItem -Path $p -Include "*.wem","*.bnk" | Select-Object -ExpandProperty FullName
        }
        foreach ($f in $resolved) {
            if ($f -like "*.bnk") { $bnkFiles += $f } else { $files += $f }
        }
    }
} else {
    $dir = (Get-Location).Path
    $foundWem = Get-ChildItem -Path $dir -Filter "*.wem" -Recurse | Select-Object -ExpandProperty FullName
    $foundBnk = Get-ChildItem -Path $dir -Filter "*.bnk" -Recurse | Select-Object -ExpandProperty FullName
    $files = $foundWem
    $bnkFiles = $foundBnk
    if ($files.Count -eq 0 -and $bnkFiles.Count -eq 0) {
        Write-Color "[!] No .wem or .bnk files found in current directory." -Color Red
        Write-Color "" -Color White
        Write-Color "USAGE:" -Color Yellow
        Write-Color "  .\Convert-Wem.ps1 -Path file.wem              # single file" -Color DarkYellow
        Write-Color "  .\Convert-Wem.ps1 -Path a.wem,b.wem           # multiple files" -Color DarkYellow
        Write-Color "  .\Convert-Wem.ps1 -Path folder                # all .wem in folder" -Color DarkYellow
        Write-Color "  .\Convert-Wem.ps1 -Path *.wem                 # wildcard" -Color DarkYellow
        Write-Color "  .\Convert-Wem.ps1 -Help                       # show help" -Color DarkYellow
        exit 1
    }
}

function Parse-BnkName {
    param([string]$Name)
    $stem = [System.IO.Path]::GetFileNameWithoutExtension($Name)
    $idx = $stem.LastIndexOf('_')
    if ($idx -le 0) { return @{ Base = $stem; Suffix = '' } }
    return @{ Base = $stem.Substring(0, $idx); Suffix = $stem.Substring($idx + 1) }
}

function Convert-SingleWem {
    param([string]$WemPath, [string]$OutputPath)
    $info = Get-WemFormatInfo $WemPath
    if (-not $info) { Write-Color "  [!] $(Split-Path $WemPath -Leaf) : Invalid WEM" -Color Red; return $false }
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($WemPath)
    Write-Color "  [>] $fileName : $($info.Codec) | $($info.Channels)ch | $($info.SampleRate)Hz | $('{0:N1}' -f ($info.FileSize/1KB))KB" -Color Cyan
    try {
        if ($info.FormatTag -ne 0xFFFF) {
            if ($info.FormatTag -eq 0x0001 -and $Format -eq "wav") {
                Copy-Item $WemPath -Destination $OutputPath -Force
                Write-Color "  [+] $fileName : Already WAV PCM" -Color Green
            } else {
                Convert-Audio -InputPath $WemPath -OutputPath $OutputPath
            }
        } else {
            if (-not $ww2ogg) { Write-Color "  [-] $fileName : SKIPPED - need ww2ogg" -Color Red; return $false }
            $tempOgg = Join-Path $env:TEMP "$fileName.temp.ogg"
            Convert-WemToOgg -WemPath $WemPath -OggPath $tempOgg -Ww2ogg $ww2ogg
            if ($Format -eq "ogg") {
                Move-Item $tempOgg -Destination $OutputPath -Force
            } else {
                Convert-Audio -InputPath $tempOgg -OutputPath $OutputPath
                if (-not $KeepOgg -and (Test-Path $tempOgg)) { Remove-Item $tempOgg -Force -ErrorAction SilentlyContinue }
            }
        }
        $size = (Get-Item $OutputPath).Length
        Write-Color "  [+] $fileName -> $('{0:N1}' -f ($size/1KB))KB | $Format" -Color Green
        return $true
    } catch { Write-Color "  [X] $fileName : $_" -Color Red; return $false }
}

# === Determine ww2ogg need ===
function Test-NeedsWw2ogg {
    param([string[]]$Files)
    foreach ($f in $Files) {
        $fi = Get-WemFormatInfo $f
        if ($fi -and $fi.FormatTag -eq 0xFFFF) { return $true }
    }
    return $false
}

$ww2ogg = $null
$needsWw2ogg = $false

# Check standalone WEMs
if ($files.Count -gt 0 -and (Test-NeedsWw2ogg $files)) { $needsWw2ogg = $true }

if ($needsWw2ogg) {
    $existing = Get-ToolPath "ww2ogg.exe"
    if ($existing -and (Test-Path "$(Get-ToolDir)\packed_codebooks_aoTuV_603.bin") -and -not $ForceDownload) {
        $ww2ogg = @{ Exe = $existing; Codebook = "$(Get-ToolDir)\packed_codebooks_aoTuV_603.bin" }
        Write-Color "[i] ww2ogg: $existing" -Color DarkYellow
    } else {
        Write-Color "[i] Need ww2ogg for Wwise Vorbis decoding" -Color DarkYellow
        $ww2ogg = Install-Ww2ogg
    }
}

Write-Color "==============================================" -Color Cyan
Write-Color "  Found $($files.Count) WEM + $($bnkFiles.Count) BNK file(s)" -Color Cyan
Write-Color "==============================================" -Color Cyan

$baseOutDir = if ($OutputDir) { $OutputDir } else { Join-Path (Get-Location).Path "convert" }
$totalCount = 0

# Process standalone .wem files
if ($files.Count -gt 0) {
    Write-Color "--- Standalone .wem files ---" -Color DarkYellow
    $ext = if ($Format -eq "mp3") { ".mp3" } else { ".$Format" }
    foreach ($f in $files) {
        $name = [System.IO.Path]::GetFileNameWithoutExtension($f)
        $outPath = Join-Path $baseOutDir "$name$ext"
        New-Item -ItemType Directory -Path (Split-Path $outPath -Parent) -Force | Out-Null
        if (Convert-SingleWem -WemPath $f -OutputPath $outPath) { $totalCount++ }
    }
}

# Process BNK files with organized output
if ($bnkFiles.Count -gt 0) {
    Write-Color "--- BNK files (organized output) ---" -Color DarkYellow
    $ext = if ($Format -eq "mp3") { ".mp3" } else { ".$Format" }
    foreach ($b in $bnkFiles) {
        $parsed = Parse-BnkName -Name (Split-Path $b -Leaf)
        $organizedDir = if ($parsed.Suffix) { Join-Path $baseOutDir $parsed.Base $parsed.Suffix } else { Join-Path $baseOutDir $parsed.Base }
        New-Item -ItemType Directory -Path $organizedDir -Force | Out-Null

        Write-Color "  [>] Extracting: $(Split-Path $b -Leaf) -> $($parsed.Base)\$($parsed.Suffix)" -Color Cyan
        $extracted = Extract-Bnk -BnkPath $b -OutputDir $organizedDir
        if ($extracted.Count -eq 0) { continue }

        $bnkCount = 0
        foreach ($w in $extracted) {
            $name = [System.IO.Path]::GetFileNameWithoutExtension($w)
            $outPath = Join-Path $organizedDir "$name$ext"
            if (Convert-SingleWem -WemPath $w -OutputPath $outPath) { $bnkCount++ }
            if (Test-Path $w) { Remove-Item $w -Force -ErrorAction SilentlyContinue }
        }
        Write-Color "  [+] Converted $bnkCount/$($extracted.Count) WEM(s) from $(Split-Path $b -Leaf)" -Color Green
        Write-Color "" -Color White
        $totalCount += $bnkCount
    }
}

Write-Color "==============================================" -Color Cyan
Write-Color "  Done! $totalCount file(s) processed." -Color Cyan
Write-Color "==============================================" -Color Cyan

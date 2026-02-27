# AV1 Media Converter

A Bun-based utility script to scan media libraries for legacy video codecs and convert them to modern AV1 format. This helps resolve transcoding issues in Jellyfin and reduces storage usage.

## Overview

The script targets several "legacy" codecs that often cause issues with modern hardware acceleration or player compatibility:
- `mpeg4` (Xvid, DivX)
- `msmpeg4v3`
- `mpeg2video` (DVD)
- `vc1` (Early Blu-ray)
- `theora`, `vp8`, `h263`, `flv1`

It uses `ffprobe` to identify codecs and `ffmpeg` with the `libsvtav1` encoder for high-quality AV1 compression.

## Prerequisites

- **Bun**: To run the script.
- **FFmpeg**: Must be compiled with `libsvtav1` support.
- **FFprobe**: For media analysis.

## Usage

Run the script using Bun from the root of the repository:

```bash
bun scripts/av1-converter.ts [options]
```

### Options

| Option | Alias | Description | Default |
|--------|-------|-------------|---------|
| `--dir` | `-d` | Directory to scan recursively | `.` |
| `--limit` | `-l` | Max number of files to convert | Infinity |
| `--dry-run` | | Scan and identify files without converting | `false` |
| `--preset` | | SVT-AV1 preset (0-13, lower is slower/better) | `6` |
| `--crf` | | SVT-AV1 quality (0-63, lower is higher quality) | `30` |
| `--upscale-to`| | Upscale video if height is below target (e.g., `720p`) | None |
| `--delete-original`| | Delete the original file after success | `false` |

### Examples

**Dry run to see what would be converted:**
```bash
bun scripts/av1-converter.ts --dir /path/to/movies --dry-run
```

**Upscale old movies to 720p:**
```bash
bun scripts/av1-converter.ts --dir /path/to/movies --upscale-to 720p
```

**Convert 2 files for testing:**
```bash
bun scripts/av1-converter.ts --dir /path/to/movies --limit 2 --preset 8
```

**Full conversion with cleanup:**
```bash
bun scripts/av1-converter.ts --dir /share/Storage/Movies --delete-original
```

## How it works

1.  **Scanning**: Uses `Bun.Glob` to recursively find common video extensions.
2.  **Analysis**: Runs `ffprobe` on each file to detect the video codec.
3.  **Encoding**: If a legacy codec is found, it triggers `ffmpeg` to:
    - Encode video to AV1 using `libsvtav1`.
    - Copy audio and subtitle streams (`-c:a copy -c:s copy`) to preserve quality and speed.
    - Output to a `.av1.mkv` file.
4.  **Verification**: Only if `ffmpeg` exits successfully, the script marks the conversion as complete.
5.  **Cleanup**: If `--delete-original` is set, it removes the old file and renames the new one to the original name (with `.mkv` extension).

## Troubleshooting

- **FFmpeg error code 171**: This script helps avoid this error by pre-converting files that would otherwise fail during real-time hardware transcoding in Jellyfin.
- **Speed**: AV1 encoding is CPU intensive. Adjust `--preset` (e.g., to `8` or `10`) for faster but slightly less efficient encoding.

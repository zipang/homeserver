# AV1 Converter Script

## Overview

This document describes the `av1-converter` script located at `scripts/av1-converter/src/index.ts`. This script is designed to re-encode legacy video formats into the modern AV1 codec, offering improved compression efficiency and quality. It provides options for scanning directories, limiting conversions, dry runs, adjusting encoding presets and quality (CRF), upscaling, and deleting original files.

## Command-line Options

The script uses `yargs` for command-line argument parsing. Below are the available options:

*   `-d`, `--dir <directory>`: Directory to scan for video files. Defaults to the current directory (`.`).
*   `-l`, `--limit <number>`: Limit the number of files to convert. Defaults to `Infinity`.
*   `--dry-run`: Scan and identify files without performing any conversion.
*   `--preset <preset_name>`: Encoding preset for SVT-AV1. Choices include: `ultrafast`, `superfast`, `veryfast`, `faster`, `fast`, `medium`, `slow`, `slower`, `veryslow`, `placebo`. Defaults to `medium`.
*   `--crf <number>`: SVT-AV1 Constant Rate Factor (CRF) for quality control. Value ranges from 0-63, where lower values indicate higher quality. Defaults to `24`.
*   `--delete-original`: Delete the original video file after a successful conversion. Defaults to `false`.
*   `--upscale-to <resolution>`: Upscale video if its height is below the target resolution (e.g., `720p`, `1080p`, `4K`).
*   `--apply-smoothing`: Apply a series of FFmpeg filters to reduce compression artifacts. This includes deblocking, denoising (hqdn3d), and debanding. Defaults to `false`.
*   `-v`, `--verbose`: Show full `ffmpeg` output and the command line used. Defaults to `false`.

## Example Usage

### Basic Conversion

To convert all supported video files in the current directory with default settings:

```bash
bun run scripts/av1-converter/src/index.ts
```

### Dry Run with Upscaling

To see which files would be converted and upscaled to 1080p without actually converting them:

```bash
bun run scripts/av1-converter/src/index.ts --dir ./videos --dry-run --upscale-to 1080p
```

### Conversion with Smoothing and Custom Quality

To convert files in a specific directory, apply smoothing filters, set a higher quality (lower CRF), and delete originals:

```bash
bun run scripts/av1-converter/src/index.ts --dir /mnt/media/movies --apply-smoothing --crf 20 --delete-original
```

### Verbose Output

To see the detailed `ffmpeg` command and output during conversion:

```bash
bun run scripts/av1-converter/src/index.ts -v
```

## Operational Guides

### Running the script

The script is a `bun` script. Ensure `bun` is installed and run the script as follows:

```bash
bun run scripts/av1-converter/src/index.ts [options]
```

### Understanding the Smoothing Filter (`--apply-smoothing`)

When the `--apply-smoothing` option is enabled, the script applies the following FFmpeg filter chain to reduce various compression artifacts:

```
deblock=filter=strong:block=8:alpha=0.1:beta=0.08:gamma=0.07:delta=0.06,hqdn3d=luma_spatial=4:chroma_spatial=3:luma_temporal=6:chroma_temporal=4,deband=range=16:threshold=32:dither=1
```

*   **`deblock`**: Reduces blocking artifacts often visible in highly compressed video.
*   **`hqdn3d`**: A high-quality 3D denoiser that minimizes general noise while striving to preserve video detail.
*   **`deband`**: Addresses banding artifacts, which appear as abrupt color changes in smooth gradients.

These filters are applied in sequence to optimize artifact reduction before any scaling operations.

## Troubleshooting

*   **`bun: command not found`**: Ensure `bun` is installed on your system. Refer to the official `bun` documentation for installation instructions.
*   **`ffmpeg: command not found`**: Ensure `ffmpeg` and `ffprobe` are installed and available in your system's PATH.
*   **Conversion Fails**: Check the output for `ffmpeg` errors, especially if `--verbose` is enabled. This can indicate issues with the input file, codec support, or insufficient system resources.
*   **Output Quality Issues**: Experiment with `--crf` values (lower is higher quality) and `preset` options. For smoothing, ensure `--apply-smoothing` is enabled.

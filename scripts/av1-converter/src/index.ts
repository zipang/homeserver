#!/usr/bin/env bun
import { Glob, $ } from 'bun';
import yargs from 'yargs';
import { hideBin } from 'yargs/helpers';
import chalk from 'chalk';
import { join, extname, basename, dirname } from 'path';
import { existsSync, renameSync, unlinkSync } from 'fs';

const TARGET_CODECS = [
  'mpeg4',
  'msmpeg4v3',
  'mpeg2video',
  'vc1',
  'theora',
  'vp8',
  'h263',
  'flv1',
];

const argv = await yargs(hideBin(process.argv))
  .option('dir', {
    alias: 'd',
    type: 'string',
    description: 'Directory to scan',
    default: '.',
  })
  .option('limit', {
    alias: 'l',
    type: 'number',
    description: 'Limit the number of files to convert',
    default: Infinity,
  })
  .option('dry-run', {
    type: 'boolean',
    description: 'Scan and identify files without converting',
    default: false,
  })
  .option('preset', {
    type: 'number',
    description: 'SVT-AV1 preset (0-13, lower is slower/better)',
    default: 6,
  })
  .option('crf', {
    type: 'number',
    description: 'SVT-AV1 CRF (0-63, lower is higher quality)',
    default: 30,
  })
  .option('delete-original', {
    type: 'boolean',
    description: 'Delete the original file after successful conversion',
    default: false,
  })
  .option('upscale-to', {
    type: 'string',
    description: 'Upscale video if height is below target (e.g., 720p, 1080p)',
  })
  .help()
  .argv;

async function getMediaInfo(filePath: string): Promise<{ codec: string, height: number } | null> {
  try {
    const result = await $`ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,height -of json ${filePath}`.json();
    const stream = result.streams[0];
    return {
      codec: stream.codec_name,
      height: stream.height,
    };
  } catch (e) {
    return null;
  }
}

function getTargetHeight(spec: string | undefined): number | null {
  if (!spec) return null;
  const match = spec.match(/(\d+)/);
  if (!match) return null;
  const val = parseInt(match[1]);
  if (spec.toLowerCase().includes('4k')) return 2160;
  return val;
}

async function convertFile(filePath: string, currentHeight: number): Promise<boolean> {
  const dir = dirname(filePath);
  const ext = extname(filePath);
  const base = basename(filePath, ext);
  const outputPath = join(dir, `${base}.av1.mkv`);

  console.log(chalk.blue(`\nConverting: ${basename(filePath)}`));
  
  const targetHeight = getTargetHeight(argv['upscale-to']);
  let vf = '';
  
  if (targetHeight && currentHeight < targetHeight) {
    console.log(chalk.yellow(`↑ Upscaling: ${currentHeight}p -> ${targetHeight}p`));
    vf = `-vf scale=-2:${targetHeight}:flags=lanczos`;
  } else {
    console.log(chalk.gray(`Height: ${currentHeight}p`));
  }

  console.log(chalk.gray(`Output: ${basename(outputPath)}`));

  try {
    // We use SVT-AV1 for encoding. 
    // -c:a copy preserves the audio streams to avoid re-encoding overhead.
    // -map 0 maps all streams (video, audio, subtitles).
    const ffmpegArgs = [
      '-i', filePath,
      '-map', '0',
      '-c:v', 'libsvtav1',
      '-preset', String(argv.preset),
      '-crf', String(argv.crf),
      ...(vf ? vf.split(' ') : []),
      '-c:a', 'copy',
      '-c:s', 'copy',
      outputPath,
      '-y'
    ];

    await $`ffmpeg ${ffmpegArgs}`.quiet();
    
    console.log(chalk.green(`✓ Successfully converted to AV1`));
    
    if (argv['delete-original']) {
      console.log(chalk.yellow(`! Deleting original: ${basename(filePath)}`));
      unlinkSync(filePath);
      const finalPath = join(dir, `${base}.mkv`);
      if (outputPath !== finalPath) {
        renameSync(outputPath, finalPath);
      }
    } else {
      console.log(chalk.yellow(`i Original file kept. New file at ${outputPath}`));
    }
    
    return true;
  } catch (e) {
    console.error(chalk.red(`✗ Failed to convert ${filePath}`));
    if (existsSync(outputPath)) {
      unlinkSync(outputPath);
    }
    return false;
  }
}

async function main() {
  const scanDir = argv.dir;
  const targetHeight = getTargetHeight(argv['upscale-to']);

  console.log(chalk.cyan(`\n--- SKYLAB Media Converter ---`));
  console.log(chalk.gray(`Scanning directory: ${scanDir}`));
  console.log(chalk.gray(`Targeting codecs: ${TARGET_CODECS.join(', ')}`));
  if (targetHeight) console.log(chalk.yellow(`Target Upscale: ${targetHeight}p`));
  if (argv['dry-run']) console.log(chalk.yellow(`Mode: DRY RUN (no files will be changed)`));
  if (argv.limit !== Infinity) console.log(chalk.gray(`Limit: ${argv.limit} files`));

  const glob = new Glob('**/*.{avi,mp4,mkv,wmv,flv,mpg,mpeg,mov,ts}');
  const files = Array.from(glob.scanSync(scanDir));
  
  console.log(chalk.gray(`Found ${files.length} potential media files.`));

  let processedCount = 0;
  let convertedCount = 0;

  for (const file of files) {
    if (convertedCount >= argv.limit) break;

    const fullPath = join(scanDir, file);
    const info = await getMediaInfo(fullPath);

    if (info && TARGET_CODECS.includes(info.codec)) {
      processedCount++;
      const upscaleNote = (targetHeight && info.height < targetHeight) ? chalk.yellow(' [UP] ') : ' ';
      console.log(chalk.yellow(`[${info.codec}]`) + upscaleNote + file);
      
      if (!argv['dry-run']) {
        const success = await convertFile(fullPath, info.height);
        if (success) convertedCount++;
      } else {
        convertedCount++;
      }
    }
  }

  console.log(chalk.cyan(`\n--- Summary ---`));
  console.log(chalk.gray(`Files scanned: ${files.length}`));
  console.log(chalk.gray(`Files matching target codecs: ${processedCount}`));
  if (!argv['dry-run']) {
    console.log(chalk.green(`Files successfully converted: ${convertedCount}`));
  } else {
    console.log(chalk.yellow(`Files that would be converted: ${convertedCount}`));
  }
}

main().catch(err => {
  console.error(chalk.red('\nAn unexpected error occurred:'));
  console.error(err);
  process.exit(1);
});

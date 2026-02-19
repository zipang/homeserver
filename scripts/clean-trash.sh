#!/usr/bin/env bash

# Recursively clean trash files from macOS and Windows systems.
# Useful when migrating files to a Linux system.

set -euo pipefail

usage() {
    echo "Usage: $(basename "$0") <directory> [--dry-run]"
    echo ""
    echo "Options:"
    echo "  --dry-run    Show what would be deleted without actually deleting"
    echo ""
    echo "Removes macOS and Windows metadata/thumbnail files:"
    echo "  macOS:  .DS_Store, ._* , .Spotlight-V100, .Trashes, .fseventsd"
    echo "  Windows: Thumbs.db, Desktop.ini, \$RECYCLE.BIN, System Volume Information"
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

TARGET_DIR="$1"
DRY_RUN=false

if [[ "${2:-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Error: '$TARGET_DIR' is not a directory"
    exit 1
fi

clean_files() {
    find "$TARGET_DIR" -type f \( \
        -name ".DS_Store" -o \
        -name "._*" -o \
        -name ".VolumeIcon.icns" -o \
        -name "Thumbs.db" -o \
        -name "Thumbs.db:encryptable" -o \
        -name "Desktop.ini" -o \
        -name "desktop.ini" -o \
        -name ".Icon" -o \
        -name ".LSOverride" \
    \) "$@" 2>/dev/null || true
}

clean_dirs() {
    find "$TARGET_DIR" -type d \( \
        -name ".Spotlight-V100" -o \
        -name ".Trashes" -o \
        -name ".fseventsd" -o \
        -name '$RECYCLE.BIN' -o \
        -name "System Volume Information" \
    \) "$@" 2>/dev/null || true
}

if $DRY_RUN; then
    echo "=== DRY RUN - Nothing will be deleted ==="
    echo ""
    echo "Files:"
    clean_files -print
    echo ""
    echo "Directories:"
    clean_dirs -print
    echo ""
    echo "=== End of dry run ==="
else
    echo "Cleaning trash files in '$TARGET_DIR'..."
    file_count=$(clean_files -print -delete | wc -l)
    dir_count=$(clean_dirs -exec rm -rf {} + -prune 2>/dev/null | wc -l)
    echo "Done. Deleted $file_count files and $dir_count directories."
fi

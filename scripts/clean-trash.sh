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

find_cmd=("find" "$TARGET_DIR")

patterns=(
    -name ".DS_Store"
    -o -name "._*"
    -o -name ".Spotlight-V100"
    -o -name ".Trashes"
    -o -name ".fseventsd"
    -o -name ".VolumeIcon.icns"
    -o -name "Thumbs.db"
    -o -name "Thumbs.db:encryptable"
    -o -name "Desktop.ini"
    -o -name "desktop.ini"
    -o -name "\$RECYCLE.BIN"
    -o -name "System Volume Information"
    -o -name ".Icon"
    -o -name ".LSOverride"
)

if $DRY_RUN; then
    echo "=== DRY RUN - Nothing will be deleted ==="
    echo ""
    "${find_cmd[@]}" "${patterns[@]}" -print 2>/dev/null || true
    echo ""
    echo "=== End of dry run ==="
else
    echo "Cleaning trash files in '$TARGET_DIR'..."
    deleted_count=$("${find_cmd[@]}" "${patterns[@]}" -print -delete 2>/dev/null | wc -l)
    echo "Done. Deleted $deleted_count items."
fi

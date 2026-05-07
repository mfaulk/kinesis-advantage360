#!/usr/bin/env bash
# Snapshot the Kinesis Adv360 v-Drive into a timestamped backup directory.
# Run this AFTER opening the v-Drive on the keyboard (SmartSet + v-Drive),
# and BEFORE flashing firmware so layouts/macros can be restored if needed.

set -euo pipefail

DEST_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
DEST="${DEST_ROOT}/vdrive-backup-${TIMESTAMP}"

find_mount() {
  # 1) Filesystem label = ADV360 (set by Kinesis firmware).
  local m
  m="$(findmnt -nr -S LABEL=ADV360 -o TARGET 2>/dev/null | head -n1 || true)"
  [[ -n "$m" ]] && { echo "$m"; return 0; }

  # 2) Common udisks2 auto-mount paths.
  for p in "/run/media/$USER/ADV360" "/media/$USER/ADV360" "/mnt/ADV360"; do
    [[ -d "$p" ]] && { echo "$p"; return 0; }
  done
  return 1
}

if ! SRC="$(find_mount)"; then
  cat >&2 <<EOF
ERROR: ADV360 v-Drive is not mounted.

  1. On the keyboard, press SmartSet + v-Drive (Hotkey 3 on the right module).
     The indicator LEDs will flash blue while the v-Drive is open.
  2. Wait for your file manager / udisks to auto-mount the ADV360 drive.
  3. Re-run this script.

If your system does not auto-mount removable drives, mount manually with:
  udisksctl mount -b /dev/disk/by-label/ADV360
EOF
  exit 1
fi

echo "Source : $SRC"
echo "Dest   : $DEST"
echo

mkdir -p "$DEST"

# Mirror the v-Drive. -a preserves attributes; --info=progress2 shows progress.
# Trailing slash on $SRC means "copy the contents of SRC into DEST".
rsync -a --info=progress2 --no-i-r "$SRC/" "$DEST/"

# Quick integrity check: every file in source should exist in dest with matching size.
diff_count="$(diff -rq "$SRC" "$DEST" 2>/dev/null | wc -l || true)"
if [[ "$diff_count" -ne 0 ]]; then
  echo
  echo "WARNING: diff -rq reports $diff_count discrepancies between source and backup."
  echo "Inspect with:  diff -rq '$SRC' '$DEST'"
  exit 2
fi

# Manifest with sha256s of every file copied, for future verification.
( cd "$DEST" && find . -type f ! -name SHA256SUMS -print0 \
    | xargs -0 sha256sum > SHA256SUMS )

echo
echo "Backup complete:"
echo "  $DEST"
echo "  $(find "$DEST" -type f | wc -l) files, $(du -sh "$DEST" | cut -f1) total"
echo
echo "Verify later with:  cd '$DEST' && sha256sum -c SHA256SUMS"

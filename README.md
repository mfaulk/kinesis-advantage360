# kinesis-debug

Working directory for debugging an intermittent left-half failure on a **Kinesis Advantage360 (wired)** keyboard, and for flashing its firmware.

## Contents

- [`DEBUG-LOG.md`](DEBUG-LOG.md) — running investigation log: hardware details, symptoms, kernel/USB evidence, and current hypotheses.
- [`FIRMWARE.md`](FIRMWARE.md) — distilled instructions for checking the firmware version and flashing `Adv360_1.0.79_update.upd` via SmartSet + v-Drive.
- [`backup-vdrive.sh`](backup-vdrive.sh) — backs up the mounted `ADV360` v-Drive to a timestamped folder with a `SHA256SUMS` manifest.
- `Adv360_1.0.79_update.upd` / `.zip` — Kinesis firmware 1.0.79 update payload.
- `Advantage360-SmartSet-Firmware-Update-Instructions.pdf` — original Kinesis instructions (source for `FIRMWARE.md`).
- `keyboard-diagram.png`, `default-layout.png` — labeled physical layout and stock per-key map, referenced from `FIRMWARE.md`.
- `vdrive-backup-YYYYMMDD-HHMMSS/` — backups produced by `backup-vdrive.sh`.

## Typical workflow

1. Read `DEBUG-LOG.md` for current state of the investigation.
2. To flash firmware, follow `FIRMWARE.md` (open v-Drive → run `./backup-vdrive.sh` → copy `.upd` → close v-Drive → install).

# Kinesis Advantage360 Debug Log

Running log of investigation into intermittent left-half failure.

## Hardware

- Kinesis Advantage360 **wired** (KB360 / SmartSet engine, **not** Pro)
- USB ID: `29ea:0360`
- Connection: USB cable directly to computer (no hub/dock)
- Two halves connected by inter-half TRRS cable
- Right half = USB master; left half talks to right over TRRS
- Firmware: stock (never updated by user)

Host: Fedora 43, kernel 6.19.11.

## Symptom

- Several times a day, the **left half** becomes fully unresponsive.
- Right half continues to work normally.
- Failure is **all at once** (entire left half dies in one moment, not progressive key-by-key or column-by-column).
- **No observed pattern**: not tied to sleep/resume, time of day, typing intensity, or motion.
- Recovery: unplugging and re-plugging the USB cable restores the left half.

## Evidence — 2026-05-07

### Kernel log (`journalctl --since "24 hours ago"`)

The Adv360 fully re-enumerated 4 times in the prior 24 hours:

- 2026-05-06 11:57:07
- 2026-05-06 21:40:50
- 2026-05-06 23:10:25
- 2026-05-07 11:21:38

These match the user's "several times a day" description and correspond to the
recovery replugs.

**Key negative finding:** there are **no USB errors preceding any of these
re-enumerations** — no `device descriptor read` errors, no port resets, no link
issues. The host sees a healthy USB device the entire time, then a clean
disconnect/reconnect when the user replugs.

This means the failure is **not on the USB-host side**. From the kernel's
perspective the right half (USB master) is fine throughout. The left half is
silently disappearing from the keyboard's *internal* point of view.

## Working hypotheses

In rough order of likelihood:

1. **Inter-half TRRS cable / jack** — partial contact, lint, strain at the
   connector, or marginal solder on the jack. TRRS is a known weak point on
   split keyboards.
2. **Left-half MCU firmware lockup** — left-half microcontroller hangs and
   stops sending events until a full power-cycle clears it. Stock (unupdated)
   firmware is plausibly old; Kinesis has shipped multiple firmware revisions.
3. **Marginal power delivery to the left half** over the inter-half cable
   causing a brownout.

The "all at once" symptom rules out progressive matrix wear. The "direct USB"
connection rules out hub power problems. The host-side log silence rules out
USB-bus issues.

## Diagnostic plan

### Test 1 — TRRS reseat (do at next failure, BEFORE replugging USB)

When the left half next dies:

1. Without unplugging USB, gently reseat the TRRS cable at both ends.
2. If that restores the left half -> inter-half cable/jack confirmed.
3. If reseating doesn't help, fully unplug and replug the TRRS cable (USB
   still connected).
4. If neither works and only USB-replug recovers it -> left-half MCU hard hang
   (firmware).

### Test 2 — TRRS cable swap

If a spare 4-conductor TRRS cable is available, swap it in for several days.
Failure stopping = cable; failure continuing = jack or firmware.

### Test 3 — TRRS jiggle test

While keyboard works, gently flex the TRRS cable near each connector. If left
half cuts out -> cable end or solder joint at jack.

### Test 4 — Live host capture

Leave running in a terminal:
```
sudo journalctl -fk | grep --line-buffered -i -E 'usb|hid|0360|29ea'
```
Note wall-clock time when next failure occurs. Silence in the log until the
replug confirms host sees nothing during the failure (host-side ruled out
permanently).

### Test 5 — Firmware update

Update from stock to v1.0.79 (2025-08-05). See `FIRMWARE.md`.

Before flashing: capture current firmware version via Status Report
(**SmartSet + Right Shift + Right Ctrl + ?** — SmartSet is the gear-shaped
button on the **right module**, top-left, next to the **6** key; see
`keyboard-diagram.png`) and record it below so we know what we were on if the
issue persists.

If v1.0.79 fixes it -> firmware bug. If it doesn't -> hardware (cable/jack),
escalate to Kinesis warranty (`tech@kinesis.com`, 2-year warranty).

## Baseline — pre-update firmware (2026-05-07)

Status Report output:

```
Advantage 360 US
Profile 1
Remaps 30
Macros 0
NKRO Off
L Firmware 1.0.69
R Firmware 1.0.69
Bootloader 1.3
www.kinesis.com/support/kb360
```

- Both halves on **1.0.69**; latest is **1.0.79** (2025-08-05) — 10 minor
  versions behind.
- Left half *is* communicating at the time of capture (it reported its
  version), confirming the failure is intermittent rather than permanent and
  the keyboard is in a flashable state right now.
- 30 user remaps in Profile 1 (worth backing up the v-Drive contents before
  flashing in case settings reset).

## Post-update firmware (2026-05-07)

Status Report output after flashing:

```
Advantage 360 US
Profile 1
Remaps 30
Macros 0
NKRO Off
L Firmware 1.0.79
R Firmware 1.0.79
Bootloader 1.3
www.kinesis.com/support/kb360
```

- Both halves now on **1.0.79** (was 1.0.69). Bootloader unchanged at 1.3.
- 30 remaps preserved across the flash; profile/macros/NKRO unchanged.

## Flash-process observation — v-Drive close hung the keyboard (2026-05-07)

Reproducible behavior seen during the flash, worth flagging because it
overlaps the bug under investigation.

**Sequence:**

1. Copy `Adv360_1.0.79_update.upd` into v-Drive `firmware/`.
2. Eject the `ADV360` drive from the OS (`udisksctl unmount` / file
   manager).
3. Press **SmartSet + v-Drive** to close the v-Drive.
4. LEDs blink green ~2× (expected: 4×).
5. **Right-half LEDs stay solid green; left-half LEDs go dark.**
6. Both halves are completely unresponsive — no key input registers.
7. Recovery: unplug + replug the USB cable. Keyboard returns to normal.

This was reproduced **twice** in a row (mounted v-Drive again, ejected,
SmartSet + v-Drive — same hang). On the second recovery, instead of
reopening v-Drive we ran **SmartSet + Right Ctrl + U** and the firmware
install proceeded normally, completing the flash to 1.0.79.

**Notes for the investigation:**

- This is a **different failure mode** from the daily bug (here *both*
  halves go unresponsive; normally only the left half dies). But the
  recovery — full USB unplug/replug — is identical, and the right half
  *also* stops responding here, which suggests the keyboard's MCU(s) can
  enter a hung state that only a power-cycle clears.
- It happened specifically on the v-Drive close transition. Could be a
  firmware bug in 1.0.69's v-Drive handling, a timing issue with the
  OS-side eject, or something specific to ejecting before pressing the
  hotkey. The Kinesis instructions say to eject first, so we followed
  the documented order.
- Worth re-testing on **1.0.79** to see if the v-Drive close still hangs
  the keyboard. If 1.0.79 also hangs, file with Kinesis. If it doesn't,
  this was a 1.0.69 bug that's now fixed.

## Actions taken

| Date       | Action                                                     |
|------------|------------------------------------------------------------|
| 2026-05-07 | Captured 24h of journalctl, identified 4 re-enumerations.  |
| 2026-05-07 | Downloaded firmware v1.0.79 + official install PDF.        |
| 2026-05-07 | Extracted `Adv360_1.0.79_update.upd` from zip.             |
| 2026-05-07 | Recorded baseline firmware: L 1.0.69 / R 1.0.69, BL 1.3.   |
| 2026-05-07 | Backed up v-Drive (`vdrive-backup-20260507-180243/`).      |
| 2026-05-07 | Copied `Adv360_1.0.79_update.upd` to v-Drive `firmware/`.  |
| 2026-05-07 | Flashed firmware v1.0.79; both halves report 1.0.79.       |
| 2026-05-07 | Observed v-Drive-close hang on 1.0.69 (both halves unresponsive, USB replug to recover). |

## Open questions / TODO

- [x] Record current (pre-update) firmware version via Status Report. (1.0.69)
- [x] Back up v-Drive contents (`vdrive-backup-20260507-180243/`).
- [x] Apply firmware v1.0.79. (Both halves on 1.0.79 confirmed via Status Report.)
- [ ] Run Test 1 (TRRS reseat) at next left-half failure.
- [ ] After update, observe for a week. Note timestamps of any further failures.
- [ ] Re-test v-Drive close on 1.0.79 — does it still hang both halves? (See "Flash-process observation" above.)

## Files in this directory

| File                                                       | Purpose                              |
|------------------------------------------------------------|--------------------------------------|
| `Adv360_1.0.79_update.zip`                                 | Firmware payload (zipped)            |
| `Adv360_1.0.79_update.upd`                                 | Extracted firmware (copy this to v-Drive `firmware/`) |
| `Advantage360-SmartSet-Firmware-Update-Instructions.pdf`   | Kinesis official install instructions |
| `keyboard-diagram.png`                                     | Labeled physical-keyboard photo (SmartSet, Hotkeys, etc.) — page 7 of KB360 manual |
| `default-layout.png`                                       | Per-key character map for Base / Fn / Keypad layers — page 14 of KB360 manual |
| `FIRMWARE.md`                                              | Distilled check + flash steps        |
| `backup-vdrive.sh`                                         | Snapshots the v-Drive into a timestamped backup with SHA256SUMS manifest |
| `DEBUG-LOG.md`                                             | This file                            |

### File checksums

```
sha256  45af6e22fa38e8ee67bc079626099b1e7a7cb20aaaf47b8f95301b5a6c49b9db  Adv360_1.0.79_update.zip
sha256  d7873c838f808f3783883f9e1e5619e5edb1c9886111c0f29bf2bf10f7dfced8  Adv360_1.0.79_update.upd
sha256  813ae18801f8bf2f848c4a9972770b55194e7d40f81c02aaf362c50f524b6f07  Advantage360-SmartSet-Firmware-Update-Instructions.pdf
sha256  df773d8a1e1bffff5f8f90751944aa30c0e30fe1678127807813124c3f06f44b  keyboard-diagram.png
sha256  4c8478bfc12cd211e538edfbfd6859e29cf8ff844bf00fe40ca881efa5204e8f  default-layout.png
```

### Sources

- Adv360 wired support: https://kinesis-ergo.com/support/kb360/
- Firmware download (v1.0.79): https://kinesis-ergo.com/download/advantage360-smartset-firmware-v1-0-79/
- Install instructions PDF: https://kinesis-ergo.com/wp-content/uploads/Advantage360-SmartSet-Firmware-Update-Instructions-9.5.24-KB360.pdf

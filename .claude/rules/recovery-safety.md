# Recovery safety rules

1. **No device writes from automation.** Never run `fastboot flash|erase|format|boot|reboot|update|oem|flashing`, `adb reboot`, `adb shell dd/mkfs/wipe`, or anything that changes a phone, unless the owner has approved that exact command in this conversation. `tests/build/static_checks.sh` fails if these appear in `scripts/`, `device/` or `tests/`.
2. **Read-only probing only.** `getprop`, `ls`, `cat`, `fastboot getvar` are allowed (and only with the user's go-ahead to touch the phone).
3. **Never-wipe partitions:** `persist`, `modemst1`, `modemst2`, `fsc`, `fsg`, `modem`, `bluetooth`, `dsp`. They may be backed up, never wiped or formatted from the UI.
4. **Format Data** must need typed confirmation (TWRP's `yes` keyboard input), never a single tap. Wipe/restore/flash need a swipe or confirm dialog that names the target partition.
5. **Image flashing** is only allowed to partitions in the fstab that have `flashimg=1`. No free-form partition targets.
6. **Testing:** temporary boot (`fastboot boot`) before any `fastboot flash recovery`. Destructive tests only with disposable data and a backup copied off the phone.
7. **Release labels:** EXPERIMENTAL until Stage 4 and 5 results are recorded in `docs/TEST_REPORT.md`.

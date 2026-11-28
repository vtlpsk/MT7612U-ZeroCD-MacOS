# MT7612U ZeroCD (macOS)

A lightweight, native macOS background daemon for automatic ZeroCD mode switching on MediaTek MT7612U USB Wi-Fi dongles.

## Overview

Many USB Wi-Fi dongles based on the **MediaTek MT7612U** chipset (e.g., Comfast CF-926AC and OEM clones) use **ZeroCD technology**: on first connect they present as a USB Mass Storage device (virtual CD-ROM) with Windows drivers instead of a wireless adapter:

- **ZeroCD state:** `VID: 0x0E8D`, `PID: 0x2870` (`lsusb`: `ID 0e8d:2870 MediaTek Inc. Љ`)
- **Wireless state:** `VID: 0x0E8D`, `PID: 0x7612`

While the adapter is in ZeroCD mode, macOS sees a virtual CD-ROM. The utility uses macOS APIs to block mounting and request ejection so the adapter can reappear in Wi-Fi mode.

## How It Works

macOS has no built-in ZeroCD switching tool like Linux `usb_modeswitch`. This project uses:

1. **Mount Suppression (`DiskArbitration`)** — rejects the volume mount request so the virtual CD-ROM never appears in Finder.
2. **Hardware Identification (`IOKit`)** — inspects USB descriptors and targets only `0x0E8D:0x2870`; all other disks are left untouched.
3. **Automated Eject** — requests ejection for the whole virtual disk via `DADiskEject()`. If that fails and the original disk is still present, it tries `diskutil eject`.
4. **USB Verification** — after the eject attempt, the utility waits up to 10 seconds for `0x0E8D:0x7612` at the same USB location. It logs whether it could confirm the switch.

## Requirements

- **macOS:** 11 (Big Sur) or newer
- **Architecture:** Apple Silicon (arm64) verified; Intel (x86_64) untested
- **Tooling:** Xcode Command Line Tools (`xcode-select --install`) for `swiftc`
- **Hardware:** MediaTek MT7612U USB Wi-Fi adapter

> **Note:** This utility performs only the hardware mode-switch. macOS ships no driver for MT7612U, so the dongle will not work as a Wi-Fi adapter on the macOS host itself. The typical use case is USB-passthrough to a virtual machine (e.g., Kali Linux for penetration testing) that provides its own driver.

---

## Installation

```bash
git clone https://github.com/vtlpsk/MT7612U-ZeroCD-MacOS.git
cd MT7612U-ZeroCD-MacOS
./scripts/install.sh
```

Run the installer from your logged-in macOS desktop account. It compiles the daemon, uses `sudo` to install the binary in `/usr/local/bin`, and registers a LaunchAgent for your account. Run the same script to update an existing installation.

Then plug in the dongle. The daemon requests ejection when macOS reports the whole virtual disk.

> If macOS shows *"The disk you attached was not readable by this computer."*, click **Ignore**. The dialog can appear during disk detection. Check the log for USB switch confirmation.

<details>
<summary><strong>Manual build (without installing the service)</strong></summary>

The daemon is a single-file Swift program and can be compiled directly:

```bash
mkdir -p bin
swiftc -O Sources/main.swift -o bin/zerocd-daemon
./bin/zerocd-daemon   # run in foreground (Ctrl+C to stop)
```
</details>


---

## Monitoring & Logs

You can monitor daemon activity and switching events in real time:

```bash
tail -F "$HOME/Library/Logs/MT7612U-ZeroCD/zerocd-daemon.log"
```

**Example output:**
```text
[2026-11-28T14:28:17Z] ZeroCD daemon started. Watching for 0e8d:2870.
[2026-11-28T14:28:22Z] /dev/disk4: detected ZeroCD (0e8d:2870), requesting eject.
[2026-11-28T14:28:23Z] /dev/disk4: Disk Arbitration ejected the virtual disk.
[2026-11-28T14:28:24Z] /dev/disk4: Wi-Fi mode confirmed (0e8d:7612).
```

---

## Uninstallation

To remove the daemon and LaunchAgent from your system:

```bash
./scripts/uninstall.sh
```

The script stops and removes the LaunchAgent and deletes `/usr/local/bin/zerocd-daemon`. Build artifacts in `bin/` and logs in `~/Library/Logs/MT7612U-ZeroCD` remain available for troubleshooting.

---

## Project Structure

```text
MT7612U-ZeroCD-MacOS/
├── Sources/
│   └── main.swift
├── scripts/
│   ├── install.sh
│   ├── launch-agent.sh
│   └── uninstall.sh
├── com.user.zerocd-daemon.plist
├── .gitignore
├── LICENSE
└── README.md
```

> `bin/zerocd-daemon` is a **build artifact** produced automatically by `./scripts/install.sh` — it is intentionally excluded via `.gitignore` and never committed to the repository, so it will **not** be present after `git clone`.

---

## License

This project is open-source and available under the [MIT License](LICENSE).

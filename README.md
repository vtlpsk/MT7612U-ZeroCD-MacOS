# MT7612U ZeroCD (macOS)

A lightweight, native macOS background daemon for automatic ZeroCD mode switching on MediaTek MT7612U USB Wi-Fi dongles.

## Overview

Many USB Wi-Fi dongles based on the **MediaTek MT7612U** chipset (e.g., Comfast CF-926AC and OEM clones) use **ZeroCD technology**: on first connect they present as a USB Mass Storage device (virtual CD-ROM) with Windows drivers instead of a wireless adapter:

- **ZeroCD state:** `VID: 0x0E8D`, `PID: 0x2870` (`lsusb`: `ID 0e8d:2870 MediaTek Inc. Љ`)
- **Wireless state:** `VID: 0x0E8D`, `PID: 0x7612`

Without this utility, macOS mounts the virtual CD-ROM as a driver installer image and blocks Wi-Fi drivers from binding to the hardware. The daemon intercepts the device via native Apple APIs, suppresses the mount, and issues a SCSI eject so the dongle re-enumerates as a Wi-Fi adapter.

## How It Works

macOS has no built-in ZeroCD switching tool like Linux `usb_modeswitch`. This project uses:

1. **Mount Suppression (`DiskArbitration`)** — rejects the volume mount request so the virtual CD-ROM never appears in Finder.
2. **Hardware Identification (`IOKit`)** — inspects USB descriptors and targets only `0x0E8D:0x2870`; all other disks are left untouched.
3. **Automated Eject** — sends `DADiskEject()` (with `diskutil eject` fallback) to force the dongle into Wi-Fi mode (`0x0E8D:0x7612`).

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

The installer compiles the daemon, copies it to `/usr/local/bin/zerocd-daemon`, and registers a persistent LaunchAgent at `~/Library/LaunchAgents/com.user.zerocd-daemon.plist`. It requires `sudo` to write to `/usr/local/bin`.

> **Note:** the installer needs administrator rights to copy the binary into `/usr/local/bin`, so it will prompt you for your password (`sudo`). Without it the script stops with an error.

Then plug in the dongle — it switches to Wi-Fi mode automatically.

> **Important:** Shortly after connecting, macOS may show a system dialog *"The disk you attached was not readable by this computer."* — click **Ignore** — do **not** click *Eject*. The daemon handles the eject automatically.

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
tail -f /tmp/zerocd-daemon.log
```

**Example output:**
```text
[14:28:17] Daemon started.
[14:28:17] Filtering strictly for MediaTek MT7612U (VID: 0x0E8D, PID: 0x2870)...
[14:28:22] Intercepted mount request for MT7612U on /dev/disk4. Suppressing mount...
[14:28:22] Detected MediaTek MT7612U Wireless Dongle (ZeroCD Mode) on /dev/disk4 [0x0e8d:0x2870]
[14:28:22] Sending EJECT request to switch device to Wi-Fi mode [0x0e8d:0x7612]...
[14:28:23] Successfully ejected /dev/disk4! MT7612U is switching to Wi-Fi mode.
```

---

## Uninstallation

To remove the daemon and LaunchAgent from your system:

```bash
./scripts/uninstall.sh
```

The script unloads and deletes the `LaunchAgent` and removes `/usr/local/bin/zerocd-daemon`. Build artifacts in `bin/` and the logs in `/tmp/zerocd-daemon.*` are left in place — delete them manually if you want a fully clean state.

---

## Project Structure

```text
MT7612U-ZeroCD-MacOS/
├── Sources/
│   └── main.swift
├── scripts/
│   ├── install.sh
│   └── uninstall.sh
├── com.user.zerocd-daemon.plist
├── .gitignore
├── LICENSE
└── README.md

> `bin/zerocd-daemon` is a **build artifact** produced automatically by `./scripts/install.sh` — it is intentionally excluded via `.gitignore` and never committed to the repository, so it will **not** be present after `git clone`.

---

## License

This project is open-source and available under the [MIT License](LICENSE).

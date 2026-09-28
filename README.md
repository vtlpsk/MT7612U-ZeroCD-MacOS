<p align="center">
  <h1 align="center">MT7612U ZeroCD (macOS)</h1>
  <p align="center">
    <strong>A lightweight, native macOS background daemon for automatic ZeroCD mode switching on MediaTek MT7612U USB Wi-Fi dongles.</strong>
  </p>
</p>

---

## 📌 Overview

Many USB Wi-Fi dongles based on the **MediaTek MT7612U** chipset (such as the *Comfast CF-926AC* and various OEM adapters) feature **ZeroCD technology**. Upon first connection, they report to the operating system as a USB Mass Storage device (virtual CD-ROM) containing Windows drivers, rather than initializing as a wireless network adapter:

- **ZeroCD Initial State (Storage / CD-ROM):** `VID: 0x0E8D`, `PID: 0x2870` (typically identified in USB tools as `0e8d:2870 MediaTek Inc. Љ`)
- **Target Wireless State (802.11ac Wi-Fi):** `VID: 0x0E8D`, `PID: 0x7612` (`802.11ac WLAN`)

Without this utility, the adapter gets stuck in CD-ROM mode and identifies as:
```text
ID 0e8d:2870 MediaTek Inc. Љ
```
On macOS, this causes an unwanted driver installer disk image to mount on your desktop while preventing Wi-Fi drivers from binding to the device. 

**MT7612U ZeroCD** solves this transparently in the background by intercepting the device via native Apple APIs and triggering an immediate SCSI eject, instantly shifting the hardware into its native Wi-Fi mode.

---

## ⚡ How It Works

Unlike Linux, which commonly relies on `usb_modeswitch`, macOS lacks an out-of-the-box ZeroCD switching tool. This project implements a native Swift background daemon leveraging Apple's low-level system frameworks:

1. **Mount Suppression (`DiskArbitration`):** Intercepts the volume mount request (`DARegisterDiskMountApprovalCallback`) and rejects it via `DADissenter`, preventing the virtual CD-ROM from flashing in Finder or mounting on the desktop.
2. **Hardware Identification (`IOKit`):** Traverses the I/O Registry to inspect the parent USB device descriptors, ensuring only exact matching hardware (`0x0E8D:0x2870`) is handled. All other flash drives and external disks are untouched.
3. **Automated Eject:** Issues a non-blocking `DADiskEject()` call (with fallback to `diskutil eject`). The adapter acknowledges the standard SCSI eject command and re-enumerates on the USB bus as a Wi-Fi device (`0x0E8D:0x7612`).

---

## 📋 Requirements

- **macOS:** macOS 11 (Big Sur) or newer (tested up to macOS 15 / Sequoia).
- **Architecture:** Apple Silicon (M1/M2/M3/M4) & Intel (x86_64).
- **Tooling:** Command Line Tools (`xcode-select --install` or Xcode) with `swiftc` installed.
- **Hardware:** MediaTek MT7612U USB Wi-Fi adapter.

> **Note:** This utility handles the **hardware mode-switch** into Wi-Fi mode. You will still need appropriate macOS wireless drivers/extensions installed for the MT7612U chipset to connect to networks.

---

## 🚀 Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/MT7612U-ZeroCD-MacOS.git
   cd MT7612U-ZeroCD-MacOS
   ```

2. **Run the installation script:**
   ```bash
   ./scripts/install.sh
   ```

The script will:
- Compile the Swift daemon into an optimized native binary.
- Install the binary to `/usr/local/bin/zerocd-daemon`.
- Register and load a persistent `LaunchAgent` (`~/Library/LaunchAgents/com.user.zerocd-daemon.plist`) that runs automatically at user login.

3. **Plug in your MT7612U USB dongle.** It will now seamlessly switch directly to Wi-Fi mode upon connection.

---

## 🔍 Monitoring & Logs

You can monitor daemon activity and switching events in real time:

```bash
tail -f /tmp/zerocd-daemon.log
```

**Example output:**
```text
[14:28:17] 🚀 ZeroCD Daemon started.
[14:28:17] Filtering strictly for MediaTek MT7612U (VID: 0x0E8D, PID: 0x2870)...
[14:28:22] Intercepted mount request for MT7612U on /dev/disk4. Suppressing mount...
[14:28:22] Detected MediaTek MT7612U Wireless Dongle (ZeroCD Mode) on /dev/disk4 [0x0e8d:0x2870]
[14:28:22] Sending EJECT request to switch device to Wi-Fi mode [0x0e8d:0x7612]...
[14:28:23] ✅ Successfully ejected /dev/disk4! MT7612U is switching to Wi-Fi mode.
```

---

## 🗑️ Uninstallation

To cleanly remove the daemon and LaunchAgent from your system:

```bash
./scripts/uninstall.sh
```

---

## 📂 Project Structure

```text
MT7612U-ZeroCD-MacOS/
├── Sources/
│   └── main.swift                # Core daemon logic (DiskArbitration & IOKit)
├── scripts/
│   ├── install.sh                # Build & LaunchAgent registration script
│   └── uninstall.sh              # Service uninstaller script
├── com.user.zerocd-daemon.plist  # launchd agent definition
└── README.md                     # Project documentation
```

---

## 📄 License

This project is open-source and available under the [MIT License](LICENSE).

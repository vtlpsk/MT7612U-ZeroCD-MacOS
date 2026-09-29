<div align="center">
  <h1 align="center">MT7612U ZeroCD (macOS)</h1>
  <p align="center">
    <strong>A lightweight, native macOS background daemon for automatic ZeroCD mode switching on MediaTek MT7612U USB Wi-Fi dongles.</strong>
  </p>
</div>

---

## 📌 Overview

Many USB Wi-Fi dongles based on the **MediaTek MT7612U** chipset (such as the *Comfast CF-926AC* and various OEM adapters) feature **ZeroCD technology**. Upon first connection, they report to the operating system as a USB Mass Storage device (virtual CD-ROM) containing Windows drivers, rather than initializing as a wireless network adapter:

- **ZeroCD Initial State (Storage / CD-ROM):** `VID: 0x0E8D`, `PID: 0x2870`
- **Target Wireless State (802.11ac Wi-Fi):** `VID: 0x0E8D`, `PID: 0x7612` (product string `802.11ac WLAN`)

Without this utility, the adapter gets stuck in CD-ROM mode. Linux `lsusb` reports it as:

```text
ID 0e8d:2870 MediaTek Inc. Љ
```

The trailing `Љ` is a garbled raw string emitted by the dongle firmware, not a real device name. On macOS you can confirm the IDs with `system_profiler SPUSBDataType` → `Vendor ID 0xe8d`, `Product ID 0x2870`.

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

- **macOS:** macOS 11 (Big Sur) or newer — **verified on macOS 27.0.1**.
- **Architecture:** Apple Silicon (arm64) — verified. Intel (x86_64) builds are expected to work but are **untested**.
- **Tooling:** Command Line Tools (`xcode-select --install`) or Xcode, which provide `swiftc`.
- **Hardware:** MediaTek MT7612U USB Wi-Fi adapter.

> **Note:** This utility only handles the **hardware mode-switch** into Wi-Fi mode. macOS ships no driver for the MT7612U chipset, so out of the box the dongle will not work as a regular Wi-Fi adapter on the macOS host. The typical use case is passing the switched adapter through to a **virtual machine** (e.g., a Linux guest such as Kali for pentesting) that provides its own driver.

---

## 🚀 Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/vtlpsk/MT7612U-ZeroCD-MacOS.git
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

> **Note:** the installer needs administrator rights to copy the binary into `/usr/local/bin`, so it will prompt you for your password (`sudo`). Without it the script stops with an error.

3. **Plug in your MT7612U USB dongle.** It will now seamlessly switch directly to Wi-Fi mode upon connection.

<details>
<summary><strong>Manual build (without installing the service)</strong></summary>

The daemon is a single-file Swift program and can be compiled directly. Note that `bin/` is a generated directory — it is created by the build step and excluded from version control via `.gitignore`.

```bash
mkdir -p bin
swiftc -O Sources/main.swift -o bin/zerocd-daemon
./bin/zerocd-daemon   # run in foreground (Ctrl+C to stop)
```
</details>


---

## 🔍 Monitoring & Logs

You can monitor daemon activity and switching events in real time:

```bash
tail -f /tmp/zerocd-daemon.log
```

**Example output:**
```text
[14:28:17] 🚀 Daemon started.
[14:28:17] Filtering strictly for MediaTek MT7612U (VID: 0x0E8D, PID: 0x2870)...
[14:28:22] Intercepted mount request for MT7612U on /dev/disk4. Suppressing mount...
[14:28:22] Detected MediaTek MT7612U Wireless Dongle (ZeroCD Mode) on /dev/disk4 [0x0e8d:0x2870]
[14:28:22] Sending EJECT request to switch device to Wi-Fi mode [0x0e8d:0x7612]...
[14:28:23] ✅ Successfully ejected /dev/disk4! MT7612U is switching to Wi-Fi mode.
```

---

## 🗑️ Uninstallation

To remove the daemon and LaunchAgent from your system:

```bash
./scripts/uninstall.sh
```

The script unloads and deletes the `LaunchAgent` and removes `/usr/local/bin/zerocd-daemon`. Build artifacts in `bin/` and the logs in `/tmp/zerocd-daemon.*` are left in place — delete them manually if you want a fully clean state.

---

## 📂 Project Structure

```text
MT7612U-ZeroCD-MacOS/             # this repository
├── Sources/
│   └── main.swift                # Core daemon logic (DiskArbitration & IOKit)
├── scripts/
│   ├── install.sh                # Build & LaunchAgent registration script
│   └── uninstall.sh              # Service uninstaller script
├── com.user.zerocd-daemon.plist  # launchd agent definition
├── .gitignore                    # Excludes build artifacts from version control
├── LICENSE                       # MIT License
└── README.md                     # Project documentation

# Local only — created by ./scripts/install.sh, never committed:
bin/
└── zerocd-daemon                 # Compiled arm64 binary
```

> `bin/zerocd-daemon` is a **build artifact** produced automatically by `./scripts/install.sh` — it is intentionally excluded via `.gitignore` and never committed to the repository, so it will **not** be present after `git clone`.

---

## 📄 License

This project is open-source and available under the [MIT License](LICENSE).

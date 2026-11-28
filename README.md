# MT7612U ZeroCD (macOS)

A lightweight, native macOS background daemon for automatic ZeroCD mode switching on MediaTek MT7612U USB Wi-Fi dongles.

## Overview

Some USB Wi-Fi adapters based on the **MediaTek MT7612U** chipset first appear as a virtual CD-ROM with Windows drivers. This utility targets adapters with these USB IDs.

- **ZeroCD mode** — `0e8d:2870`
- **Wi-Fi mode** — `0e8d:7612`

## Switching modes on macOS

If connecting the adapter opens the dialog *"The disk you attached was not readable by this computer."*, choose one of these options.

- **Eject** requests ejection of the virtual driver disk. This can switch the adapter to Wi-Fi mode manually.
- **Ignore** dismisses the dialog. If the daemon is running, it can still request ejection automatically.

To check the result independently of the daemon, run `ioreg -p IOUSB -l -w 0` in Terminal and look for the adapter. The USB vendor ID is `0x0e8d` (`3725` in decimal). A product ID of `0x7612` (`30226`) confirms Wi-Fi mode. A product ID of `0x2870` (`10352`) means the adapter is still in ZeroCD mode.

## How It Works

1. The daemon uses IOKit to match USB ID `0e8d:2870` and Disk Arbitration to decline mount requests for the matching virtual disk.
2. When macOS reports the whole virtual disk, the daemon requests ejection via `DADiskEject()`. If that fails and the original disk is still present, it tries `diskutil eject`.
3. After the eject attempt, the daemon waits up to 10 seconds for `0e8d:7612` at the same USB location and logs the result. macOS may take additional time to detect the virtual disk before the daemon requests ejection.

## Requirements

- **macOS:** 11 (Big Sur) or newer
- **Architecture:** Built for Apple Silicon and Intel. Startup tested on Apple Silicon.
- **Tooling:** Xcode Command Line Tools (`xcode-select --install`) for `swiftc`
- **Hardware:** MediaTek MT7612U USB Wi-Fi adapter

The utility switches the adapter's hardware mode. Networking requires an MT7612U driver. One option is to pass the adapter through to a Linux virtual machine with a compatible driver.

---

## Installation

```bash
git clone https://github.com/vtlpsk/MT7612U-ZeroCD-MacOS.git
cd MT7612U-ZeroCD-MacOS
./scripts/install.sh
```

Run the installer from your logged-in macOS desktop account. The script compiles the daemon, uses `sudo` to install the binary in `/usr/local/bin`, and registers a LaunchAgent for your account. For an existing Git clone, run `git pull --ff-only` from the project directory and then rerun `./scripts/install.sh`.

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

Follow the LaunchAgent log to monitor automatic switching.

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

The LaunchAgent writes standard error to `~/Library/Logs/MT7612U-ZeroCD/zerocd-daemon.err`.

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

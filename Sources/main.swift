import Foundation
import DiskArbitration
import IOKit

// Target: MediaTek MT7612U ZeroCD mode (VID: 0x0E8D, PID: 0x2870)
// Once ejected, it switches to Wi-Fi mode (VID: 0x0E8D, PID: 0x7612)
let targetVID = 0x0e8d
let targetPID = 0x2870
let targetDeviceName = "MediaTek MT7612U Wireless Dongle (ZeroCD Mode)"

func log(_ message: String) {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withTime, .withColonSeparatorInTime]
    let timestamp = formatter.string(from: Date())
    print("[\(timestamp)] \(message)")
    fflush(stdout)
}

func inspectUSB(disk: DADisk) -> (vid: Int, pid: Int, vendor: String, product: String)? {
    let mediaService = DADiskCopyIOMedia(disk)
    guard mediaService != 0 else { return nil }
    defer { IOObjectRelease(mediaService) }

    var current = mediaService
    var isFirst = true

    while current != 0 {
        var vidVal: Int? = nil
        var pidVal: Int? = nil
        var vName = ""
        var pName = ""

        if let val = IORegistryEntryCreateCFProperty(current, "idVendor" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int {
            vidVal = val
        }
        if let val = IORegistryEntryCreateCFProperty(current, "idProduct" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int {
            pidVal = val
        }
        if let val = IORegistryEntryCreateCFProperty(current, "USB Vendor Name" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String {
            vName = val
        } else if let val = IORegistryEntryCreateCFProperty(current, "kUSBVendorString" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String {
            vName = val
        }
        if let val = IORegistryEntryCreateCFProperty(current, "USB Product Name" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String {
            pName = val
        } else if let val = IORegistryEntryCreateCFProperty(current, "kUSBProductString" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String {
            pName = val
        }

        if let vid = vidVal, let pid = pidVal {
            if !isFirst { IOObjectRelease(current) }
            return (vid, pid, vName, pName)
        }

        var parent: io_registry_entry_t = 0
        if IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent) == KERN_SUCCESS {
            if !isFirst { IOObjectRelease(current) }
            isFirst = false
            current = parent
        } else {
            if !isFirst { IOObjectRelease(current) }
            break
        }
    }
    return nil
}

func isMT7612U(disk: DADisk) -> Bool {
    if let usb = inspectUSB(disk: disk) {
        if usb.vid == targetVID && usb.pid == targetPID {
            return true
        }
    }
    return false
}

func diskAppearedCallback(disk: DADisk, context: UnsafeMutableRawPointer?) {
    guard isMT7612U(disk: disk) else { return }
    let bsd = DADiskGetBSDName(disk).map { String(cString: $0) } ?? "unknown"

    log("Detected \(targetDeviceName) on /dev/\(bsd) [0x0e8d:0x2870]")
    log("Sending EJECT request to switch device to Wi-Fi mode [0x0e8d:0x7612]...")

    DADiskEject(disk, DADiskEjectOptions(kDADiskEjectOptionDefault), { disk, dissenter, context in
        let bsd = DADiskGetBSDName(disk).map { String(cString: $0) } ?? "unknown"
        if let dissenter = dissenter {
            let status = DADissenterGetStatus(dissenter)
            log("⚠️ Direct eject returned status \(status). Triggering diskutil eject fallback...")
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
            task.arguments = ["eject", bsd]
            try? task.run()
        } else {
            log("✅ Successfully ejected /dev/\(bsd)! MT7612U is switching to Wi-Fi mode.")
        }
    }, nil)
}

func diskMountApprovalCallback(disk: DADisk, context: UnsafeMutableRawPointer?) -> Unmanaged<DADissenter>? {
    if isMT7612U(disk: disk) {
        let bsd = DADiskGetBSDName(disk).map { String(cString: $0) } ?? "disk"
        log("Intercepted mount request for MT7612U on /dev/\(bsd). Suppressing mount...")
        let dissenter = DADissenterCreate(kCFAllocatorDefault, DAReturn(kDAReturnNotPermitted), "ZeroCD MT7612U Auto-Eject pending" as CFString)
        return Unmanaged.passRetained(dissenter)
    }
    return nil
}

guard let session = DASessionCreate(kCFAllocatorDefault) else {
    log("❌ Error: Unable to create DiskArbitration session.")
    exit(1)
}

DASessionScheduleWithRunLoop(session, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
DARegisterDiskMountApprovalCallback(session, nil, diskMountApprovalCallback, nil)
DARegisterDiskAppearedCallback(session, nil, diskAppearedCallback, nil)

log("🚀 Zer0CD Daemon started.")
log("Filtering strictly for MediaTek MT7612U (VID: 0x0E8D, PID: 0x2870)...")

CFRunLoopRun()

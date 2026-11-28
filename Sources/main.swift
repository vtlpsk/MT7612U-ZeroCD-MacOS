import Foundation
import DiskArbitration
import IOKit

let targetVID = 0x0e8d
let zeroCDPID = 0x2870
let wirelessPID = 0x7612
let switchConfirmationTimeout: TimeInterval = 10

let logDateFormatter = ISO8601DateFormatter()

func log(_ message: String) {
    print("[\(logDateFormatter.string(from: Date()))] \(message)")
    fflush(stdout)
}

func usbProperty(_ entry: io_registry_entry_t, _ key: String) -> Int? {
    IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?
        .takeRetainedValue() as? Int
}

// Walk up from the media to the nearest USB device, so a hub's IDs cannot match.
func copyUSBDevice(for media: io_service_t) -> io_registry_entry_t {
    var entry = media
    IOObjectRetain(entry)

    while IOObjectConformsTo(entry, "IOUSBHostDevice") == 0 {
        var parent: io_registry_entry_t = 0
        let result = IORegistryEntryGetParentEntry(entry, kIOServicePlane, &parent)
        IOObjectRelease(entry)
        guard result == KERN_SUCCESS else { return 0 }
        entry = parent
    }

    return entry
}

func isTargetUSBDevice(_ device: io_registry_entry_t, productID: Int) -> Bool {
    usbProperty(device, "idVendor") == targetVID && usbProperty(device, "idProduct") == productID
}

func mediaRegistryID(_ media: io_service_t) -> UInt64? {
    var id: UInt64 = 0
    guard IORegistryEntryGetRegistryEntryID(media, &id) == KERN_SUCCESS else { return nil }
    return id
}

func wirelessDeviceIsPresent(at locationID: Int) -> Bool {
    var iterator: io_iterator_t = 0
    // A null Mach port selects the default IOKit port on macOS 11 as well.
    let result = IOServiceGetMatchingServices(0, IOServiceMatching("IOUSBHostDevice"), &iterator)
    guard result == KERN_SUCCESS else { return false }
    defer { IOObjectRelease(iterator) }

    while case let device = IOIteratorNext(iterator), device != 0 {
        defer { IOObjectRelease(device) }
        if isTargetUSBDevice(device, productID: wirelessPID),
           usbProperty(device, "locationID") == locationID {
            return true
        }
    }

    return false
}

final class ModeSwitch {
    let bsdName: String
    let mediaID: UInt64?
    let locationID: Int?

    init(bsdName: String, mediaID: UInt64?, locationID: Int?) {
        self.bsdName = bsdName
        self.mediaID = mediaID
        self.locationID = locationID
    }

    var diskPath: String { "/dev/\(bsdName)" }

    func confirmWirelessMode() {
        guard let locationID = locationID else {
            log("\(diskPath): cannot verify Wi-Fi mode because the USB location is unavailable.")
            return
        }

        if wirelessDeviceIsPresent(at: locationID) {
            log("\(diskPath): Wi-Fi mode confirmed (0e8d:7612).")
            return
        }

        let start = ProcessInfo.processInfo.systemUptime
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            if wirelessDeviceIsPresent(at: locationID) {
                log("\(self.diskPath): Wi-Fi mode confirmed (0e8d:7612).")
                timer.invalidate()
            } else if ProcessInfo.processInfo.systemUptime - start >= switchConfirmationTimeout {
                log("\(self.diskPath): no Wi-Fi device (0e8d:7612) at the same USB location after \(Int(switchConfirmationTimeout)) seconds.")
                timer.invalidate()
            }
        }
    }

    func ejectWithDiskutil(_ disk: DADisk) {
        let media = DADiskCopyIOMedia(disk)
        defer { if media != 0 { IOObjectRelease(media) } }
        guard let mediaID = mediaID, media != 0, mediaRegistryID(media) == mediaID else {
            log("\(diskPath): skipping diskutil eject because the original media could not be verified.")
            confirmWirelessMode()
            return
        }

        log("\(diskPath): trying diskutil eject.")
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        task.arguments = ["eject", diskPath]
        task.terminationHandler = { task in
            let status = task.terminationStatus
            let reason = task.terminationReason
            DispatchQueue.main.async {
                if reason == .exit && status == 0 {
                    log("\(self.diskPath): diskutil ejected the virtual disk.")
                } else {
                    log("\(self.diskPath): diskutil eject failed (\(reason == .exit ? "exit status" : "signal") \(status)).")
                }
                self.confirmWirelessMode()
            }
        }

        do {
            try task.run()
        } catch {
            log("\(diskPath): could not launch diskutil: \(error.localizedDescription)")
            confirmWirelessMode()
        }
    }
}

func diskAppearedCallback(disk: DADisk, context: UnsafeMutableRawPointer?) {
    let media = DADiskCopyIOMedia(disk)
    guard media != 0 else { return }
    defer { IOObjectRelease(media) }

    let device = copyUSBDevice(for: media)
    guard device != 0 else { return }
    defer { IOObjectRelease(device) }
    guard isTargetUSBDevice(device, productID: zeroCDPID) else { return }

    guard let bsdName = DADiskGetBSDName(disk) else {
        log("Detected ZeroCD (0e8d:2870) without a BSD disk name.")
        return
    }

    let modeSwitch = ModeSwitch(
        bsdName: String(cString: bsdName),
        mediaID: mediaRegistryID(media),
        locationID: usbProperty(device, "locationID")
    )
    log("\(modeSwitch.diskPath): detected ZeroCD (0e8d:2870), requesting eject.")

    // The completion callback consumes this retained reference.
    let request = Unmanaged.passRetained(modeSwitch).toOpaque()
    DADiskEject(disk, DADiskEjectOptions(kDADiskEjectOptionDefault), { disk, dissenter, context in
        guard let context = context else { return }
        let modeSwitch = Unmanaged<ModeSwitch>.fromOpaque(context).takeRetainedValue()

        if let dissenter = dissenter {
            let status = DADissenterGetStatus(dissenter)
            log("\(modeSwitch.diskPath): Disk Arbitration eject failed (status \(status)).")
            modeSwitch.ejectWithDiskutil(disk)
        } else {
            log("\(modeSwitch.diskPath): Disk Arbitration ejected the virtual disk.")
            modeSwitch.confirmWirelessMode()
        }
    }, request)
}

func diskMountApprovalCallback(disk: DADisk, context: UnsafeMutableRawPointer?) -> Unmanaged<DADissenter>? {
    let media = DADiskCopyIOMedia(disk)
    guard media != 0 else { return nil }
    defer { IOObjectRelease(media) }

    let device = copyUSBDevice(for: media)
    guard device != 0 else { return nil }
    defer { IOObjectRelease(device) }
    guard isTargetUSBDevice(device, productID: zeroCDPID) else { return nil }

    let bsdName = DADiskGetBSDName(disk).map { String(cString: $0) } ?? "unknown"
    log("/dev/\(bsdName): blocked mounting the ZeroCD volume.")
    let dissenter = DADissenterCreate(
        kCFAllocatorDefault, DAReturn(kDAReturnNotPermitted), "MT7612U ZeroCD" as CFString
    )
    return Unmanaged.passRetained(dissenter)
}

guard let session = DASessionCreate(kCFAllocatorDefault) else {
    log("Unable to create Disk Arbitration session.")
    exit(1)
}

DASessionScheduleWithRunLoop(session, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
DARegisterDiskMountApprovalCallback(session, nil, diskMountApprovalCallback, nil)
DARegisterDiskAppearedCallback(
    session, kDADiskDescriptionMatchMediaWhole.takeUnretainedValue(), diskAppearedCallback, nil
)

log("ZeroCD daemon started. Watching for 0e8d:2870.")
CFRunLoopRun()

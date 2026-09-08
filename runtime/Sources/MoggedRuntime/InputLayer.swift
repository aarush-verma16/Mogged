import Foundation
import IOKit.hid

/// A gamepad the Mac can see. Names are for the operator console; Play does not
/// require this list to be non-empty — Wine enumerates the same USB HID devices.
public struct ConnectedController: Sendable, Equatable {
    public let name: String
}

/// Wired (and Bluetooth) pads on this Mac must show up as Windows HID/XInput
/// inside the title environment, or Steam Input and the game never see them.
public enum InputLayer {
    public static func environment() -> [String: String] {
        [
            "SDL_JOYSTICK_HIDAPI": "1",
            "SDL_JOYSTICK_MFI": "1",
            "SDL_JOYSTICK_HIDAPI_PS4": "1",
            "SDL_JOYSTICK_HIDAPI_PS5": "1",
            "SDL_JOYSTICK_HIDAPI_XBOX": "1",
            "SDL_JOYSTICK_HIDAPI_JOY_CONS": "1",
        ]
    }

    public static func apply(into env: inout [String: String]) {
        for (key, value) in environment() {
            env[key] = value
        }
    }

    public static func connected() -> [ConnectedController] {
        hidControllers()
    }

    public static var statusLabel: String {
        let pads = connected()
        if pads.isEmpty { return "none" }
        return pads.map(\.name).joined(separator: ", ")
    }

    /// SDL in the engine app only receives Game Controller events if that app
    /// declares it. Our copy of the engine lives under Application Support.
    public static func ensureHostAllowsControllers(wine: URL) {
        var url = wine
        for _ in 0..<8 {
            url.deleteLastPathComponent()
            let plist = url.appendingPathComponent("Contents/Info.plist")
            guard FileManager.default.fileExists(atPath: plist.path) else { continue }
            guard let dict = NSMutableDictionary(contentsOf: plist) else { continue }
            if dict["GCSupportsControllerUserInteraction"] as? Bool == true { return }
            dict["GCSupportsControllerUserInteraction"] = true
            dict.write(to: plist, atomically: true)
            return
        }
    }

    /// Generic Desktop joystick / gamepad / multi-axis. Does not seize the device.
    private static func hidControllers() -> [ConnectedController] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let page = 0x01
        let matches: [[String: Any]] = [
            [kIOHIDDeviceUsagePageKey as String: page, kIOHIDDeviceUsageKey as String: 0x04],
            [kIOHIDDeviceUsagePageKey as String: page, kIOHIDDeviceUsageKey as String: 0x05],
            [kIOHIDDeviceUsagePageKey as String: page, kIOHIDDeviceUsageKey as String: 0x08],
        ]
        IOHIDManagerSetDeviceMatchingMultiple(manager, matches as CFArray)
        guard IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
            return []
        }
        defer { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }
        guard let raw = IOHIDManagerCopyDevices(manager) else { return [] }
        let devices = (raw as NSSet) as? Set<IOHIDDevice> ?? []
        var names: [String] = []
        var seen = Set<String>()
        for device in devices {
            let product = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String
            let maker = IOHIDDeviceGetProperty(device, kIOHIDManufacturerKey as CFString) as? String
            let name = (product?.isEmpty == false ? product! : maker) ?? "Controller"
            let key = name.lowercased()
            if seen.insert(key).inserted {
                names.append(name)
            }
        }
        return names.map { ConnectedController(name: $0) }
    }
}

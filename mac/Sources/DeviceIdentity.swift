import Foundation
import IOKit
import CryptoKit

enum DeviceIdentity {
    /// Stable hashed hardware UUID for this Mac (not the raw serial).
    static var deviceHash: String {
        let raw = hardwareUUID() ?? Host.current().localizedName ?? "unknown-mac"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static var deviceName: String {
        Host.current().localizedName ?? "Mac"
    }

    private static func hardwareUUID() -> String? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard let cf = IORegistryEntryCreateCFProperty(service, "IOPlatformUUID" as CFString, kCFAllocatorDefault, 0)?
            .takeUnretainedValue() else { return nil }
        return cf as? String
    }
}

import Foundation
import IOKit
import CryptoKit

enum DeviceIdentity {
    /// Stable seat fingerprint for this Mac.
    ///
    /// Industry practice (LicenseFlow / Keylight / LicenseManager): use
    /// `IOPlatformUUID` (survives OS reinstalls, changes on logic-board swap),
    /// hash it, and never send the raw hardware serial to the server.
    /// Re-activating the same Mac reuses the same seat.
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

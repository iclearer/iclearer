import Foundation
import CryptoKit
import Security

struct LicenseClaims: Codable, Equatable {
    var v: Int
    var email: String
    var key: String
    var plan: String
    var macs: Int
    var device_hash: String
    var verified_at: Int
    var grace_days: Int

    var verifiedDate: Date {
        Date(timeIntervalSince1970: TimeInterval(verified_at))
    }

    var daysSinceVerified: Int {
        max(0, Int(Date().timeIntervalSince(verifiedDate) / 86_400))
    }

    var isWithinGrace: Bool {
        daysSinceVerified <= grace_days
    }

    var isWithinWarnWindow: Bool {
        let ok = LicenseConfig.graceDaysOK
        return daysSinceVerified > ok && daysSinceVerified <= grace_days
    }
}

enum LicenseBlob {
    static func verify(_ blob: String) -> LicenseClaims? {
        let parts = blob.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 2, let payloadData = base64URLDecode(parts[0]),
              let sigData = base64URLDecode(parts[1]),
              let publicKey = publicKey()
        else { return nil }

        let payloadBytes = Data(parts[0].utf8)
        guard publicKey.isValidSignature(sigData, for: payloadBytes) else { return nil }
        return try? JSONDecoder().decode(LicenseClaims.self, from: payloadData)
    }

    static func store(_ blob: String) {
        KeychainStore.set(blob, account: "license_blob")
    }

    static func load() -> String? {
        KeychainStore.get(account: "license_blob")
    }

    static func clear() {
        KeychainStore.delete(account: "license_blob")
    }

    static func currentClaims() -> LicenseClaims? {
        guard let blob = load() else { return nil }
        return verify(blob)
    }

    private static func publicKey() -> Curve25519.Signing.PublicKey? {
        guard let spki = Data(base64Encoded: LicenseConfig.licensePublicKeySPKIB64),
              spki.count >= 32
        else { return nil }
        let raw = spki.suffix(32)
        return try? Curve25519.Signing.PublicKey(rawRepresentation: raw)
    }

    private static func base64URLDecode(_ s: String) -> Data? {
        var b64 = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let pad = (4 - b64.count % 4) % 4
        b64 += String(repeating: "=", count: pad)
        return Data(base64Encoded: b64)
    }
}

enum KeychainStore {
    private static let service = "com.iclearer.app.license"

    static func set(_ value: String, account: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    static func get(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

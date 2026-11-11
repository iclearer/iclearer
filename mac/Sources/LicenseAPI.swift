import Foundation

struct LicenseAPIResponse: Decodable {
    var ok: Bool
    var error: String?
    var message: String?
    var email: String?
    var key: String?
    var plan: String?
    var macs: Int?
    var status: String?
    var license_blob: String?
    var created: Bool?
    var emailed: Bool?
    var email_skipped: Bool?
    var next: String?
    var devices: [LicenseDeviceDTO]?
}

struct LicenseDeviceDTO: Decodable {
    var id: String?
    var device_hash: String
    var device_name: String?
    var app_version: String?
    var last_seen_at: String?
    var created_at: String?
}

enum LicenseAPI {
    static func signup(email: String, marketing: Bool) async -> LicenseAPIResponse {
        await post([
            "action": "signup",
            "email": email,
            "marketing_opt_in": marketing
        ])
    }

    static func activate(email: String, key: String) async -> LicenseAPIResponse {
        await post([
            "action": "activate",
            "email": email,
            "key": key,
            "device_hash": DeviceIdentity.deviceHash,
            "device_name": DeviceIdentity.deviceName,
            "app_version": LicenseConfig.appVersion
        ])
    }

    static func heartbeat(email: String, key: String) async -> LicenseAPIResponse {
        await post([
            "action": "heartbeat",
            "email": email,
            "key": key,
            "device_hash": DeviceIdentity.deviceHash,
            "app_version": LicenseConfig.appVersion
        ])
    }

    static func sendSignInLink(email: String) async -> LicenseAPIResponse {
        await post([
            "action": "send_signin_link",
            "email": email
        ])
    }

    static func resendKey(email: String) async -> LicenseAPIResponse {
        await post([
            "action": "resend_key",
            "email": email
        ])
    }

    static func listDevices(email: String, key: String) async -> LicenseAPIResponse {
        await post([
            "action": "list_devices",
            "email": email,
            "key": key
        ])
    }

    static func removeDevice(email: String, key: String, deviceHash: String) async -> LicenseAPIResponse {
        await post([
            "action": "remove_device",
            "email": email,
            "key": key,
            "device_hash": deviceHash
        ])
    }

    static func setMarketing(email: String, key: String?, marketing: Bool) async -> LicenseAPIResponse {
        var body: [String: Any] = [
            "action": "set_marketing",
            "email": email,
            "marketing_opt_in": marketing
        ]
        if let key, !key.isEmpty {
            body["key"] = key
        }
        return await post(body)
    }

    private static func post(_ body: [String: Any]) async -> LicenseAPIResponse {
        var request = URLRequest(url: LicenseConfig.licenseAPIURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(LicenseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(LicenseConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("iClearer-Mac", forHTTPHeaderField: "x-iclearer-app")
        request.timeoutInterval = 30
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                if let decoded = try? JSONDecoder().decode(LicenseAPIResponse.self, from: data) {
                    return decoded
                }
                return LicenseAPIResponse(ok: false, error: "Server error (\(http.statusCode)).")
            }
            return try JSONDecoder().decode(LicenseAPIResponse.self, from: data)
        } catch {
            return LicenseAPIResponse(ok: false, error: error.localizedDescription)
        }
    }
}

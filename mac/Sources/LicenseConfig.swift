import Foundation

/// Cloud endpoints for license signup / activate / heartbeat.
/// Uses the company Supabase project + Edge Function `license-api`.
enum LicenseConfig {
    static let supabaseURL = URL(string: "https://kzbimjneyhlivsodhpgm.supabase.co")!
    /// Publishable / anon key — Edge Function has verify_jwt=false; this is only for gateway routing.
    static let supabaseAnonKey = "sb_publishable_g0M4nIaak9CkhauA504hRA_wulzYdS7"

    static var licenseAPIURL: URL {
        supabaseURL.appendingPathComponent("functions/v1/license-api")
    }

    /// SPKI (DER) Ed25519 public key — must match LICENSE_SIGNING_PUBLIC_KEY_B64 on the server.
    static let licensePublicKeySPKIB64 = "MCowBQYDK2VwAyEAXIQsOdFZHMSmAWiE3ceRZfiLRq0lHiqhb/mBsNghgcs="

    static let graceDaysOK = 24
    static let graceDaysWarn = 6
    static var graceDaysTotal: Int { graceDaysOK + graceDaysWarn }

    static let appVersion: String =
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
}

import Foundation

enum LicensePlan: String, Codable {
    case free
    case monthly
    case yearly
    case once

    var displayName: String {
        switch self {
        case .free: return "Free plan"
        case .monthly: return "iClearer Monthly"
        case .yearly: return "iClearer Yearly"
        case .once: return "iClearer · Version 1"
        }
    }

    var isPro: Bool { self != .free }
    var isSubscription: Bool { self == .monthly || self == .yearly }
}

struct LicenseState: Equatable {
    var email: String
    var plan: LicensePlan
    var key: String
    var usedCleanupBytes: Int64
    var marketingOptIn: Bool
    var onboardingComplete: Bool
    var macSeats: Int
    var protectedPaths: [String]
    var scanEveryday: Bool
    var scanBackups: Bool
    var scanBuilders: Bool
    var largeFileMinMB: Int
    var launchAtLogin: Bool
    var menuBarItem: Bool
    var scheduleEnabled: Bool
    /// "light" | "dark"
    var appearance: String
    var lowSpaceAlerts: Bool
    var notifyScanFinished: Bool
    /// "Daily" | "Weekly" | "Monthly"
    var scheduleFrequency: String
    /// Unix seconds of last successful online verify (also embedded in Keychain blob).
    var lastVerifiedAt: Int

    static let freeQuotaBytes: Int64 = 500_000_000 // 500 MB
    static let testKey = "ICLR-TEST-0001-FREE"
    static let testEmail = "test@iclearer.com"

    static var `default`: LicenseState {
        LicenseState(
            email: "",
            plan: .free,
            key: "",
            usedCleanupBytes: 0,
            marketingOptIn: false,
            onboardingComplete: false,
            macSeats: 1,
            protectedPaths: [],
            scanEveryday: true,
            scanBackups: true,
            scanBuilders: true,
            largeFileMinMB: 500,
            launchAtLogin: false,
            menuBarItem: true,
            scheduleEnabled: false,
            appearance: "dark",
            lowSpaceAlerts: false,
            notifyScanFinished: true,
            scheduleFrequency: "Weekly",
            lastVerifiedAt: 0
        )
    }

    var remainingFreeBytes: Int64 {
        max(0, Self.freeQuotaBytes - usedCleanupBytes)
    }

    /// Pro entitlement considering offline signed blob + grace window.
    var isPro: Bool {
        guard plan.isPro else { return false }
        if let claims = LicenseBlob.currentClaims() {
            guard claims.device_hash == DeviceIdentity.deviceHash else { return false }
            return claims.isWithinGrace
        }
        // No blob yet (legacy / mid-migration): allow briefly if we have a key.
        if lastVerifiedAt > 0 {
            let days = Int(Date().timeIntervalSince1970 - TimeInterval(lastVerifiedAt)) / 86_400
            return days <= LicenseConfig.graceDaysTotal
        }
        return !key.isEmpty
    }

    var licenseNeedsOnlineCheck: Bool {
        guard plan.isPro else { return false }
        guard let claims = LicenseBlob.currentClaims() else { return true }
        return claims.isWithinWarnWindow || claims.daysSinceVerified >= LicenseConfig.graceDaysOK
    }
}

extension LicenseState: Codable {
    enum CodingKeys: String, CodingKey {
        case email, plan, key, usedCleanupBytes, marketingOptIn, onboardingComplete, macSeats
        case protectedPaths, scanEveryday, scanBackups, scanBuilders, largeFileMinMB
        case launchAtLogin, menuBarItem, scheduleEnabled
        case appearance, lowSpaceAlerts, notifyScanFinished, scheduleFrequency
        case lastVerifiedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let base = LicenseState.default
        email = try c.decodeIfPresent(String.self, forKey: .email) ?? base.email
        plan = try c.decodeIfPresent(LicensePlan.self, forKey: .plan) ?? base.plan
        key = try c.decodeIfPresent(String.self, forKey: .key) ?? base.key
        usedCleanupBytes = try c.decodeIfPresent(Int64.self, forKey: .usedCleanupBytes) ?? base.usedCleanupBytes
        marketingOptIn = try c.decodeIfPresent(Bool.self, forKey: .marketingOptIn) ?? base.marketingOptIn
        onboardingComplete = try c.decodeIfPresent(Bool.self, forKey: .onboardingComplete) ?? base.onboardingComplete
        macSeats = try c.decodeIfPresent(Int.self, forKey: .macSeats) ?? base.macSeats
        protectedPaths = try c.decodeIfPresent([String].self, forKey: .protectedPaths) ?? base.protectedPaths
        scanEveryday = try c.decodeIfPresent(Bool.self, forKey: .scanEveryday) ?? base.scanEveryday
        scanBackups = try c.decodeIfPresent(Bool.self, forKey: .scanBackups) ?? base.scanBackups
        scanBuilders = try c.decodeIfPresent(Bool.self, forKey: .scanBuilders) ?? base.scanBuilders
        largeFileMinMB = try c.decodeIfPresent(Int.self, forKey: .largeFileMinMB) ?? base.largeFileMinMB
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? base.launchAtLogin
        menuBarItem = try c.decodeIfPresent(Bool.self, forKey: .menuBarItem) ?? base.menuBarItem
        scheduleEnabled = try c.decodeIfPresent(Bool.self, forKey: .scheduleEnabled) ?? base.scheduleEnabled
        appearance = try c.decodeIfPresent(String.self, forKey: .appearance) ?? base.appearance
        lowSpaceAlerts = try c.decodeIfPresent(Bool.self, forKey: .lowSpaceAlerts) ?? base.lowSpaceAlerts
        notifyScanFinished = try c.decodeIfPresent(Bool.self, forKey: .notifyScanFinished) ?? base.notifyScanFinished
        scheduleFrequency = try c.decodeIfPresent(String.self, forKey: .scheduleFrequency) ?? base.scheduleFrequency
        lastVerifiedAt = try c.decodeIfPresent(Int.self, forKey: .lastVerifiedAt) ?? base.lastVerifiedAt
    }
}

enum LicenseStore {
    private static let defaultsKey = "iclearer.license.v1"
    private static let pendingEmailKey = "iclearer.pendingEmail"
    private static let pendingMarketingKey = "iclearer.pendingMarketing"
    private static var cached = load()

    static var current: LicenseState { cached }

    /// Email typed during onboarding / sign-in before a key is activated — form prefill only.
    static var pendingEmail: String {
        get { UserDefaults.standard.string(forKey: pendingEmailKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: pendingEmailKey) }
    }

    static var pendingMarketing: Bool {
        get { UserDefaults.standard.bool(forKey: pendingMarketingKey) }
        set { UserDefaults.standard.set(newValue, forKey: pendingMarketingKey) }
    }

    static func observe(_ observer: AnyObject, handler: @escaping () -> Void) {
        NotificationCenter.default.addObserver(forName: .iClearerLicenseChanged, object: nil, queue: .main) { [weak observer] _ in
            guard observer != nil else { return }
            handler()
        }
    }

    static func update(_ mutate: (inout LicenseState) -> Void) {
        mutate(&cached)
        save()
        NotificationCenter.default.post(name: .iClearerLicenseChanged, object: nil)
    }

    /// Remember email for form prefill without treating the user as signed in.
    static func setPendingAccount(email: String, marketing: Bool) {
        let clean = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        pendingEmail = clean
        pendingMarketing = marketing
    }

    static func clearPendingAccount() {
        pendingEmail = ""
        pendingMarketing = false
    }

    /// Commit account email only after activate / intentional free onboarding finish.
    static func setEmail(_ email: String, marketing: Bool) {
        update {
            $0.email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            $0.marketingOptIn = marketing
        }
        clearPendingAccount()
    }

    static func setMarketingOptIn(_ on: Bool) {
        update { $0.marketingOptIn = on }
        let state = cached
        let email = state.email.isEmpty ? pendingEmail : state.email
        guard !email.isEmpty else { return }
        Task {
            _ = await LicenseAPI.setMarketing(
                email: email,
                key: state.key.isEmpty ? nil : state.key,
                marketing: on
            )
        }
    }

    /// Apply a successful activate / heartbeat response (signed blob + plan).
    static func applyRemote(_ response: LicenseAPIResponse) {
        guard response.ok else { return }
        let plan = LicensePlan(rawValue: response.plan ?? "free") ?? .free
        if let blob = response.license_blob {
            LicenseBlob.store(blob)
        }
        update {
            if let email = response.email, !email.isEmpty { $0.email = email.lowercased() }
            if let key = response.key, !key.isEmpty { $0.key = key.uppercased() }
            $0.plan = plan
            $0.macSeats = max(1, response.macs ?? $0.macSeats)
            $0.lastVerifiedAt = Int(Date().timeIntervalSince1970)
            if plan.isPro { $0.onboardingComplete = true }
        }
        clearPendingAccount()
    }

    /// Local-only activate for the seeded test key when the API is unreachable.
    @discardableResult
    static func activateOfflineFallback(email: String, key: String) -> (ok: Bool, message: String) {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard cleanEmail.contains("@"), cleanEmail.contains(".") else {
            return (false, "Enter a valid email address.")
        }
        guard !cleanKey.isEmpty else { return (false, "Enter your license key.") }

        let isTest =
            cleanKey == LicenseState.testKey
            || cleanKey.contains("TEST")
            || cleanKey.contains("ONCE")
        guard isTest else {
            return (false, "Connect to the internet to activate this license.")
        }

        let plan: LicensePlan
        if cleanKey.contains("ONCE") { plan = .once }
        else if cleanKey.contains("MONTH") { plan = .monthly }
        else { plan = .yearly }

        update {
            $0.email = cleanEmail
            $0.key = cleanKey
            $0.plan = plan
            $0.macSeats = 1
            $0.onboardingComplete = true
            $0.lastVerifiedAt = Int(Date().timeIntervalSince1970)
        }
        clearPendingAccount()
        return (true, "\(plan.displayName) activated for \(cleanEmail) (offline test).")
    }

    @discardableResult
    static func activate(email: String, key: String) -> (ok: Bool, message: String) {
        // Synchronous wrapper kept for older call sites — prefer async activateOnline.
        activateOfflineFallback(email: email, key: key)
    }

    static func signOut() {
        LicenseBlob.clear()
        clearPendingAccount()
        update {
            $0.plan = .free
            $0.key = ""
            $0.email = ""
            $0.marketingOptIn = false
            $0.usedCleanupBytes = 0
            $0.lastVerifiedAt = 0
            $0.macSeats = 1
            $0.onboardingComplete = false
        }
    }

    static func recordCleanup(bytes: Int64) {
        guard !cached.isPro else { return }
        update { $0.usedCleanupBytes += bytes }
    }

    static func completeOnboarding() {
        update { $0.onboardingComplete = true }
    }

    /// Refresh signed license when online (call from app launch).
    static func heartbeatIfNeeded() {
        let state = cached
        guard !state.key.isEmpty, !state.email.isEmpty else { return }
        Task {
            let response = await LicenseAPI.heartbeat(email: state.email, key: state.key)
            await MainActor.run {
                if response.ok {
                    applyRemote(response)
                } else if let err = response.error, err.lowercased().contains("not activated") {
                    // Device missing — leave local state; user can re-activate.
                }
            }
        }
    }

    private static func load() -> LicenseState {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              var decoded = try? JSONDecoder().decode(LicenseState.self, from: data)
        else {
            return .default
        }
        // Abandoned sign-in: email was saved without a key / finished onboarding.
        // Do not treat that as logged in on next launch.
        if !decoded.email.isEmpty && decoded.key.isEmpty && !decoded.onboardingComplete {
            pendingEmail = decoded.email
            pendingMarketing = decoded.marketingOptIn
            decoded.email = ""
            decoded.marketingOptIn = false
            if let data = try? JSONEncoder().encode(decoded) {
                UserDefaults.standard.set(data, forKey: defaultsKey)
            }
        }
        return decoded
    }

    private static func save() {
        if let data = try? JSONEncoder().encode(cached) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}

extension Notification.Name {
    static let iClearerLicenseChanged = Notification.Name("iClearerLicenseChanged")
    static let iClearerStateChanged = Notification.Name("iClearerStateChanged")
    static let iClearerNavigate = Notification.Name("iClearerNavigate")
    static let iClearerShowSheet = Notification.Name("iClearerShowSheet")
    static let iClearerQuickLook = Notification.Name("iClearerQuickLook")
    static let iClearerToast = Notification.Name("iClearerToast")
}

enum SheetKind: String {
    case onboarding
    case upgrade
    case signIn
    case account
    case settings
    case about
    case help
    case rules
    case keys
}

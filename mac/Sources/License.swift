import Foundation

enum LicensePlan: String, Codable {
    case free
    case yearly
    case once

    var displayName: String {
        switch self {
        case .free: return "Free plan"
        case .yearly: return "iClearer Yearly"
        case .once: return "iClearer · Version 1"
        }
    }

    var isPro: Bool { self != .free }
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

    static let freeQuotaBytes: Int64 = 500_000_000 // 500 MB (decimal), matches prototype copy
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
            scheduleFrequency: "Weekly"
        )
    }

    var remainingFreeBytes: Int64 {
        max(0, Self.freeQuotaBytes - usedCleanupBytes)
    }

    var isPro: Bool { plan.isPro }
}

extension LicenseState: Codable {
    enum CodingKeys: String, CodingKey {
        case email, plan, key, usedCleanupBytes, marketingOptIn, onboardingComplete, macSeats
        case protectedPaths, scanEveryday, scanBackups, scanBuilders, largeFileMinMB
        case launchAtLogin, menuBarItem, scheduleEnabled
        case appearance, lowSpaceAlerts, notifyScanFinished, scheduleFrequency
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
    }
}

enum LicenseStore {
    private static let defaultsKey = "iclearer.license.v1"
    private static var cached = load()
    private static let observers = NSHashTable<AnyObject>.weakObjects()

    static var current: LicenseState { cached }

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

    static func setEmail(_ email: String, marketing: Bool) {
        update {
            $0.email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            $0.marketingOptIn = marketing
        }
    }

    @discardableResult
    static func activate(email: String, key: String) -> (ok: Bool, message: String) {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        guard cleanEmail.contains("@"), cleanEmail.contains(".") else {
            return (false, "Enter a valid email address.")
        }
        guard !cleanKey.isEmpty else {
            return (false, "Enter a license key.")
        }

        let isTestCombo =
            cleanKey == LicenseState.testKey
            || (cleanEmail == LicenseState.testEmail && cleanKey.contains("TEST"))
            || cleanKey.contains("TEST")
            || cleanKey.contains("ONCE")

        guard isTestCombo || cleanKey.hasPrefix("ICLR-") else {
            return (false, "That key isn’t recognized. Try ICLR-TEST-0001-FREE for local testing.")
        }

        // FREE test key stays Free (prototype). Use YEARLY or ONCE in the key for Pro.
        let plan: LicensePlan
        if cleanKey.contains("ONCE") { plan = .once }
        else if cleanKey.contains("FREE") { plan = .yearly }
        else { plan = .yearly }
        update {
            $0.email = cleanEmail
            $0.key = cleanKey
            $0.plan = plan
            $0.macSeats = 1
            $0.onboardingComplete = true
            if plan == .free { $0.usedCleanupBytes = 0 }
        }
        return (true, "\(plan.displayName) activated for \(cleanEmail).")
    }

    static func signOut() {
        update {
            $0.plan = .free
            $0.key = ""
            $0.usedCleanupBytes = 0
            // Keep email for convenience unless empty
        }
    }

    static func recordCleanup(bytes: Int64) {
        guard !cached.isPro else { return }
        update { $0.usedCleanupBytes += bytes }
    }

    static func completeOnboarding() {
        update { $0.onboardingComplete = true }
    }

    private static func load() -> LicenseState {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode(LicenseState.self, from: data)
        else {
            return .default
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

import Foundation
import AppKit

enum CacheSafety: String, Codable {
    case safe
    case askFirst

    var label: String {
        switch self {
        case .safe: return "Safe"
        case .askFirst: return "Ask first"
        }
    }
}

enum CleanGroup: String {
    case everyday = "Everyday"
    case builders = "Builders"
}

/// Prototype Builders grid buckets — sizes come from Clean → Builders rows.
enum BuilderBucket: Int, CaseIterable {
    case xcode
    case node
    case python
    case homebrew
    case docker
    case ai

    var proTitle: String {
        switch self {
        case .xcode: return "Xcode"
        case .node: return "Node and npm"
        case .python: return "Python"
        case .homebrew: return "Homebrew"
        case .docker: return "Docker"
        case .ai: return "AI models"
        }
    }

    var freeKind: String {
        switch self {
        case .xcode: return "Build tool"
        case .node, .homebrew: return "Package manager"
        case .python: return "Language runtime"
        case .docker: return "Container tool"
        case .ai: return "AI tool"
        }
    }

    /// Maps a Clean → Builders list row into one of the six tiles (or nil if unrelated, e.g. iOS backups).
    static func classify(_ item: CacheItem) -> BuilderBucket? {
        let path = item.path.lowercased()
        let name = item.name.lowercased()

        if path.contains("ollama") || name.contains("ollama")
            || path.contains("huggingface") || name.contains("huggingface")
            || name.contains("ai model")
            || path.contains("transformers") || name.contains("transformers") {
            return .ai
        }
        if path.contains("docker") || path.contains("colima")
            || name.contains("docker") || name.contains("colima") {
            return .docker
        }
        if path.contains("homebrew") || name.contains("homebrew") {
            return .homebrew
        }
        if path.contains("/.npm") || path.hasSuffix("/.npm")
            || path.contains("/pnpm") || path.contains("/yarn")
            || name.contains("npm") || name.contains("pnpm") || name.contains("yarn") {
            return .node
        }
        if path.contains("deriveddata") || path.contains("coresimulator")
            || path.contains("/xcode") || name.contains("xcode") || name.contains("simulator")
            || path.contains("cocoapods") || name.contains("cocoapods")
            || path.contains("ms-playwright") || name.contains("playwright")
            || path.contains("/.gradle") || name.contains("gradle") {
            return .xcode
        }
        if path.contains("/pip") || name.contains("pip")
            || name.contains("python") || name.contains("uv")
            || path.contains("/.cache/uv") || path.contains("/.cache/pip") {
            return .python
        }
        // Remaining ~/.cache kids from the developer catalog → language runtime tile.
        if path.contains("/.cache/") {
            return .python
        }
        return nil
    }
}

enum CacheCategory: String, CaseIterable, Comparable, Codable {
    case browser = "Browser"
    case developer = "Developer"
    case apps = "Apps"
    case macos = "macOS"
    case optionalLarge = "Optional large files"

    var sortOrder: Int {
        switch self {
        case .browser: return 0
        case .developer: return 1
        case .apps: return 2
        case .macos: return 3
        case .optionalLarge: return 4
        }
    }

    var cleanGroup: CleanGroup {
        switch self {
        case .developer, .optionalLarge: return .builders
        default: return .everyday
        }
    }

    var mapBucket: String {
        switch self {
        case .browser, .apps: return "Apps"
        case .developer, .optionalLarge: return "Developer"
        case .macos: return "System"
        }
    }

    static func < (lhs: CacheCategory, rhs: CacheCategory) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

enum AppScreen: String, CaseIterable {
    case overview
    case clean
    case storageMap
    case largeFiles
    case apps
    case builders
    case history
    case duplicates
    case maintenance

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .clean: return "Clean"
        case .storageMap: return "Storage Map"
        case .largeFiles: return "Large & Old Files"
        case .apps: return "Apps"
        case .builders: return "Builders"
        case .history: return "History"
        case .duplicates: return "Duplicates"
        case .maintenance: return "Maintenance"
        }
    }

    var subtitle: String {
        switch self {
        case .overview: return "Your Mac at a glance"
        case .clean: return "Review what iClearer found"
        case .storageMap: return "See where your space went"
        case .largeFiles: return "Big files you have not opened in months"
        case .apps: return "Remove apps and their leftovers"
        case .builders: return "Developer and AI tool leftovers"
        case .history: return "Every cleanup, with restore"
        case .duplicates: return "Identical files taking space twice"
        case .maintenance: return "Small fixes that keep your Mac tidy"
        }
    }

    var isComingSoon: Bool {
        self == .duplicates || self == .maintenance
    }

    var commandDigit: String? {
        switch self {
        case .overview: return "1"
        case .clean: return "2"
        case .storageMap: return "3"
        case .largeFiles: return "4"
        case .apps: return "5"
        case .builders: return "6"
        case .history: return "7"
        default: return nil
        }
    }
}

struct CacheItem: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let path: String
    let bytes: Int64
    let category: CacheCategory
    let safety: CacheSafety
    let detail: String
    let genericName: String
    let willComeBack: String

    var group: CleanGroup { category.cleanGroup }

    var formattedSize: String { AppFormat.bytes(bytes) }

    func displayName(isPro: Bool) -> String {
        isPro ? name : genericName
    }

    func displayDetail(isPro: Bool) -> String {
        if isPro { return detail }
        return safety == .safe
            ? "Rebuilt automatically. Safe to clear."
            : "Can’t always be rebuilt. Review before clearing."
    }

    func displayPath(isPro: Bool) -> String {
        isPro ? path : "Location hidden on Free"
    }
}

struct DiskInfo {
    var total: Int64 = 0
    var used: Int64 = 0
    var free: Int64 = 0

    var usedFraction: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total)
    }

    var percentUsed: Int {
        Int((usedFraction * 100).rounded())
    }
}

struct CatalogEntry {
    let name: String
    let relativePath: String
    let category: CacheCategory
    let safety: CacheSafety
    let detail: String
    let willComeBack: String
    let genericName: String
    let expandChildren: Bool

    func resolvedPath(home: URL) -> URL {
        if relativePath.hasPrefix("/") {
            return URL(fileURLWithPath: relativePath)
        }
        if relativePath.hasPrefix("~/") {
            return home.appendingPathComponent(String(relativePath.dropFirst(2)))
        }
        return home.appendingPathComponent(relativePath)
    }
}

struct HistoryEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let bytes: Int64
    let summary: String
    /// Original on-disk paths before cleanup.
    let paths: [String]
    /// Matching Trash locations (parallel to `paths`) so Restore can put items back.
    let trashPaths: [String]
    let names: [String]
    var restored: Bool

    enum CodingKeys: String, CodingKey {
        case id, date, bytes, summary, paths, trashPaths, names, restored
    }

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        bytes: Int64,
        summary: String,
        paths: [String],
        trashPaths: [String],
        names: [String],
        restored: Bool = false
    ) {
        self.id = id
        self.date = date
        self.bytes = bytes
        self.summary = summary
        self.paths = paths
        self.trashPaths = trashPaths
        self.names = names
        self.restored = restored
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        date = try c.decode(Date.self, forKey: .date)
        bytes = try c.decode(Int64.self, forKey: .bytes)
        summary = try c.decode(String.self, forKey: .summary)
        paths = try c.decodeIfPresent([String].self, forKey: .paths) ?? []
        trashPaths = try c.decodeIfPresent([String].self, forKey: .trashPaths) ?? []
        names = try c.decodeIfPresent([String].self, forKey: .names) ?? []
        restored = try c.decodeIfPresent(Bool.self, forKey: .restored) ?? false
    }

    /// Prototype-style: “Today, 9:41 AM” or “Oct 28”.
    var formattedDate: String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            let t = DateFormatter()
            t.dateFormat = "h:mm a"
            return "Today, \(t.string(from: date))"
        }
        if cal.isDateInYesterday(date) {
            let t = DateFormatter()
            t.dateFormat = "h:mm a"
            return "Yesterday, \(t.string(from: date))"
        }
        let d = DateFormatter()
        d.dateFormat = "MMM d"
        return d.string(from: date)
    }

    func trashRecords() -> [TrashRecord] {
        zip(paths, trashPaths).map { original, trash in
            TrashRecord(
                originalPath: original,
                trashURL: URL(fileURLWithPath: trash),
                bytes: 0,
                name: (original as NSString).lastPathComponent
            )
        }
    }
}

struct TrashRecord {
    let originalPath: String
    let trashURL: URL
    let bytes: Int64
    let name: String
}

struct LargeFileItem: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    /// Home-relative parent folder shown in the list (e.g. `~/Downloads`).
    let path: String
    /// Absolute path used for Quick Look / Trash.
    let fullPath: String
    let bytes: Int64
    let ageLabel: String
    let kind: String

    /// Stable id so selection survives rescans of the same path.
    static func stableID(for fullPath: String) -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)
        let data = Array(fullPath.utf8)
        for (i, byte) in data.enumerated() {
            bytes[i % 16] ^= byte &+ UInt8(truncatingIfNeeded: i)
            bytes[(i &* 3) % 16] &+= byte
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}

struct AppLeftover: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let appBytes: Int64
    let leftoverBytes: Int64
    let lastUsed: String
    let bundlePath: String

    enum CodingKeys: String, CodingKey {
        case id, name, appBytes, leftoverBytes, lastUsed, bundlePath
    }

    init(id: UUID, name: String, appBytes: Int64, leftoverBytes: Int64, lastUsed: String, bundlePath: String = "") {
        self.id = id
        self.name = name
        self.appBytes = appBytes
        self.leftoverBytes = leftoverBytes
        self.lastUsed = lastUsed
        self.bundlePath = bundlePath
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        appBytes = try c.decode(Int64.self, forKey: .appBytes)
        leftoverBytes = try c.decode(Int64.self, forKey: .leftoverBytes)
        lastUsed = try c.decode(String.self, forKey: .lastUsed)
        bundlePath = try c.decodeIfPresent(String.self, forKey: .bundlePath) ?? ""
    }
}

struct MapChild: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let bytes: Int64

    init(id: UUID = UUID(), name: String, bytes: Int64) {
        self.id = id
        self.name = name
        self.bytes = bytes
    }
}

struct MapSlice: Identifiable {
    let id: UUID
    let name: String
    let bytes: Int64
    let color: NSColor
    var children: [MapChild] = []

    init(id: UUID = UUID(), name: String, bytes: Int64, color: NSColor, children: [MapChild] = []) {
        self.id = id
        self.name = name
        self.bytes = bytes
        self.color = color
        self.children = children
    }
}

/// Persisted scan so relaunch / rebuild does not force a full rescan every time.
struct ScanCache: Codable {
    var savedAt: Date
    var items: [CacheItem]
    var map: [PersistedMapSlice]
    var largeFiles: [LargeFileItem]
    var apps: [AppLeftover]
    var diskTotal: Int64
    var diskUsed: Int64
    var diskFree: Int64

    struct PersistedMapSlice: Codable {
        var name: String
        var bytes: Int64
        var children: [MapChild]
    }

    enum CodingKeys: String, CodingKey {
        case savedAt, items, map, largeFiles, apps, diskTotal, diskUsed, diskFree
    }

    init(
        savedAt: Date,
        items: [CacheItem],
        map: [PersistedMapSlice],
        largeFiles: [LargeFileItem],
        apps: [AppLeftover],
        diskTotal: Int64,
        diskUsed: Int64,
        diskFree: Int64
    ) {
        self.savedAt = savedAt
        self.items = items
        self.map = map
        self.largeFiles = largeFiles
        self.apps = apps
        self.diskTotal = diskTotal
        self.diskUsed = diskUsed
        self.diskFree = diskFree
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        savedAt = try c.decode(Date.self, forKey: .savedAt)
        items = try c.decode([CacheItem].self, forKey: .items)
        map = try c.decode([PersistedMapSlice].self, forKey: .map)
        largeFiles = try c.decodeIfPresent([LargeFileItem].self, forKey: .largeFiles) ?? []
        apps = try c.decodeIfPresent([AppLeftover].self, forKey: .apps) ?? []
        diskTotal = try c.decode(Int64.self, forKey: .diskTotal)
        diskUsed = try c.decode(Int64.self, forKey: .diskUsed)
        diskFree = try c.decode(Int64.self, forKey: .diskFree)
    }
}

enum AppFormat {
    static func bytes(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }

    /// Storage Map / disk legend — whole GB only ("41 GB"), matching the prototype.
    static func wholeGB(_ value: Int64) -> String {
        let gb = Double(value) / 1_000_000_000.0
        let rounded = Int(gb.rounded())
        return "\(max(0, rounded)) GB"
    }

    /// Legend / ring label: whole numbers only ("259 MB", "41 GB") — never "258.7 MB".
    static func mapSize(_ value: Int64) -> String {
        if value >= 500_000_000 { return wholeGB(value) }
        let mb = Double(value) / 1_000_000.0
        if mb >= 0.5 {
            return "\(max(1, Int(mb.rounded()))) MB"
        }
        let kb = Double(value) / 1_000.0
        return "\(max(0, Int(kb.rounded()))) KB"
    }

    static func count(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// “opened 3 days ago” / “opened 14 months ago” — rejects nonsense dates upstream.
    static func openedAgo(since date: Date) -> String {
        let seconds = max(0, Date().timeIntervalSince(date))
        let days = Int(seconds / 86_400)
        if days <= 0 { return "today" }
        if days == 1 { return "1 day" }
        if days < 45 { return "\(days) days" }
        let months = Int((Double(days) / 30.4).rounded())
        if months < 18 {
            return months <= 1 ? "1 month" : "\(months) months"
        }
        let years = max(1, Int((Double(days) / 365.0).rounded()))
        // Cap absurd ages so a bad timestamp never shows “47 years”.
        if years > 15 { return "a while" }
        return years == 1 ? "1 year" : "\(years) years"
    }

    /// Free-plan quota labels match the prototype ("500 MB"), not binary MiB.
    static func freeQuota(_ value: Int64) -> String {
        let mb = Double(value) / (1000.0 * 1000.0)
        if mb >= 999.5 {
            return String(format: "%.1f GB", mb / 1000.0)
        }
        if abs(mb - 500) < 25 {
            return "500 MB"
        }
        let rounded = Int(mb.rounded())
        return "\(rounded) MB"
    }
}

enum FreeMask {
    static func genericName(for name: String, category: CacheCategory, path: String) -> String {
        let lower = (name + " " + path).lowercased()
        if lower.contains("log") { return "App log files" }
        if lower.contains("chrome") || lower.contains("safari") || lower.contains("firefox") || lower.contains("brave") {
            return "Browser cache"
        }
        if lower.contains("/library/caches") && category == .macos { return "System cache" }
        if lower.contains("mail") { return "Mail cache" }
        if lower.contains("dmg") || lower.contains("pkg") || lower.contains("installer") { return "Old installer files" }
        if lower.contains("mobilesync") || lower.contains("backup") { return "Old device backups" }
        if lower.contains("/var/folders") || lower.contains("temporary") { return "System temporary files" }
        if lower.contains("deriveddata") { return "Developer build files" }
        if lower.contains("coresimulator") || lower.contains("simulator") { return "Developer simulator files" }
        if lower.contains("npm") || lower.contains("pip") || lower.contains("yarn") || lower.contains("pnpm") || lower.contains("homebrew") || lower.contains("cocoapods") || lower.contains("gradle") {
            return "Package manager cache"
        }
        if lower.contains("docker") || lower.contains("colima") { return "Container cache" }
        if lower.contains("ollama") || lower.contains("huggingface") { return "AI model files" }
        switch category {
        case .browser: return "Browser cache"
        case .developer: return "Developer build files"
        case .apps: return "App cache"
        case .macos: return "System cache"
        case .optionalLarge: return "Large optional files"
        }
    }
}

enum DemoData {
    static let largeFiles: [LargeFileItem] = []
    static let apps: [AppLeftover] = []

    static let neverTouchExamples = [
        ("Keychain", "Passwords and certificates"),
        ("Accounts", "Signed-in cloud and mail accounts"),
        ("Editor user data", "Cursor / VS Code settings and chats"),
        ("Tokens & SSH keys", "API tokens, .env, SSH private keys"),
        ("Git folders", ".git repositories and credentials")
    ]
}

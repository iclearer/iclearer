import Foundation

enum CacheSafety: String {
    case safe
    case optional
}

enum CacheCategory: String, CaseIterable, Comparable {
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

    static func < (lhs: CacheCategory, rhs: CacheCategory) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

struct CacheItem: Identifiable, Hashable {
    let id: UUID
    let name: String
    let path: String
    let bytes: Int64
    let category: CacheCategory
    let safety: CacheSafety
    let detail: String

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
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

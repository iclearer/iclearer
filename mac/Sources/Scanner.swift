import Foundation

enum CacheCatalog {
    static let entries: [CatalogEntry] = [
        CatalogEntry(
            name: "User caches",
            relativePath: "~/Library/Caches",
            category: .apps,
            safety: .safe,
            detail: "Per-app caches. Broken out below when possible.",
            willComeBack: "Rebuilt as you use apps. Safe to clear.",
            genericName: "App cache",
            expandChildren: true
        ),
        CatalogEntry(
            name: "Developer cache (~/.cache)",
            relativePath: "~/.cache",
            category: .developer,
            safety: .safe,
            detail: "uv, pip, Hugging Face, Codex, and similar tool caches.",
            willComeBack: "Tools refill caches as you use them.",
            genericName: "Package manager cache",
            expandChildren: true
        ),
        CatalogEntry(
            name: "npm cache",
            relativePath: "~/.npm",
            category: .developer,
            safety: .safe,
            detail: "Downloaded npm packages. Safe to delete; they redownload.",
            willComeBack: "npm downloads them again when needed.",
            genericName: "Package manager cache",
            expandChildren: false
        ),
        CatalogEntry(
            name: "pnpm store",
            relativePath: "~/Library/pnpm",
            category: .developer,
            safety: .safe,
            detail: "pnpm package store.",
            willComeBack: "pnpm downloads packages again when needed.",
            genericName: "Package manager cache",
            expandChildren: false
        ),
        CatalogEntry(
            name: "Yarn cache",
            relativePath: "~/Library/Caches/Yarn",
            category: .developer,
            safety: .safe,
            detail: "Yarn package cache.",
            willComeBack: "Yarn downloads packages again when needed.",
            genericName: "Package manager cache",
            expandChildren: false
        ),
        CatalogEntry(
            name: "pip cache",
            relativePath: "~/Library/Caches/pip",
            category: .developer,
            safety: .safe,
            detail: "Python pip downloads.",
            willComeBack: "pip downloads them again when needed.",
            genericName: "Package manager cache",
            expandChildren: false
        ),
        CatalogEntry(
            name: "Homebrew cache",
            relativePath: "~/Library/Caches/Homebrew",
            category: .developer,
            safety: .safe,
            detail: "Homebrew downloads and bottles.",
            willComeBack: "Homebrew downloads them again when needed.",
            genericName: "Package manager cache",
            expandChildren: false
        ),
        CatalogEntry(
            name: "Homebrew var cache (Apple Silicon)",
            relativePath: "/opt/homebrew/var/cache",
            category: .developer,
            safety: .safe,
            detail: "Homebrew variable cache on Apple Silicon.",
            willComeBack: "Homebrew downloads them again when needed.",
            genericName: "Package manager cache",
            expandChildren: false
        ),
        CatalogEntry(
            name: "Homebrew var cache (Intel)",
            relativePath: "/usr/local/var/cache",
            category: .developer,
            safety: .safe,
            detail: "Homebrew variable cache on Intel Macs.",
            willComeBack: "Homebrew downloads them again when needed.",
            genericName: "Package manager cache",
            expandChildren: false
        ),
        CatalogEntry(
            name: "Playwright browsers",
            relativePath: "~/Library/Caches/ms-playwright",
            category: .developer,
            safety: .safe,
            detail: "Cached browser binaries for tests.",
            willComeBack: "Playwright redownloads browsers when needed.",
            genericName: "Developer build files",
            expandChildren: false
        ),
        CatalogEntry(
            name: "Xcode DerivedData",
            relativePath: "~/Library/Developer/Xcode/DerivedData",
            category: .developer,
            safety: .safe,
            detail: "Xcode build cache. Rebuilds next time you compile.",
            willComeBack: "Xcode rebuilds it the next time you build.",
            genericName: "Developer build files",
            expandChildren: false
        ),
        CatalogEntry(
            name: "CocoaPods cache",
            relativePath: "~/Library/Caches/CocoaPods",
            category: .developer,
            safety: .safe,
            detail: "CocoaPods spec and download cache.",
            willComeBack: "CocoaPods downloads them again when needed.",
            genericName: "Package manager cache",
            expandChildren: false
        ),
        CatalogEntry(
            name: "Gradle cache",
            relativePath: "~/.gradle/caches",
            category: .developer,
            safety: .safe,
            detail: "Android / Gradle caches.",
            willComeBack: "Gradle downloads them again when needed.",
            genericName: "Package manager cache",
            expandChildren: false
        ),
        CatalogEntry(
            name: "Cursor caches",
            relativePath: "~/Library/Application Support/Cursor/Cache",
            category: .apps,
            safety: .safe,
            detail: "Cursor browser cache only. Does not include login or chats.",
            willComeBack: "Cursor refills cache as you use it.",
            genericName: "App cache",
            expandChildren: false
        ),
        CatalogEntry(
            name: "Cursor cached editors",
            relativePath: "~/Library/Application Support/Cursor/CachedData",
            category: .apps,
            safety: .safe,
            detail: "Cached Cursor editor bits.",
            willComeBack: "Cursor refills cache as you use it.",
            genericName: "App cache",
            expandChildren: false
        ),
        CatalogEntry(
            name: "Cursor logs",
            relativePath: "~/Library/Application Support/Cursor/logs",
            category: .apps,
            safety: .safe,
            detail: "Cursor log files.",
            willComeBack: "Rebuilt as you use Cursor.",
            genericName: "App log files",
            expandChildren: false
        ),
        CatalogEntry(
            name: "VS Code caches",
            relativePath: "~/Library/Application Support/Code/Cache",
            category: .apps,
            safety: .safe,
            detail: "VS Code cache. Does not include settings or login.",
            willComeBack: "VS Code refills cache as you use it.",
            genericName: "App cache",
            expandChildren: false
        ),
        CatalogEntry(
            name: "System caches",
            relativePath: "/Library/Caches",
            category: .macos,
            safety: .safe,
            detail: "Shared system app caches.",
            willComeBack: "macOS rebuilds them automatically.",
            genericName: "System cache",
            expandChildren: false
        ),
        CatalogEntry(
            name: "macOS temporary files",
            relativePath: "/private/var/folders",
            category: .macos,
            safety: .askFirst,
            detail: "macOS temp files. Usually safe; a few apps may rebuild caches.",
            willComeBack: "macOS recreates what it needs.",
            genericName: "System temporary files",
            expandChildren: false
        ),
        CatalogEntry(
            name: "User logs",
            relativePath: "~/Library/Logs",
            category: .macos,
            safety: .safe,
            detail: "Application log files.",
            willComeBack: "Rebuilt as you use apps.",
            genericName: "App log files",
            expandChildren: false
        ),
        CatalogEntry(
            name: "Colima / Docker disk",
            relativePath: "~/.colima",
            category: .optionalLarge,
            safety: .askFirst,
            detail: "Docker virtual machine disk. Only delete if you do not need Colima.",
            willComeBack: "Docker rebuilds layers, which can take minutes.",
            genericName: "Container cache",
            expandChildren: false
        ),
        CatalogEntry(
            name: "Ollama models",
            relativePath: "~/.ollama/models",
            category: .optionalLarge,
            safety: .askFirst,
            detail: "Downloaded AI models. You will have to download them again.",
            willComeBack: "Models download again, which can be large.",
            genericName: "AI model files",
            expandChildren: false
        ),
        CatalogEntry(
            name: "Docker data",
            relativePath: "~/.docker",
            category: .optionalLarge,
            safety: .askFirst,
            detail: "Docker settings and cache.",
            willComeBack: "Docker rebuilds layers, which can take minutes.",
            genericName: "Container cache",
            expandChildren: false
        ),
        CatalogEntry(
            name: "iOS Simulator",
            relativePath: "~/Library/Developer/CoreSimulator",
            category: .optionalLarge,
            safety: .askFirst,
            detail: "Xcode iOS Simulator data.",
            willComeBack: "Re-download in Xcode if you need one again.",
            genericName: "Developer simulator files",
            expandChildren: false
        ),
        CatalogEntry(
            name: "Old iOS backups",
            relativePath: "~/Library/Application Support/MobileSync/Backup",
            category: .optionalLarge,
            safety: .askFirst,
            detail: "Backups of iPhones and iPads made in Finder.",
            willComeBack: "Cannot be rebuilt. Keep one recent backup.",
            genericName: "Old device backups",
            expandChildren: false
        )
    ]

    /// Paths / fragments that must never be selected or deleted.
    static let blockedPathFragments = [
        "Keychains",
        "/Library/Keychains",
        "state.vscdb",
        "/Library/Application Support/Cursor/User",
        "/Library/Application Support/Code/User",
        "/.ssh/",
        "/.ssh",
        ".env",
        ".env.local",
        ".env.production",
        "id_rsa",
        "id_ed25519",
        "id_ecdsa",
        "credentials",
        "Cookies",
        "/.git/",
        "/.git",
        "Accounts",
        "Login Items",
        "Tokens",
        "token.json",
        "auth.json",
        "secrets",
        "wallet.dat"
    ]
}

enum DiskProbe {
    /// Matches System Settings → Storage: APFS container capacity and the
    /// “important usage” free figure (includes purgeable space). Raw
    /// `volumeAvailableCapacity` is lower (~86 GB here) and does not match Settings (~92 GB).
    static func current() -> DiskInfo {
        do {
            let values = try URL(fileURLWithPath: "/System/Volumes/Data").resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey
            ])
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let important = values.volumeAvailableCapacityForImportantUsage.map { Int64($0) } ?? 0
            let available = Int64(values.volumeAvailableCapacity ?? 0)
            let free = important > 0 ? important : available
            return DiskInfo(total: total, used: max(total - free, 0), free: free)
        } catch {
            return DiskInfo()
        }
    }
}

enum FolderSizer {
    /// Caps slow/hung `du` calls (iCloud / network placeholders) so scans can't stall forever.
    private static let defaultTimeoutSeconds: TimeInterval = 4

    static func bytes(at path: String) -> Int64 {
        bytes(at: path, timeout: defaultTimeoutSeconds)
    }

    static func bytes(at path: String, timeout: TimeInterval) -> Int64 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        process.arguments = ["-sk", path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            let deadline = Date().addingTimeInterval(timeout)
            while process.isRunning {
                if Date() > deadline {
                    process.terminate()
                    return 0
                }
                Thread.sleep(forTimeInterval: 0.05)
            }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let line = String(data: data, encoding: .utf8)?
                .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
                .first,
                let kilobytes = Int64(line)
            else {
                return 0
            }
            return kilobytes * 1024
        } catch {
            return 0
        }
    }
}

struct ScanProgress {
    var fraction: Double
    var label: String
    /// Listable leftovers found so far — same total Overview shows as “FOUND ON YOUR MAC”.
    var foundBytes: Int64
    /// Locations checked so far (not only listable leftovers).
    var foundCount: Int
    /// Extra line under the ring (e.g. “Click Allow” for Finder Automation).
    var hint: String? = nil
}

enum CacheScanner {
    static func scan(
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        includeEveryday: Bool = true,
        includeBuilders: Bool = true,
        includeBackups: Bool = true,
        protectedPaths: [String] = [],
        onProgress: ((ScanProgress) -> Void)? = nil
    ) -> [CacheItem] {
        var jobs: [(name: String, path: String, category: CacheCategory, safety: CacheSafety, detail: String, willComeBack: String, genericName: String)] = []
        var seen = Set<String>()
        let protected = Set(protectedPaths.map { ($0 as NSString).standardizingPath })

        for entry in CacheCatalog.entries {
            if entry.category.cleanGroup == .everyday && !includeEveryday { continue }
            if entry.category.cleanGroup == .builders && !includeBuilders { continue }
            if entry.name.contains("iOS backups") && !includeBackups { continue }

            let url = entry.resolvedPath(home: home)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            if entry.expandChildren {
                if let children = try? FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                ) {
                    for child in children {
                        let path = (child.path as NSString).standardizingPath
                        guard seen.insert(path).inserted, !isBlocked(path), !protected.contains(path) else { continue }
                        let friendly = friendlyName(for: child.lastPathComponent, parent: entry)
                        let category = categoryOverride(for: child.lastPathComponent, fallback: entry.category)
                        jobs.append((
                            friendly,
                            path,
                            category,
                            entry.safety,
                            child.path,
                            entry.willComeBack,
                            FreeMask.genericName(for: friendly, category: category, path: path)
                        ))
                    }
                } else {
                    let path = (url.path as NSString).standardizingPath
                    if seen.insert(path).inserted, !isBlocked(path), !protected.contains(path) {
                        jobs.append((entry.name, path, entry.category, entry.safety, entry.detail, entry.willComeBack, entry.genericName))
                    }
                }
            } else {
                let path = (url.path as NSString).standardizingPath
                if seen.insert(path).inserted, !isBlocked(path), !protected.contains(path) {
                    jobs.append((entry.name, path, entry.category, entry.safety, entry.detail, entry.willComeBack, entry.genericName))
                }
            }
        }

        // Measure bigger / Builders paths first so the scan “found” number climbs
        // toward the Overview total early (instead of sitting on small Everyday caches).
        jobs.sort { lhs, rhs in
            let lRank = lhs.category.cleanGroup == .builders ? 0 : 1
            let rRank = rhs.category.cleanGroup == .builders ? 0 : 1
            if lRank != rRank { return lRank < rRank }
            return lhs.name < rhs.name
        }

        var items: [CacheItem] = []
        // Same metric as Overview hero (`totalFoundBytes`): listable leftovers only.
        var checkedCount = 0
        var foundBytes: Int64 = 0
        let total = max(jobs.count, 1)
        for (index, job) in jobs.enumerated() {
            let size = FolderSizer.bytes(at: job.path)
            checkedCount = index + 1
            if size >= 1_000_000 {
                foundBytes += size
                items.append(CacheItem(
                    id: UUID(),
                    name: job.name,
                    path: job.path,
                    bytes: size,
                    category: job.category,
                    safety: job.safety,
                    detail: job.detail,
                    genericName: job.genericName,
                    willComeBack: job.willComeBack
                ))
            }
            onProgress?(ScanProgress(
                fraction: Double(checkedCount) / Double(total),
                label: "Measuring \(job.name)…",
                foundBytes: foundBytes,
                foundCount: checkedCount
            ))
        }

        onProgress?(ScanProgress(
            fraction: 1,
            label: "Scan complete",
            foundBytes: foundBytes,
            foundCount: checkedCount
        ))

        return items.sorted { $0.bytes > $1.bytes }
    }

    private static func isBlocked(_ path: String) -> Bool {
        let standardized = (path as NSString).standardizingPath
        let last = (standardized as NSString).lastPathComponent
        if last == ".git" || last == ".env" || last.hasPrefix(".env.") { return true }
        if last.hasPrefix("id_rsa") || last.hasPrefix("id_ed25519") || last.hasPrefix("id_ecdsa") { return true }
        return CacheCatalog.blockedPathFragments.contains { standardized.contains($0) }
    }

    private static func friendlyName(for folder: String, parent: CatalogEntry) -> String {
        switch folder {
        case "Google": return "Chrome"
        case "com.google.Chrome": return "Chrome"
        case "Firefox": return "Firefox"
        case "com.apple.Safari": return "Safari"
        case "pip": return "pip"
        case "Homebrew": return "Homebrew"
        case "JetBrains": return "JetBrains / PyCharm"
        case "ms-playwright": return "Playwright"
        case "pnpm": return "pnpm cache"
        case "Yarn": return "Yarn"
        case "uv": return "uv"
        case "huggingface": return "Hugging Face"
        case "codex-runtimes": return "Codex runtimes"
        case "com.openai.codex": return "Codex"
        default:
            if folder.hasPrefix("com.apple.") {
                return "Apple · " + folder.replacingOccurrences(of: "com.apple.", with: "")
            }
            if folder.hasPrefix("com.") {
                return folder
            }
            return folder
        }
    }

    private static func categoryOverride(for folder: String, fallback: CacheCategory) -> CacheCategory {
        switch folder.lowercased() {
        case "google", "com.google.chrome", "firefox", "com.apple.safari", "com.brave.browser":
            return .browser
        case "pip", "uv", "homebrew", "pnpm", "yarn", "npm", "ms-playwright", "jetbrains",
             "huggingface", "codex-runtimes", "com.openai.codex", "cocoapods", "node-gyp":
            return .developer
        default:
            return fallback
        }
    }
}

enum CacheCleaner {
    static func isAllowed(_ path: String) -> Bool {
        let standardized = (path as NSString).standardizingPath
        guard !CacheCatalog.blockedPathFragments.contains(where: { standardized.contains($0) }) else {
            return false
        }
        let last = (standardized as NSString).lastPathComponent
        if last == ".git" || last.hasPrefix(".env") || last.hasPrefix("id_rsa") || last.hasPrefix("id_ed25519") {
            return false
        }

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let allowedPrefixes = [
            home + "/Library/Caches",
            home + "/.cache",
            home + "/.npm",
            home + "/Library/pnpm",
            home + "/Library/Logs",
            home + "/Library/Developer",
            home + "/Library/Application Support/Cursor/Cache",
            home + "/Library/Application Support/Cursor/CachedData",
            home + "/Library/Application Support/Cursor/logs",
            home + "/Library/Application Support/Cursor/snapshots",
            home + "/Library/Application Support/Cursor/CachedExtensionVSIXs",
            home + "/Library/Application Support/Code/Cache",
            home + "/Library/Application Support/MobileSync/Backup",
            home + "/.colima",
            home + "/.ollama/models",
            home + "/.docker",
            home + "/.gradle/caches",
            "/Library/Caches",
            "/opt/homebrew/var/cache",
            "/usr/local/var/cache",
            "/private/var/folders"
        ]
        return allowedPrefixes.contains { standardized == $0 || standardized.hasPrefix($0 + "/") }
    }

    static func moveToTrash(_ path: String) throws -> URL? {
        guard isAllowed(path) else {
            throw CleanError.blocked(path)
        }
        var resulting: NSURL?
        try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: &resulting)
        return resulting as URL?
    }

    static func restoreFromTrash(_ record: TrashRecord) throws {
        let fm = FileManager.default
        let destination = URL(fileURLWithPath: record.originalPath)
        let parent = destination.deletingLastPathComponent()
        if !fm.fileExists(atPath: parent.path) {
            try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        }
        if fm.fileExists(atPath: destination.path) {
            throw CleanError.restoreFailed("Destination already exists: \(record.originalPath)")
        }
        guard fm.fileExists(atPath: record.trashURL.path) else {
            throw CleanError.restoreFailed("Missing from Trash: \(record.name)")
        }
        try fm.moveItem(at: record.trashURL, to: destination)
    }

    /// Locates a trashed item when we only know the original path (Empty Trash / rename).
    static func findInTrash(originalPath: String) -> URL? {
        let fm = FileManager.default
        let baseName = (originalPath as NSString).lastPathComponent
        var folders: [URL] = [
            fm.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")
        ]
        if let vols = try? fm.contentsOfDirectory(
            at: URL(fileURLWithPath: "/Volumes"),
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for vol in vols {
                folders.append(vol.appendingPathComponent(".Trashes"))
            }
        }
        for folder in folders {
            let exact = folder.appendingPathComponent(baseName)
            if fm.fileExists(atPath: exact.path) { return exact }
            guard let kids = try? fm.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }
            // Finder often renames collisions: “Name 10.41.22 AM”.
            if let match = kids.first(where: {
                $0.lastPathComponent == baseName
                    || $0.lastPathComponent.hasPrefix(baseName + " ")
            }) {
                return match
            }
        }
        return nil
    }

    enum CleanError: LocalizedError {
        case blocked(String)
        case restoreFailed(String)

        var errorDescription: String? {
            switch self {
            case .blocked(let path):
                return "iClearer refused to delete a protected path: \(path)"
            case .restoreFailed(let message):
                return message
            }
        }
    }
}

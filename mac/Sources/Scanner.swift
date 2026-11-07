import Foundation

enum CacheCatalog {
    static let entries: [CatalogEntry] = [
        CatalogEntry(
            name: "User caches",
            relativePath: "~/Library/Caches",
            category: .apps,
            safety: .safe,
            detail: "Per-app caches. Broken out below when possible.",
            expandChildren: true
        ),
        CatalogEntry(
            name: "Developer cache (~/.cache)",
            relativePath: "~/.cache",
            category: .developer,
            safety: .safe,
            detail: "uv, pip, Hugging Face, Codex, and similar tool caches.",
            expandChildren: true
        ),
        CatalogEntry(
            name: "npm cache",
            relativePath: "~/.npm",
            category: .developer,
            safety: .safe,
            detail: "Downloaded npm packages. Safe to delete; they redownload.",
            expandChildren: false
        ),
        CatalogEntry(
            name: "pnpm store",
            relativePath: "~/Library/pnpm",
            category: .developer,
            safety: .safe,
            detail: "pnpm package store.",
            expandChildren: false
        ),
        CatalogEntry(
            name: "Yarn cache",
            relativePath: "~/Library/Caches/Yarn",
            category: .developer,
            safety: .safe,
            detail: "Yarn package cache.",
            expandChildren: false
        ),
        CatalogEntry(
            name: "pip cache",
            relativePath: "~/Library/Caches/pip",
            category: .developer,
            safety: .safe,
            detail: "Python pip downloads.",
            expandChildren: false
        ),
        CatalogEntry(
            name: "Homebrew cache",
            relativePath: "~/Library/Caches/Homebrew",
            category: .developer,
            safety: .safe,
            detail: "Homebrew downloads and bottles.",
            expandChildren: false
        ),
        CatalogEntry(
            name: "Homebrew var cache (Apple Silicon)",
            relativePath: "/opt/homebrew/var/cache",
            category: .developer,
            safety: .safe,
            detail: "Homebrew variable cache on Apple Silicon.",
            expandChildren: false
        ),
        CatalogEntry(
            name: "Homebrew var cache (Intel)",
            relativePath: "/usr/local/var/cache",
            category: .developer,
            safety: .safe,
            detail: "Homebrew variable cache on Intel Macs.",
            expandChildren: false
        ),
        CatalogEntry(
            name: "Playwright browsers",
            relativePath: "~/Library/Caches/ms-playwright",
            category: .developer,
            safety: .safe,
            detail: "Cached browser binaries for tests.",
            expandChildren: false
        ),
        CatalogEntry(
            name: "Xcode DerivedData",
            relativePath: "~/Library/Developer/Xcode/DerivedData",
            category: .developer,
            safety: .safe,
            detail: "Xcode build cache. Rebuilds next time you compile.",
            expandChildren: false
        ),
        CatalogEntry(
            name: "CocoaPods cache",
            relativePath: "~/Library/Caches/CocoaPods",
            category: .developer,
            safety: .safe,
            detail: "CocoaPods spec and download cache.",
            expandChildren: false
        ),
        CatalogEntry(
            name: "Gradle cache",
            relativePath: "~/.gradle/caches",
            category: .developer,
            safety: .safe,
            detail: "Android / Gradle caches.",
            expandChildren: false
        ),
        CatalogEntry(
            name: "Cursor caches",
            relativePath: "~/Library/Application Support/Cursor/Cache",
            category: .apps,
            safety: .safe,
            detail: "Cursor browser cache only. Does not include login or chats.",
            expandChildren: false
        ),
        CatalogEntry(
            name: "Cursor cached editors",
            relativePath: "~/Library/Application Support/Cursor/CachedData",
            category: .apps,
            safety: .safe,
            detail: "Cached Cursor editor bits.",
            expandChildren: false
        ),
        CatalogEntry(
            name: "Cursor logs",
            relativePath: "~/Library/Application Support/Cursor/logs",
            category: .apps,
            safety: .safe,
            detail: "Cursor log files.",
            expandChildren: false
        ),
        CatalogEntry(
            name: "VS Code caches",
            relativePath: "~/Library/Application Support/Code/Cache",
            category: .apps,
            safety: .safe,
            detail: "VS Code cache. Does not include settings or login.",
            expandChildren: false
        ),
        CatalogEntry(
            name: "System caches",
            relativePath: "/Library/Caches",
            category: .macos,
            safety: .safe,
            detail: "Shared system app caches.",
            expandChildren: false
        ),
        CatalogEntry(
            name: "macOS temporary files",
            relativePath: "/private/var/folders",
            category: .macos,
            safety: .optional,
            detail: "macOS temp files. Usually safe; a few apps may rebuild caches.",
            expandChildren: false
        ),
        CatalogEntry(
            name: "User logs",
            relativePath: "~/Library/Logs",
            category: .macos,
            safety: .safe,
            detail: "Application log files.",
            expandChildren: false
        ),
        CatalogEntry(
            name: "Colima / Docker disk",
            relativePath: "~/.colima",
            category: .optionalLarge,
            safety: .optional,
            detail: "Docker virtual machine disk. Only delete if you do not need Colima.",
            expandChildren: false
        ),
        CatalogEntry(
            name: "Ollama models",
            relativePath: "~/.ollama/models",
            category: .optionalLarge,
            safety: .optional,
            detail: "Downloaded AI models. You will have to download them again.",
            expandChildren: false
        ),
        CatalogEntry(
            name: "Docker data",
            relativePath: "~/.docker",
            category: .optionalLarge,
            safety: .optional,
            detail: "Docker settings and cache.",
            expandChildren: false
        ),
        CatalogEntry(
            name: "iOS Simulator",
            relativePath: "~/Library/Developer/CoreSimulator",
            category: .optionalLarge,
            safety: .optional,
            detail: "Xcode iOS Simulator data.",
            expandChildren: false
        )
    ]

    static let blockedPathFragments = [
        "Keychains",
        "state.vscdb",
        "/Library/Application Support/Cursor/User",
        "/Library/Application Support/Code/User"
    ]
}

enum DiskProbe {
    static func current() -> DiskInfo {
        do {
            let values = try URL(fileURLWithPath: "/").resourceValues(forKeys: [
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeTotalCapacityKey
            ])
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let free = values.volumeAvailableCapacityForImportantUsage.map { Int64($0) } ?? 0
            return DiskInfo(total: total, used: max(total - free, 0), free: free)
        } catch {
            return DiskInfo()
        }
    }
}

enum FolderSizer {
    static func bytes(at path: String) -> Int64 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        process.arguments = ["-sk", path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
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
    var foundBytes: Int64
    var foundCount: Int
}

enum CacheScanner {
    static func scan(
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        onProgress: ((ScanProgress) -> Void)? = nil
    ) -> [CacheItem] {
        var jobs: [(name: String, path: String, category: CacheCategory, safety: CacheSafety, detail: String)] = []
        var seen = Set<String>()

        for entry in CacheCatalog.entries {
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
                        guard seen.insert(path).inserted, !isBlocked(path) else { continue }
                        jobs.append((
                            friendlyName(for: child.lastPathComponent, parent: entry),
                            path,
                            categoryOverride(for: child.lastPathComponent, fallback: entry.category),
                            entry.safety,
                            child.path
                        ))
                    }
                } else {
                    let path = (url.path as NSString).standardizingPath
                    if seen.insert(path).inserted, !isBlocked(path) {
                        jobs.append((entry.name, path, entry.category, entry.safety, entry.detail))
                    }
                }
            } else {
                let path = (url.path as NSString).standardizingPath
                if seen.insert(path).inserted, !isBlocked(path) {
                    jobs.append((entry.name, path, entry.category, entry.safety, entry.detail))
                }
            }
        }

        var items: [CacheItem] = []
        let total = max(jobs.count, 1)
        for (index, job) in jobs.enumerated() {
            onProgress?(ScanProgress(
                fraction: Double(index) / Double(total),
                label: "Measuring \(job.name)…",
                foundBytes: items.reduce(0) { $0 + $1.bytes },
                foundCount: items.count
            ))
            let size = FolderSizer.bytes(at: job.path)
            guard size >= 1_000_000 else { continue }
            items.append(CacheItem(
                id: UUID(),
                name: job.name,
                path: job.path,
                bytes: size,
                category: job.category,
                safety: job.safety,
                detail: job.detail
            ))
        }

        onProgress?(ScanProgress(
            fraction: 1,
            label: "Scan complete",
            foundBytes: items.reduce(0) { $0 + $1.bytes },
            foundCount: items.count
        ))

        return items.sorted { $0.bytes > $1.bytes }
    }

    private static func childItems(of url: URL, fallback: CatalogEntry, seen: inout Set<String>) -> [CacheItem] {
        let fm = FileManager.default
        guard let children = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            var items: [CacheItem] = []
            appendItem(path: url.path, name: fallback.name, category: fallback.category, safety: fallback.safety, detail: fallback.detail, into: &items, seen: &seen)
            return items
        }

        var items: [CacheItem] = []
        for child in children {
            let name = friendlyName(for: child.lastPathComponent, parent: fallback)
            appendItem(
                path: child.path,
                name: name,
                category: categoryOverride(for: child.lastPathComponent, fallback: fallback.category),
                safety: fallback.safety,
                detail: child.path,
                into: &items,
                seen: &seen
            )
        }
        return items
    }

    private static func appendItem(
        path: String,
        name: String,
        category: CacheCategory,
        safety: CacheSafety,
        detail: String,
        into items: inout [CacheItem],
        seen: inout Set<String>
    ) {
        let standardized = (path as NSString).standardizingPath
        guard seen.insert(standardized).inserted else { return }
        guard !isBlocked(standardized) else { return }
        let size = FolderSizer.bytes(at: standardized)
        guard size > 0 else { return }
        items.append(
            CacheItem(
                id: UUID(),
                name: name,
                path: standardized,
                bytes: size,
                category: category,
                safety: safety,
                detail: detail
            )
        )
    }

    private static func isBlocked(_ path: String) -> Bool {
        CacheCatalog.blockedPathFragments.contains { path.contains($0) }
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

    static func moveToTrash(_ path: String) throws {
        guard isAllowed(path) else {
            throw CleanError.blocked(path)
        }
        var resulting: NSURL?
        try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: &resulting)
    }

    enum CleanError: LocalizedError {
        case blocked(String)

        var errorDescription: String? {
            switch self {
            case .blocked(let path):
                return "Clearaer refused to delete a protected path: \(path)"
            }
        }
    }
}

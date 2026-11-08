import Foundation
import AppKit

/// Builds Storage Map slices so category totals track System Settings → Storage.
///
/// Observed on this Mac vs Settings:
/// - Documents ≈ everything in `$HOME` except `Library` / `.Trash` (~24.05 GB)
/// - Applications ≈ app bundles + `$HOME/Library` + `/Library/Application Support`
///   + `/Library/Frameworks` (~25.8 GB), excluding Developer / Messages folders
/// - Developer ≈ `/Library/Developer` + `~/Library/Developer` (thin; Homebrew stays System Data)
/// - Free / Used use DiskProbe’s “important” free (purgeable-aware), not raw APFS free
enum StorageMapProbe {
    struct Result {
        let slices: [MapSlice]
    }

    private static let home = FileManager.default.homeDirectoryForCurrentUser

    /// - Parameters:
    ///   - onProgress: 0…1 map phase progress + short label for the Overview ring.
    ///   - onAwaitingFinderAllow: Fired on the calling queue right before Finder Automation may prompt.
    static func measure(
        disk: DiskInfo,
        onProgress: ((Double, String) -> Void)? = nil,
        onAwaitingFinderAllow: (() -> Void)? = nil
    ) -> Result {
        let fm = FileManager.default
        func progress(_ fraction: Double, _ label: String) {
            onProgress?(min(1, max(0, fraction)), label)
        }

        progress(0.02, "Apps")
        // ── Applications ─────────────────────────────────────────────────────
        let applications = measureFolder("/Applications", timeout: 180)
        progress(0.12, "Apps")
        let systemApps = measureFolder("/System/Applications", timeout: 120)
        let userApps = measureFolder(home.appendingPathComponent("Applications").path, timeout: 60)
        let bundleTotal = applications + systemApps + userApps

        progress(0.22, "App data")
        let userLibraryRoot = home.appendingPathComponent("Library").path
        let userLibrary = measureFolder(userLibraryRoot, timeout: 240)
        let developerUser = measureFolder(home.appendingPathComponent("Library/Developer").path, timeout: 120)
        let messagesUser = measureFolder(home.appendingPathComponent("Library/Messages").path, timeout: 60)
            + measureFolder(home.appendingPathComponent("Library/Containers/com.apple.MobileSMS").path, timeout: 60)
        // Keep Apps / Developer / Messages mutually exclusive like System Settings.
        let libraryForApps = max(0, userLibrary - developerUser - messagesUser)

        let systemAppSupport = measureFolder("/Library/Application Support", timeout: 120)
        let frameworks = measureFolder("/Library/Frameworks", timeout: 120)

        progress(0.40, "Apps")
        var appKids = applicationChildren(limit: 12)
        appKids = reconcile(children: appKids, toTotal: bundleTotal, otherName: "Other apps")
        if libraryForApps > 1_000_000 {
            appKids.append(MapChild(name: "App Library data", bytes: libraryForApps))
        }
        if systemAppSupport > 1_000_000 {
            appKids.append(MapChild(name: "System app support", bytes: systemAppSupport))
        }
        if frameworks > 1_000_000 {
            appKids.append(MapChild(name: "Frameworks", bytes: frameworks))
        }
        appKids.sort { $0.bytes > $1.bytes }
        let appsTotal = bundleTotal + libraryForApps + systemAppSupport + frameworks

        progress(0.48, "Documents")
        // ── Documents (home minus Library / Trash — matches Settings ~24 GB) ─
        var documentKids: [MapChild] = []
        var documentsTotal: Int64 = 0
        if let names = try? fm.contentsOfDirectory(atPath: home.path) {
            for name in names {
                // Pictures → Photos category (System Settings), not Documents.
                if name == "Library" || name == ".Trash" || name == "Pictures" { continue }
                let path = home.appendingPathComponent(name).path
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: path, isDirectory: &isDir) else { continue }
                let bytes = measureFolder(path, timeout: isDir.boolValue ? 120 : 15)
                guard bytes > 0 else { continue }
                documentsTotal += bytes
                if bytes > 1_000_000 {
                    documentKids.append(MapChild(name: name, bytes: bytes))
                }
            }
        }
        documentKids.sort { $0.bytes > $1.bytes }
        if documentKids.count > 12 {
            let head = Array(documentKids.prefix(12))
            let rest = documentKids.dropFirst(12).reduce(Int64(0)) { $0 + $1.bytes }
            documentKids = head
            if rest > 1_000_000 {
                documentKids.append(MapChild(name: "Other files", bytes: rest))
            }
        }

        progress(0.70, "Developer")
        // ── Messages ─────────────────────────────────────────────────────────
        let messagesTotal = messagesUser
        let messagesKids: [MapChild] = messagesTotal > 1_000_000
            ? [MapChild(name: "Messages data", bytes: messagesTotal)]
            : []

        // ── Developer (Xcode / CLT only — not Homebrew) ───────────────────────
        let developerSystem = measureFolder("/Library/Developer", timeout: 180)
        let developerTotal = developerUser + developerSystem
        var developerKids: [MapChild] = []
        if developerUser > 1_000_000 {
            developerKids.append(MapChild(name: "User Developer", bytes: developerUser))
        }
        if developerSystem > 1_000_000 {
            developerKids.append(MapChild(name: "Command Line Tools / Xcode", bytes: developerSystem))
        }
        developerKids.sort { $0.bytes > $1.bytes }

        progress(0.82, "Photos")
        // ── Photos = ~/Pictures (Finder size; may prompt Automation Allow) ─
        let photosTotal = PhotosSizer.measure(onAwaitingAllow: onAwaitingFinderAllow)
        var mediaKids: [MapChild] = []
        if photosTotal > 0 {
            mediaKids.append(MapChild(name: "Pictures", bytes: photosTotal))
        }

        progress(0.92, "System")
        // ── Remainder → System Data (Homebrew, macOS, VM, Preboot, …) ────────
        let measuredUser = appsTotal + documentsTotal + messagesTotal + developerTotal + photosTotal
        let systemTotal = max(0, disk.used - measuredUser)
        let systemKids: [MapChild] = systemTotal > 0
            ? [MapChild(name: "macOS, Homebrew, and system data", bytes: systemTotal)]
            : []

        let colors: [String: NSColor] = [
            "Apps": Theme.mapApps,
            "Documents": Theme.mapDocuments,
            "Messages": Theme.mapICloud,
            "Developer": Theme.mapDeveloper,
            "Photos": Theme.mapPhotos,
            "System": Theme.mapSystem,
            "Free": Theme.mapFree
        ]

        // Order matches System Settings Storage bar.
        let order: [(String, Int64, [MapChild])] = [
            ("Apps", appsTotal, appKids),
            ("Documents", documentsTotal, documentKids),
            ("Messages", messagesTotal, messagesKids),
            ("Developer", developerTotal, developerKids),
            ("Photos", photosTotal, mediaKids),
            ("System", systemTotal, systemKids),
            ("Free", disk.free, [])
        ]

        let slices = order.compactMap { name, bytes, kids -> MapSlice? in
            guard bytes > 0 else { return nil }
            return MapSlice(
                name: name,
                bytes: bytes,
                color: colors[name] ?? Theme.mapOther,
                children: kids.filter { $0.bytes > 0 }
            )
        }
        progress(1, "Disk map")
        return Result(slices: slices)
    }

    private static func measureFolder(_ path: String, timeout: TimeInterval) -> Int64 {
        guard FileManager.default.fileExists(atPath: path) else { return 0 }
        return FolderSizer.bytes(at: path, timeout: timeout)
    }

    private static func reconcile(children: [MapChild], toTotal total: Int64, otherName: String) -> [MapChild] {
        guard total > 0 else { return children.filter { $0.bytes > 0 } }
        var kids = children.filter { $0.bytes > 0 }.sorted { $0.bytes > $1.bytes }
        let sum = kids.reduce(Int64(0)) { $0 + $1.bytes }
        if sum < total {
            let gap = total - sum
            if let idx = kids.firstIndex(where: { $0.name == otherName }) {
                kids[idx] = MapChild(name: otherName, bytes: kids[idx].bytes + gap)
            } else if gap > 1_000_000 {
                kids.append(MapChild(name: otherName, bytes: gap))
            }
        } else if sum > total {
            let scale = Double(total) / Double(sum)
            kids = kids.map { MapChild(name: $0.name, bytes: max(1_000_000, Int64(Double($0.bytes) * scale))) }
        }
        return kids.sorted { $0.bytes > $1.bytes }
    }

    private static func applicationChildren(limit: Int) -> [MapChild] {
        let roots = [
            "/Applications",
            "/System/Applications",
            home.appendingPathComponent("Applications").path
        ]
        var sizes: [String: Int64] = [:]
        let fm = FileManager.default
        for root in roots {
            guard let items = try? fm.contentsOfDirectory(atPath: root) else { continue }
            for name in items {
                if name.hasPrefix(".") { continue }
                let path = (root as NSString).appendingPathComponent(name)
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { continue }
                let bytes = FolderSizer.bytes(at: path, timeout: 60)
                guard bytes > 1_000_000 else { continue }
                let display = name.hasSuffix(".app")
                    ? (name as NSString).deletingPathExtension
                    : name
                sizes[display, default: 0] += bytes
            }
        }
        let sorted = sizes.sorted { $0.value > $1.value }
        guard !sorted.isEmpty else { return [] }
        var kids = Array(sorted.prefix(limit)).map { MapChild(name: $0.key, bytes: $0.value) }
        let rest = sorted.dropFirst(limit).reduce(Int64(0)) { $0 + $1.value }
        if rest > 1_000_000 {
            kids.append(MapChild(name: "Other apps", bytes: rest))
        }
        return kids
    }
}

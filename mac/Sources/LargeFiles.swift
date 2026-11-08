import Foundation
import AppKit
import UniformTypeIdentifiers

/// Finds large, infrequently opened files under the user home folder.
enum LargeFilesProbe {
    private static let maxResults = 40
    /// Skip files opened in the last two weeks — keep “old” files without emptying the list.
    private static let recentDays = 14
    private static let skipNameFragments = [
        "/Library/Caches/",
        "/Library/Logs/",
        "/.Trash/",
        "/node_modules/",
        "/.git/",
        "/DerivedData/",
        "/CoreSimulator/",
        "/iClearer.app/"
    ]

    static func scan(minBytes: Int64, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [LargeFileItem] {
        var pathSet = Set(spotlightPaths(minBytes: minBytes, home: home))
        for path in walkFallbackPaths(minBytes: minBytes, home: home) {
            pathSet.insert(path)
        }

        let recentCutoff = Date().addingTimeInterval(-TimeInterval(recentDays) * 24 * 60 * 60)
        var found: [LargeFileItem] = []
        let fm = FileManager.default

        for path in pathSet {
            if shouldSkip(path) { continue }
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: path, isDirectory: &isDir) else { continue }

            let url = URL(fileURLWithPath: path)
            let bytes: Int64
            if isDir.boolValue {
                guard isPackage(url) else { continue }
                bytes = FolderSizer.bytes(at: path, timeout: 3)
            } else {
                bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) } ?? 0
            }
            guard bytes >= minBytes else { continue }

            let lastOpened = lastOpenedDate(for: url) ?? modificationDate(for: url) ?? Date.distantPast
            if lastOpened > recentCutoff { continue }

            found.append(LargeFileItem(
                id: LargeFileItem.stableID(for: path),
                name: url.lastPathComponent,
                path: displayParent(of: path, home: home.path),
                fullPath: path,
                bytes: bytes,
                ageLabel: ageLabel(since: lastOpened),
                kind: kind(for: url)
            ))
        }

        return found
            .sorted { $0.bytes > $1.bytes }
            .prefix(maxResults)
            .map { $0 }
    }

    private static func spotlightPaths(minBytes: Int64, home: URL) -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = [
            "-onlyin", home.path,
            "kMDItemFSSize >= \(minBytes)"
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            let deadline = Date().addingTimeInterval(12)
            while process.isRunning {
                if Date() > deadline {
                    process.terminate()
                    break
                }
                Thread.sleep(forTimeInterval: 0.05)
            }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8) ?? ""
            return text
                .split(whereSeparator: \.isNewline)
                .map(String.init)
                .filter { !$0.isEmpty }
        } catch {
            return []
        }
    }

    /// Direct walk of common user folders when Spotlight returns little/nothing.
    private static func walkFallbackPaths(minBytes: Int64, home: URL) -> [String] {
        let roots = [
            home.appendingPathComponent("Downloads"),
            home.appendingPathComponent("Documents"),
            home.appendingPathComponent("Desktop"),
            home.appendingPathComponent("Movies"),
            home.appendingPathComponent("Music"),
            home.appendingPathComponent("Pictures"),
            home.appendingPathComponent("Parallels"),
            home.appendingPathComponent("VirtualBox VMs"),
            home.appendingPathComponent("Library/Application Support")
        ]
        var out: [String] = []
        let fm = FileManager.default
        for root in roots {
            guard let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .isPackageKey, .fileSizeKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            var checked = 0
            while let url = enumerator.nextObject() as? URL {
                checked += 1
                if checked > 8_000 { break }
                if shouldSkip(url.path) { continue }

                let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .isPackageKey, .fileSizeKey])
                if values?.isPackage == true {
                    out.append(url.path)
                    enumerator.skipDescendants()
                    continue
                }
                if values?.isRegularFile == true {
                    let size = Int64(values?.fileSize ?? 0)
                    if size >= minBytes {
                        out.append(url.path)
                    }
                }
            }
        }
        return out
    }

    private static func shouldSkip(_ path: String) -> Bool {
        skipNameFragments.contains { path.contains($0) }
    }

    private static func isPackage(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let packages: Set<String> = [
            "app", "bundle", "framework", "plugin", "kext",
            "fcpbundle", "imovieproject", "photoslibrary", "photolibrary",
            "pvm", "vmwarevm", "sparsebundle", "pkg", "xpc",
            "playground", "xcodeproj", "xcworkspace", "scptd"
        ]
        if packages.contains(ext) { return true }
        return (try? url.resourceValues(forKeys: [.isPackageKey]).isPackage) == true
    }

    private static func lastOpenedDate(for url: URL) -> Date? {
        if let values = try? url.resourceValues(forKeys: [.contentAccessDateKey]),
           let date = values.contentAccessDate {
            return date
        }
        let item = NSMetadataItem(url: url)
        if let date = item?.value(forAttribute: NSMetadataItemLastUsedDateKey) as? Date {
            return date
        }
        return nil
    }

    private static func modificationDate(for url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
    }

    private static func displayParent(of path: String, home: String) -> String {
        let parent = (path as NSString).deletingLastPathComponent
        if parent == home { return "~" }
        if parent.hasPrefix(home + "/") {
            return "~" + parent.dropFirst(home.count)
        }
        return parent
    }

    static func ageLabel(since date: Date) -> String {
        let seconds = max(0, Date().timeIntervalSince(date))
        let days = Int(seconds / 86_400)
        if days < 45 {
            let months = max(1, Int((Double(days) / 30.0).rounded()))
            return months == 1 ? "1 month" : "\(months) months"
        }
        let months = Int((Double(days) / 30.4).rounded())
        if months < 18 {
            return months <= 1 ? "1 month" : "\(months) months"
        }
        let years = max(1, Int((Double(days) / 365.0).rounded()))
        return years == 1 ? "1 year" : "\(years) years"
    }

    static func kind(for url: URL) -> String {
        let name = url.lastPathComponent.lowercased()
        let ext = url.pathExtension.lowercased()
        if ["pvm", "vmwarevm", "vdi", "vmdk", "qcow2", "vbox"].contains(ext) {
            return "Virtual machine"
        }
        if ["fcpbundle", "imovieproject", "prproj", "drp"].contains(ext) {
            return "Video project"
        }
        if name.contains("screen recording") {
            return "Screen recording"
        }
        if ["iso", "dmg", "img", "toast", "cdr"].contains(ext) {
            return "Disk image"
        }
        if ["zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz"].contains(ext) {
            return "Archive"
        }
        if ["xip", "pkg", "mpkg"].contains(ext) {
            return "Installer"
        }
        if ["aif", "aiff", "wav", "flac", "caf"].contains(ext) {
            return "Audio recording"
        }
        if ["mov", "mp4", "m4v", "mkv", "avi"].contains(ext) {
            return "Video"
        }
        if ["psd", "psb", "sketch", "fig"].contains(ext) {
            return "Design file"
        }
        if ext == "app" { return "Application" }
        if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            if type.conforms(to: .movie) { return "Video" }
            if type.conforms(to: .audio) { return "Audio recording" }
            if type.conforms(to: .image) { return "Image" }
            if type.conforms(to: .archive) { return "Archive" }
            if type.conforms(to: .diskImage) { return "Disk image" }
            if let desc = type.localizedDescription, !desc.isEmpty {
                return desc.prefix(1).uppercased() + desc.dropFirst()
            }
        }
        return "Large file"
    }
}

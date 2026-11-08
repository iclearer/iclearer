import Foundation
import AppKit

/// Lists apps the way Finder’s Applications folder does:
/// `/Applications` ∪ `/System/Applications` ∪ `~/Applications`,
/// plus leftover folders (Python 3.x, Utilities) and nested apps inside them.
enum AppsProbe {
    private static func roots(home: URL) -> [URL] {
        [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            home.appendingPathComponent("Applications")
        ]
    }

    static func scan(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [AppLeftover] {
        let fm = FileManager.default
        var candidates: [(key: String, url: URL, isFolder: Bool)] = []

        for root in roots(home: home) {
            guard let kids = try? fm.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in kids {
                let name = url.lastPathComponent
                if name.hasPrefix(".") { continue }

                if name.hasSuffix(".app") {
                    if name == "iClearer.app" { continue }
                    let key = "app:" + name
                    // Prefer Data-volume /Applications over /System/Applications.
                    if let idx = candidates.firstIndex(where: { $0.key == key }) {
                        if candidates[idx].url.path.hasPrefix("/Applications/"),
                           url.path.hasPrefix("/System/Applications/") {
                            continue
                        }
                        candidates[idx] = (key, url, false)
                    } else {
                        candidates.append((key, url, false))
                    }
                    continue
                }

                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { continue }
                guard root.path == "/Applications"
                    || root.path == home.appendingPathComponent("Applications").path
                else { continue }

                candidates.append(("folder:" + name, url, true))

                if let nested = try? fm.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                ) {
                    for child in nested where child.lastPathComponent.hasSuffix(".app") {
                        let n = child.lastPathComponent
                        let key = "app:" + n
                        if !candidates.contains(where: { $0.key == key }) {
                            candidates.append((key, child, false))
                        }
                    }
                }
            }
        }

        // Size in parallel. Symlinks (Safari, OpenCore-Patcher, …) must be resolved
        // before `du` — otherwise size is 0 and the app was previously dropped.
        var sized = Array<AppLeftover?>(repeating: nil, count: candidates.count)
        DispatchQueue.concurrentPerform(iterations: candidates.count) { i in
            let item = candidates[i]
            let sizeURL = item.url.resolvingSymlinksInPath()
            let bytes = FolderSizer.bytes(at: sizeURL.path, timeout: 8)
            let display: String
            if item.isFolder {
                display = item.url.lastPathComponent
            } else {
                display = (item.url.lastPathComponent as NSString).deletingPathExtension
            }
            sized[i] = AppLeftover(
                id: LargeFileItem.stableID(for: item.url.path),
                name: display,
                appBytes: max(bytes, 0),
                leftoverBytes: 0,
                lastUsed: lastOpenedLabel(for: sizeURL),
                bundlePath: item.url.path
            )
        }

        return sized.compactMap { $0 }.sorted { $0.appBytes > $1.appBytes }
    }

    private static func lastOpenedLabel(for url: URL) -> String {
        if let date = bestLastOpened(for: url) {
            return AppFormat.openedAgo(since: date)
        }
        return "a while"
    }

    private static func bestLastOpened(for url: URL) -> Date? {
        // Spotlight last-used only — avoid slow resource-value fallbacks during scan.
        if let item = NSMetadataItem(url: url),
           let used = item.value(forAttribute: NSMetadataItemLastUsedDateKey) as? Date,
           used.timeIntervalSince1970 > 1_104_537_600,
           used <= Date().addingTimeInterval(86_400) {
            return used
        }
        return nil
    }
}

import Foundation
import AppKit

final class AppState {
    static let shared = AppState()

    private(set) var screen: AppScreen = .overview
    private(set) var items: [CacheItem] = []
    private(set) var selected = Set<UUID>()
    private(set) var disk = DiskProbe.current()
    private(set) var isScanning = false
    private(set) var isCleaning = false
    private(set) var scanProgress = ScanProgress(fraction: 0, label: "Ready", foundBytes: 0, foundCount: 0)
    private(set) var selectedItemID: UUID?
    private(set) var filterGroup: CleanGroup? = nil
    private(set) var searchQuery = ""
    private(set) var history: [HistoryEntry] = []
    private(set) var lastTrash: [TrashRecord] = []
    private(set) var lastCleanupBytes: Int64 = 0
    private(set) var sidebarHidden = false
    private(set) var inspectorHidden = false
    private(set) var largeFiles: [LargeFileItem] = []
    private(set) var apps: [AppLeftover] = []
    private(set) var largeFileSelection = Set<UUID>()
    private(set) var toastMessage: String?
    private(set) var toastShowsUndo = false
    /// Real disk map from `StorageMapProbe` (nil until first measure finishes).
    private(set) var storageMapSlices: [MapSlice]?
    private(set) var isMeasuringStorageMap = false
    private var storageMapGeneration = 0
    /// Combined scan: junk leftovers + disk map must both finish.
    private var junkScanFraction = 0.0
    private var mapScanFraction = 0.0
    private var junkScanFinished = false
    private var mapScanFinished = false
    private var scanFoundBytes: Int64 = 0
    private var scanFoundCount = 0
    private var mapPhaseLabel = "Disk map"
    private var awaitingFinderAllow = false

    var license: LicenseState { LicenseStore.current }
    var isPro: Bool { license.isPro }
    var isBusy: Bool { isScanning || isCleaning }

    var visibleItems: [CacheItem] {
        items.filter { item in
            if let filterGroup, item.group != filterGroup { return false }
            if searchQuery.isEmpty { return true }
            let q = searchQuery.lowercased()
            return item.name.lowercased().contains(q)
                || item.genericName.lowercased().contains(q)
                || item.path.lowercased().contains(q)
        }
        // Everyday block first, then Builders — never interleaved.
        .sorted { a, b in
            if a.group != b.group {
                return a.group == .everyday && b.group == .builders
            }
            return a.bytes > b.bytes
        }
    }

    /// True when any checked item is Ask first (shows Clean backup warning).
    var hasAskFirstSelected: Bool {
        selectedItems.contains { $0.safety == .askFirst }
    }

    var selectedItems: [CacheItem] {
        items.filter { selected.contains($0.id) }
    }

    var selectedBytes: Int64 {
        selectedItems.reduce(0) { $0 + $1.bytes }
    }

    var totalFoundBytes: Int64 {
        items.reduce(0) { $0 + $1.bytes }
    }

    var safeBytes: Int64 {
        items.filter { $0.safety == .safe }.reduce(0) { $0 + $1.bytes }
    }

    var selectedItem: CacheItem? {
        guard let selectedItemID else { return visibleItems.first }
        return items.first { $0.id == selectedItemID } ?? visibleItems.first
    }

    private let historyKey = "iclearer.history.v1"
    private let scanCacheKey = "iclearer.scanCache.v1"
    /// Keep last scan for relaunches so rebuilds don’t force Scan → Scan → Scan.
    private let scanCacheMaxAge: TimeInterval = 48 * 60 * 60

    private init() {
        loadHistory()
        loadScanCache()
        disk = DiskProbe.current()
        if storageMapSlices != nil {
            patchStorageMapDiskTotals()
        }
    }

    func notify() {
        NotificationCenter.default.post(name: .iClearerStateChanged, object: nil)
    }

    func navigate(_ screen: AppScreen) {
        self.screen = screen
        if screen == .builders {
            filterGroup = .builders
        } else if screen == .clean {
            filterGroup = nil
        }
        if screen == .storageMap {
            ensureStorageMap()
        }
        notify()
    }

    func setSearch(_ query: String) {
        searchQuery = query
        notify()
    }

    func setFilter(_ group: CleanGroup?) {
        filterGroup = group
        notify()
    }

    func selectItem(_ id: UUID?) {
        selectedItemID = id
        notify()
    }

    func toggleSelection(_ id: UUID) {
        if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
        selectedItemID = id
        notify()
    }

    func selectSafeOnly() {
        selected = Set(items.filter { $0.safety == .safe }.map(\.id))
        notify()
    }

    func selectAllVisible() {
        selected.formUnion(visibleItems.map(\.id))
        notify()
    }

    func clearPicks() {
        selected.removeAll()
        notify()
    }

    func toggleSidebar() {
        sidebarHidden.toggle()
        notify()
    }

    func toggleInspector() {
        inspectorHidden.toggle()
        notify()
    }

    func showToast(_ message: String, undo: Bool = false) {
        toastMessage = message
        toastShowsUndo = undo
        NotificationCenter.default.post(
            name: .iClearerToast,
            object: nil,
            userInfo: ["message": message, "undo": undo]
        )
    }

    func showSheet(_ kind: SheetKind, reason: String? = nil) {
        var info: [String: Any] = ["kind": kind.rawValue]
        if let reason { info["reason"] = reason }
        NotificationCenter.default.post(name: .iClearerShowSheet, object: nil, userInfo: info)
    }

    func showQuickLook(_ file: LargeFileItem) {
        NotificationCenter.default.post(
            name: .iClearerQuickLook,
            object: nil,
            userInfo: ["id": file.id.uuidString]
        )
    }

    var largeFilesBytes: Int64 {
        largeFiles.reduce(0) { $0 + $1.bytes }
    }

    /// Sum of listed Apps rows without double-counting nested items
    /// (e.g. IDLE.app inside “Python 3.12” folder).
    var appsBytes: Int64 {
        let paths = apps.map(\.bundlePath)
        return apps.reduce(0) { sum, app in
            let nested = paths.contains {
                $0 != app.bundlePath && app.bundlePath.hasPrefix($0 + "/")
            }
            return nested ? sum : sum + app.appBytes
        }
    }

    func visibleApps() -> [AppLeftover] {
        guard !searchQuery.isEmpty else { return apps }
        let q = searchQuery.lowercased()
        return apps.filter { $0.name.lowercased().contains(q) }
    }

    /// Six Builders tiles (prototype `bdl`) — sizes are sums of Clean → Builders rows.
    func builderTiles() -> [(proTitle: String, freeKind: String, bytes: Int64)] {
        var totals = [Int64](repeating: 0, count: BuilderBucket.allCases.count)
        for item in buildersItems() {
            guard let bucket = BuilderBucket.classify(item) else { continue }
            totals[bucket.rawValue] += item.bytes
        }
        return BuilderBucket.allCases.map { bucket in
            (bucket.proTitle, bucket.freeKind, totals[bucket.rawValue])
        }
    }

    func visibleLargeFiles() -> [LargeFileItem] {
        let base = isPro ? largeFiles : Array(largeFiles.prefix(5))
        guard !searchQuery.isEmpty else { return base }
        let q = searchQuery.lowercased()
        return base.filter {
            $0.name.lowercased().contains(q)
                || $0.kind.lowercased().contains(q)
                || $0.path.lowercased().contains(q)
        }
    }

    func refreshDisk() {
        disk = DiskProbe.current()
        notify()
    }

    func startScan() {
        guard !isBusy else { return }
        isScanning = true
        items = []
        selected = []
        selectedItemID = nil
        largeFiles = []
        largeFileSelection.removeAll()
        // Keep previous Apps list visible until the apps pass finishes (avoids empty Apps mid-scan).
        junkScanFraction = 0
        mapScanFraction = 0
        junkScanFinished = false
        mapScanFinished = false
        scanFoundBytes = 0
        scanFoundCount = 0
        mapPhaseLabel = "Disk map"
        awaitingFinderAllow = false
        scanProgress = ScanProgress(fraction: 0, label: "Starting scan…", foundBytes: 0, foundCount: 0)
        refreshDisk()
        publishCombinedScanProgress(forceNotify: true)

        // Disk map runs in parallel; scan stays open until both finish.
        beginStorageMapMeasure(forCombinedScan: true)

        let license = self.license
        let minLargeBytes = Int64(max(50, license.largeFileMinMB)) * 1_000_000
        DispatchQueue.global(qos: .userInitiated).async {
            var lastNotified = -1.0
            let group = DispatchGroup()
            var foundJunk: [CacheItem] = []
            var foundLarge: [LargeFileItem] = []
            var foundApps: [AppLeftover] = []

            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                foundJunk = CacheScanner.scan(
                    includeEveryday: license.scanEveryday,
                    includeBuilders: license.scanBuilders,
                    includeBackups: license.scanBackups,
                    protectedPaths: license.protectedPaths
                ) { progress in
                    DispatchQueue.main.async {
                        self.junkScanFraction = min(0.88, progress.fraction * 0.88)
                        self.scanFoundBytes = progress.foundBytes
                        self.scanFoundCount = progress.foundCount
                        let combined = self.combinedScanFraction()
                        if combined - lastNotified >= 0.01 || progress.fraction >= 1 {
                            lastNotified = combined
                            self.publishCombinedScanProgress(forceNotify: true)
                        } else {
                            self.publishCombinedScanProgress(forceNotify: false)
                        }
                    }
                }
                group.leave()
            }

            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                foundLarge = LargeFilesProbe.scan(minBytes: minLargeBytes)
                DispatchQueue.main.async {
                    self.junkScanFraction = max(self.junkScanFraction, 0.93)
                    self.publishCombinedScanProgress(forceNotify: true)
                }
                group.leave()
            }

            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                foundApps = AppsProbe.scan()
                DispatchQueue.main.async {
                    // Publish apps as soon as they’re ready so Apps tab isn’t empty after Rescan.
                    self.apps = foundApps
                    self.junkScanFraction = max(self.junkScanFraction, 0.97)
                    self.publishCombinedScanProgress(forceNotify: true)
                    self.notify()
                }
                group.leave()
            }

            group.wait()
            DispatchQueue.main.async {
                self.items = foundJunk
                self.largeFiles = foundLarge
                self.apps = foundApps
                // Safe start ticked; Ask first unticked
                self.selected = Set(foundJunk.filter { $0.safety == .safe }.map(\.id))
                self.selectedItemID = self.selected.first ?? foundJunk.first?.id
                let totalFound = foundJunk.reduce(Int64(0)) { $0 + $1.bytes }
                self.scanFoundBytes = totalFound
                self.scanFoundCount = max(self.scanFoundCount, foundJunk.count)
                self.junkScanFraction = 1
                self.junkScanFinished = true
                self.publishCombinedScanProgress(forceNotify: true)
                self.finishCombinedScanIfReady()
            }
        }
    }

    /// Starts a background measure of real Apps / Photos / Documents / … sizes.
    func ensureStorageMap() {
        if storageMapSlices != nil || isMeasuringStorageMap || isScanning { return }
        refreshStorageMap(force: false)
    }

    private var isScanningLargeFiles = false

    /// Fills Large & Old Files when the list is empty (e.g. older scan cache).
    func ensureLargeFiles() {
        guard largeFiles.isEmpty, !isScanning, !isScanningLargeFiles else { return }
        isScanningLargeFiles = true
        let minBytes = Int64(max(50, license.largeFileMinMB)) * 1_000_000
        notify()
        DispatchQueue.global(qos: .userInitiated).async {
            let found = LargeFilesProbe.scan(minBytes: minBytes)
            DispatchQueue.main.async {
                self.largeFiles = found
                self.isScanningLargeFiles = false
                self.saveScanCache()
                self.notify()
            }
        }
    }

    private var isScanningApps = false

    func ensureApps(force: Bool = false) {
        // Rescan refreshes apps in startScan; force refreshes a stale/incomplete list.
        guard force || apps.isEmpty, !isScanning, !isScanningApps else { return }
        isScanningApps = true
        notify()
        DispatchQueue.global(qos: .userInitiated).async {
            let found = AppsProbe.scan()
            DispatchQueue.main.async {
                self.apps = found
                self.isScanningApps = false
                self.saveScanCache()
                self.notify()
            }
        }
    }

    func refreshStorageMap(force: Bool) {
        if isMeasuringStorageMap && !force { return }
        if !force, storageMapSlices != nil { return }
        beginStorageMapMeasure(forCombinedScan: false)
    }

    private func beginStorageMapMeasure(forCombinedScan: Bool) {
        isMeasuringStorageMap = true
        if forCombinedScan {
            mapScanFinished = false
            mapScanFraction = 0
        }
        storageMapGeneration += 1
        let generation = storageMapGeneration
        let diskSnapshot = DiskProbe.current()
        disk = diskSnapshot
        notify()

        DispatchQueue.global(qos: .userInitiated).async {
            let result = StorageMapProbe.measure(
                disk: diskSnapshot,
                onProgress: { fraction, label in
                    DispatchQueue.main.async {
                        guard generation == self.storageMapGeneration else { return }
                        self.mapScanFraction = fraction
                        self.mapPhaseLabel = label
                        if self.isScanning {
                            self.publishCombinedScanProgress(forceNotify: true)
                        } else {
                            self.notify()
                        }
                    }
                },
                onAwaitingFinderAllow: {
                    DispatchQueue.main.async {
                        guard generation == self.storageMapGeneration else { return }
                        self.awaitingFinderAllow = true
                        if self.isScanning {
                            self.publishCombinedScanProgress(forceNotify: true)
                        }
                        self.showToast("If macOS asks to control Finder, click Allow — needed for Photos size.")
                    }
                }
            )
            DispatchQueue.main.async {
                guard generation == self.storageMapGeneration else { return }
                self.storageMapSlices = result.slices
                self.isMeasuringStorageMap = false
                self.mapScanFraction = 1
                self.mapScanFinished = true
                self.awaitingFinderAllow = false
                if self.isScanning {
                    self.publishCombinedScanProgress(forceNotify: true)
                    self.finishCombinedScanIfReady()
                } else {
                    self.notify()
                }
            }
        }
    }

    private func combinedScanFraction() -> Double {
        // Leftovers scan is most of the bar; disk map fills the rest.
        let value = junkScanFraction * 0.78 + mapScanFraction * 0.22
        if junkScanFinished && mapScanFinished { return 1 }
        // Never show 100% until both halves are done.
        return min(0.99, value)
    }

    private func publishCombinedScanProgress(forceNotify: Bool) {
        let fraction = combinedScanFraction()
        var label = "Scanning your Mac…"
        if junkScanFinished && !mapScanFinished {
            label = "Finishing disk map…"
        } else if !junkScanFinished && mapScanFraction > 0.05 && mapScanFraction < 1 {
            label = "Scanning your Mac…"
        }
        let hint: String?
        if awaitingFinderAllow {
            hint = "macOS may ask to control Finder — click Allow so Photos can be sized."
        } else if junkScanFinished && !mapScanFinished {
            hint = "Mapping \(mapPhaseLabel)…"
        } else if !mapScanFinished && mapScanFraction > 0 {
            hint = "\(AppFormat.count(scanFoundCount)) items checked · \(AppFormat.bytes(scanFoundBytes)) found · disk map \(Int((mapScanFraction * 100).rounded()))%"
        } else {
            hint = nil
        }
        scanProgress = ScanProgress(
            fraction: fraction,
            label: label,
            foundBytes: scanFoundBytes,
            foundCount: scanFoundCount,
            hint: hint
        )
        if forceNotify { notify() }
    }

    private func finishCombinedScanIfReady() {
        guard isScanning, junkScanFinished, mapScanFinished else { return }
        isScanning = false
        awaitingFinderAllow = false
        refreshDisk()
        patchStorageMapDiskTotals()
        scanProgress = ScanProgress(
            fraction: 1,
            label: items.isEmpty ? "No large caches found" : "Scan complete",
            foundBytes: scanFoundBytes,
            foundCount: scanFoundCount,
            hint: nil
        )
        saveScanCache()
        notify()
    }

    /// After a junk scan, refresh only the Free slice from DiskProbe so we don’t
    /// kick off a second full folder walk.
    private func patchStorageMapDiskTotals() {
        guard var slices = storageMapSlices, !slices.isEmpty else { return }
        let free = max(0, disk.free)
        if let idx = slices.firstIndex(where: { $0.name == "Free" }) {
            slices[idx] = MapSlice(
                name: "Free",
                bytes: free,
                color: slices[idx].color,
                children: []
            )
        } else if free > 0 {
            slices.append(MapSlice(name: "Free", bytes: free, color: Theme.mapFree, children: []))
        }
        storageMapSlices = slices
    }

    func protectPath(_ path: String) {
        LicenseStore.update {
            if !$0.protectedPaths.contains(path) {
                $0.protectedPaths.append(path)
            }
        }
        if let item = items.first(where: { $0.path == path }) {
            selected.remove(item.id)
            items.removeAll { $0.id == item.id }
        }
        showToast("Protected. iClearer will skip it from now on.")
        notify()
    }

    func unprotectPath(_ path: String) {
        LicenseStore.update {
            $0.protectedPaths.removeAll { $0 == path }
        }
        notify()
    }

    /// Returns nil if cleanup may proceed, otherwise an upgrade reason or ask-first prompt tag.
    func cleanupGate() -> CleanupGate {
        let chosen = selectedItems
        guard !chosen.isEmpty else { return .empty }
        let bytes = selectedBytes
        if !isPro && bytes > license.remainingFreeBytes {
            return .needsUpgrade("Your selection is \(AppFormat.bytes(bytes)). The free plan has \(AppFormat.bytes(license.remainingFreeBytes)) of cleanup left.")
        }
        let askCount = chosen.filter { $0.safety == .askFirst }.count
        if askCount > 0 {
            return .needsAskConfirm(askCount)
        }
        return .ready
    }

    enum CleanupGate {
        case empty
        case needsUpgrade(String)
        case needsAskConfirm(Int)
        case ready
    }

    func performCleanup(acknowledgedAskFirst: Bool = false, completion: (() -> Void)? = nil) {
        switch cleanupGate() {
        case .empty:
            completion?()
            return
        case .needsUpgrade(let reason):
            showSheet(.upgrade, reason: reason)
            completion?()
            return
        case .needsAskConfirm where !acknowledgedAskFirst:
            completion?()
            return
        case .needsAskConfirm, .ready:
            break
        }

        let chosen = selectedItems
        guard !chosen.isEmpty else {
            completion?()
            return
        }
        isCleaning = true
        notify()

        DispatchQueue.global(qos: .userInitiated).async {
            var failures: [String] = []
            var records: [TrashRecord] = []
            var freed: Int64 = 0
            var names: [String] = []

            for item in chosen {
                do {
                    if let trashURL = try CacheCleaner.moveToTrash(item.path) {
                        records.append(TrashRecord(
                            originalPath: item.path,
                            trashURL: trashURL,
                            bytes: item.bytes,
                            name: item.name
                        ))
                        freed += item.bytes
                        // Always store the real cleaned name — History (Pro) must match what went to Trash.
                        names.append(item.name)
                    }
                } catch {
                    failures.append("\(item.name): \(error.localizedDescription)")
                }
            }

            DispatchQueue.main.async {
                let removedIDs = Set(records.map { record in
                    chosen.first(where: { $0.path == record.originalPath })?.id
                }.compactMap { $0 })
                self.items.removeAll { removedIDs.contains($0.id) }
                self.selected.subtract(removedIDs)
                LicenseStore.recordCleanup(bytes: freed)
                self.recordCleanupHistory(records: records, names: names, freed: freed)
                self.isCleaning = false
                self.refreshDisk()
                self.notify()
                self.showToast("Moved \(AppFormat.bytes(freed)) to the Trash.", undo: true)

                if !failures.isEmpty {
                    let alert = NSAlert()
                    alert.messageText = "Some items could not be deleted"
                    alert.informativeText = failures.joined(separator: "\n")
                    alert.runModal()
                }
                completion?()
            }
        }
    }

    func undoLastCleanup() {
        guard !lastTrash.isEmpty else {
            showToast("Nothing to undo.")
            return
        }
        // Undo restores the most recent history entry that still matches lastTrash.
        if let entry = history.first(where: { !$0.restored }) {
            restoreHistoryEntry(entry.id, fromUndo: true)
            return
        }
        restoreTrashRecords(lastTrash, bytes: lastCleanupBytes, entryID: nil, fromUndo: true)
    }

    /// Puts a History cleanup back from the Trash onto the Mac.
    func restoreHistoryEntry(_ id: UUID, fromUndo: Bool = false) {
        guard let idx = history.firstIndex(where: { $0.id == id }) else { return }
        guard !history[idx].restored else {
            showToast("Already restored.")
            return
        }
        if !isPro && !fromUndo {
            showSheet(.upgrade, reason: "History with restore is part of iClearer. You can still Undo your last cleanup for free.")
            return
        }

        var records = history[idx].trashRecords()
        // Older entries / emptied Trash: try to locate by name under ~/.Trash.
        if records.isEmpty || records.contains(where: { !FileManager.default.fileExists(atPath: $0.trashURL.path) }) {
            records = history[idx].paths.compactMap { original -> TrashRecord? in
                if let existing = records.first(where: {
                    $0.originalPath == original && FileManager.default.fileExists(atPath: $0.trashURL.path)
                }) {
                    return existing
                }
                guard let trashURL = CacheCleaner.findInTrash(originalPath: original) else { return nil }
                return TrashRecord(
                    originalPath: original,
                    trashURL: trashURL,
                    bytes: 0,
                    name: (original as NSString).lastPathComponent
                )
            }
        }

        guard !records.isEmpty else {
            showToast("Those items are no longer in the Trash. Empty Trash may have removed them.")
            return
        }
        restoreTrashRecords(records, bytes: history[idx].bytes, entryID: id, fromUndo: fromUndo)
    }

    private func restoreTrashRecords(
        _ records: [TrashRecord],
        bytes: Int64,
        entryID: UUID?,
        fromUndo: Bool
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            var restored = 0
            var missing = 0
            for record in records {
                guard FileManager.default.fileExists(atPath: record.trashURL.path) else {
                    missing += 1
                    continue
                }
                do {
                    try CacheCleaner.restoreFromTrash(record)
                    restored += 1
                } catch {
                    missing += 1
                }
            }
            DispatchQueue.main.async {
                if restored > 0 {
                    // Prototype removes the row after restore.
                    if let entryID {
                        self.history.removeAll { $0.id == entryID }
                    } else if fromUndo, !self.history.isEmpty {
                        self.history.removeFirst()
                    }
                    self.saveHistory()
                    if fromUndo || self.lastTrash.map(\.originalPath) == records.map(\.originalPath) {
                        self.lastTrash = []
                        self.lastCleanupBytes = 0
                    }
                    self.showToast("Restored to the original locations · \(AppFormat.bytes(bytes)).")
                    self.startScan()
                } else if missing > 0 {
                    self.showToast("Those items are no longer in the Trash.")
                } else {
                    self.showToast("Could not restore from Trash.")
                }
                self.notify()
            }
        }
    }

    /// Saves a cleanup into History and arms free Undo for the last batch.
    /// `names` must be the real items that landed in Trash (same order as `records`).
    func recordCleanupHistory(records: [TrashRecord], names: [String], freed: Int64) {
        guard freed > 0, !records.isEmpty else { return }
        // Only keep names that correspond to successfully trashed records.
        let realNames: [String] = {
            if names.count == records.count { return names }
            return records.map(\.name)
        }()
        lastTrash = records
        lastCleanupBytes = freed
        let summary = realNames.prefix(2).joined(separator: ", ")
            + (realNames.count > 2 ? ", \(realNames.count - 2) more" : "")
        let entry = HistoryEntry(
            bytes: freed,
            summary: summary.isEmpty ? "Cleanup" : summary,
            paths: records.map(\.originalPath),
            trashPaths: records.map { $0.trashURL.path },
            names: realNames
        )
        history.insert(entry, at: 0)
        if history.count > 100 { history = Array(history.prefix(100)) }
        saveHistory()
        notify()
    }

    func mapSlices() -> [MapSlice] {
        // Prefer real measured map from this Mac.
        if let storageMapSlices, !storageMapSlices.isEmpty {
            return storageMapSlices
        }
        // Lightweight placeholder while measuring: Free + Used only (no fake apps).
        var slices: [MapSlice] = []
        if disk.used > 0 {
            slices.append(MapSlice(
                name: "Used",
                bytes: disk.used,
                color: Theme.mapOther,
                children: []
            ))
        }
        if disk.free > 0 {
            slices.append(MapSlice(
                name: "Free",
                bytes: disk.free,
                color: Theme.mapFree,
                children: []
            ))
        }
        return slices
    }

    /// Overview “Your disk” bar — categories fill `disk.used`, Free is exact `disk.free`
    /// so the bar always matches “X free of Y” (iCloud folded into Other).
    func diskBarSlices() -> [MapSlice] {
        let used = max(0, disk.used)
        let free = max(0, disk.free)
        ensureStorageMap()

        // Prefer real Storage Map categories; ignore placeholder Used/Free-only.
        let raw = (storageMapSlices ?? []).filter {
            $0.name != "Free" && $0.name != "Used" && $0.bytes > 0
        }

        var apps: MapSlice?
        var documents: MapSlice?
        var messages: MapSlice?
        var developer: MapSlice?
        var photos: MapSlice?
        var system: MapSlice?
        var otherBytes: Int64 = 0
        var otherKids: [MapChild] = []

        for slice in raw {
            switch slice.name {
            case "Apps": apps = slice
            case "Documents": documents = slice
            case "Messages": messages = slice
            case "Developer": developer = slice
            case "Photos", "Photos & Media": photos = slice
            case "System": system = slice
            case "iCloud Drive", "Other":
                otherBytes += slice.bytes
                otherKids.append(contentsOf: slice.children)
            default:
                otherBytes += slice.bytes
            }
        }

        // Same order as System Settings → Storage.
        var usedSlices: [MapSlice] = []
        if let apps { usedSlices.append(apps) }
        if let documents { usedSlices.append(documents) }
        if let messages { usedSlices.append(messages) }
        if let developer { usedSlices.append(developer) }
        if let photos { usedSlices.append(photos) }
        if let system { usedSlices.append(system) }
        if otherBytes > 0 {
            usedSlices.append(MapSlice(
                name: "Other",
                bytes: otherBytes,
                color: Theme.mapOther,
                children: otherKids
            ))
        }

        let measured = usedSlices.reduce(Int64(0)) { $0 + $1.bytes }
        if measured <= 0 || used <= 0 {
            // Map not ready — honest two-tone bar from DiskProbe.
            var placeholder: [MapSlice] = []
            if used > 0 {
                placeholder.append(MapSlice(name: "Used", bytes: used, color: Theme.mapApps, children: []))
            }
            if free > 0 {
                placeholder.append(MapSlice(name: "Free", bytes: free, color: Theme.mapFree, children: []))
            }
            return placeholder
        }

        // Make used segments sum exactly to disk.used (remainder → System / Other).
        let gap = used - measured
        if gap > 1_000_000 {
            if let idx = usedSlices.firstIndex(where: { $0.name == "System" }) {
                let s = usedSlices[idx]
                usedSlices[idx] = MapSlice(
                    name: s.name, bytes: s.bytes + gap, color: s.color,
                    children: s.children + [MapChild(name: "Other system", bytes: gap)]
                )
            } else if let idx = usedSlices.firstIndex(where: { $0.name == "Other" }) {
                let s = usedSlices[idx]
                usedSlices[idx] = MapSlice(
                    name: s.name, bytes: s.bytes + gap, color: s.color, children: s.children
                )
            } else {
                usedSlices.append(MapSlice(
                    name: "System", bytes: gap, color: Theme.mapSystem,
                    children: [MapChild(name: "macOS & system data", bytes: gap)]
                ))
            }
        } else if gap < -1_000_000 {
            // Over-count: shrink System/Other so used segments fit disk.used.
            var overflow = -gap
            for name in ["System", "Other"] {
                guard overflow > 0, let idx = usedSlices.firstIndex(where: { $0.name == name }) else { continue }
                let s = usedSlices[idx]
                let cut = min(s.bytes, overflow)
                let next = s.bytes - cut
                overflow -= cut
                if next > 1_000_000 {
                    usedSlices[idx] = MapSlice(name: s.name, bytes: next, color: s.color, children: s.children)
                } else {
                    usedSlices.remove(at: idx)
                }
            }
        }

        if free > 0 {
            usedSlices.append(MapSlice(name: "Free", bytes: free, color: Theme.mapFree, children: []))
        }
        return usedSlices
    }

    func buildersItems() -> [CacheItem] {
        items.filter { $0.group == .builders }
    }

    func everydayBytes() -> Int64 {
        items.filter { $0.group == .everyday }.reduce(0) { $0 + $1.bytes }
    }

    func buildersBytes() -> Int64 {
        items.filter { $0.group == .builders }.reduce(0) { $0 + $1.bytes }
    }

    var selectedLargeFiles: [LargeFileItem] {
        largeFiles.filter { largeFileSelection.contains($0.id) }
    }

    var largeFileSelectedBytes: Int64 {
        selectedLargeFiles.reduce(0) { $0 + $1.bytes }
    }

    /// Free plan: opens Unlock. Pro: toggles selection.
    func toggleLargeFileSelection(_ id: UUID) {
        guard isPro else {
            showSheet(.upgrade, reason: "Selecting large files is part of iClearer.")
            return
        }
        if largeFileSelection.contains(id) {
            largeFileSelection.remove(id)
        } else {
            largeFileSelection.insert(id)
        }
        notify()
    }

    func clearLargeFileSelection() {
        largeFileSelection.removeAll()
        notify()
    }

    /// Moves an app (or Applications leftover folder) to the Trash — sync & snappy.
    func uninstallApp(_ app: AppLeftover, completion: @escaping (_ freed: Int64, _ errorMessage: String?) -> Void) {
        guard isPro else {
            showSheet(.upgrade, reason: "App uninstaller is part of iClearer.")
            completion(0, nil)
            return
        }
        let path = (app.bundlePath as NSString).standardizingPath
        let home = (FileManager.default.homeDirectoryForCurrentUser.path as NSString).standardizingPath
        let allowed =
            path.hasPrefix("/Applications/")
            || path.hasPrefix(home + "/Applications/")
        guard allowed else {
            completion(0, "System apps can’t be moved to the Trash from iClearer.")
            return
        }
        guard FileManager.default.fileExists(atPath: path) else {
            apps.removeAll { $0.id == app.id }
            apps.removeAll { $0.bundlePath.hasPrefix(path + "/") }
            saveScanCache()
            notify()
            completion(0, "That app is no longer on disk.")
            return
        }

        do {
            var resulting: NSURL?
            try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: &resulting)
            let freed = app.appBytes
            if let trashURL = resulting as URL? {
                recordCleanupHistory(
                    records: [TrashRecord(
                        originalPath: path,
                        trashURL: trashURL,
                        bytes: freed,
                        name: app.name
                    )],
                    names: ["\(app.name) and leftovers"],
                    freed: freed
                )
                LicenseStore.recordCleanup(bytes: freed)
            }
            apps.removeAll { $0.id == app.id }
            apps.removeAll { $0.bundlePath.hasPrefix(path + "/") }
            saveScanCache()
            notify()
            completion(freed, nil)
        } catch {
            completion(0, error.localizedDescription)
        }
    }

    /// Moves selected large files to Trash. Prefers Finder recycle (works with TCC).
    func trashSelectedLargeFiles(completion: @escaping (_ freed: Int64, _ errorMessage: String?) -> Void) {
        let targets = selectedLargeFiles
        guard !targets.isEmpty else {
            completion(0, "Nothing selected.")
            return
        }
        let home = (FileManager.default.homeDirectoryForCurrentUser.path as NSString).standardizingPath
        var urls: [URL] = []
        var bytesByPath: [String: (id: UUID, bytes: Int64)] = [:]
        for file in targets {
            let path = (file.fullPath as NSString).standardizingPath
            guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else { continue }
            guard path.hasPrefix(home + "/") else { continue }
            let url = URL(fileURLWithPath: path)
            urls.append(url)
            bytesByPath[path] = (file.id, file.bytes)
        }
        guard !urls.isEmpty else {
            completion(0, "Those files are no longer on disk.")
            return
        }

        NSWorkspace.shared.recycle(urls) { [weak self] newURLs, error in
            DispatchQueue.main.async {
                guard let self else { return }
                var freed: Int64 = 0
                var trashedIDs = Set<UUID>()
                var records: [TrashRecord] = []
                var names: [String] = []
                // `newURLs` maps original URL → Trash URL.
                for (original, trashURL) in newURLs {
                    let path = (original.path as NSString).standardizingPath
                    let hit = bytesByPath[path] ?? bytesByPath.first(where: {
                        path.hasPrefix($0.key) || $0.key.hasPrefix(path)
                    })?.value
                    guard let hit else { continue }
                    freed += hit.bytes
                    trashedIDs.insert(hit.id)
                    records.append(TrashRecord(
                        originalPath: path,
                        trashURL: trashURL,
                        bytes: hit.bytes,
                        name: original.lastPathComponent
                    ))
                    names.append(original.lastPathComponent)
                }
                // Fallback: FileManager.trashItem when recycle returns empty but no hard error.
                if trashedIDs.isEmpty {
                    for file in targets {
                        let path = (file.fullPath as NSString).standardizingPath
                        guard path.hasPrefix(home + "/"), FileManager.default.fileExists(atPath: path) else { continue }
                        do {
                            var resulting: NSURL?
                            try FileManager.default.trashItem(
                                at: URL(fileURLWithPath: path),
                                resultingItemURL: &resulting
                            )
                            guard let trashURL = resulting as URL? else { continue }
                            freed += file.bytes
                            trashedIDs.insert(file.id)
                            records.append(TrashRecord(
                                originalPath: path,
                                trashURL: trashURL,
                                bytes: file.bytes,
                                name: file.name
                            ))
                            names.append(file.name)
                        } catch {
                            continue
                        }
                    }
                }
                if !trashedIDs.isEmpty {
                    self.largeFiles.removeAll { trashedIDs.contains($0.id) }
                    self.largeFileSelection.subtract(trashedIDs)
                    self.recordCleanupHistory(
                        records: records,
                        names: names.isEmpty ? ["Large and old files"] : names,
                        freed: freed
                    )
                    LicenseStore.recordCleanup(bytes: freed)
                    self.saveScanCache()
                    self.notify()
                    completion(freed, nil)
                } else {
                    let msg = error?.localizedDescription
                        ?? "macOS blocked Trash. Allow Files and Folders access for iClearer in System Settings → Privacy & Security."
                    completion(0, msg)
                }
            }
        }
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data)
        else { return }
        history = decoded
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    private func loadScanCache() {
        guard let data = UserDefaults.standard.data(forKey: scanCacheKey),
              let cache = try? JSONDecoder().decode(ScanCache.self, from: data)
        else { return }
        guard Date().timeIntervalSince(cache.savedAt) <= scanCacheMaxAge else {
            UserDefaults.standard.removeObject(forKey: scanCacheKey)
            return
        }
        items = cache.items
        largeFiles = cache.largeFiles
        apps = cache.apps
        selected = Set(cache.items.filter { $0.safety == .safe }.map(\.id))
        selectedItemID = selected.first ?? cache.items.first?.id
        storageMapSlices = cache.map.map { slice in
            MapSlice(
                name: slice.name,
                bytes: slice.bytes,
                color: Self.mapColor(for: slice.name),
                children: slice.children
            )
        }
        // Prefer live DiskProbe on next paint; keep cached totals as a fallback.
        if cache.diskTotal > 0 {
            disk = DiskInfo(total: cache.diskTotal, used: cache.diskUsed, free: cache.diskFree)
        }
        let found = cache.items.reduce(Int64(0)) { $0 + $1.bytes }
        scanProgress = ScanProgress(
            fraction: 1,
            label: "Last scan",
            foundBytes: found,
            foundCount: cache.items.count,
            hint: nil
        )
    }

    private func saveScanCache() {
        let cache = ScanCache(
            savedAt: Date(),
            items: items,
            map: (storageMapSlices ?? []).map {
                ScanCache.PersistedMapSlice(name: $0.name, bytes: $0.bytes, children: $0.children)
            },
            largeFiles: largeFiles,
            apps: apps,
            diskTotal: disk.total,
            diskUsed: disk.used,
            diskFree: disk.free
        )
        if let data = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(data, forKey: scanCacheKey)
        }
    }

    private static func mapColor(for name: String) -> NSColor {
        switch name {
        case "Apps": return Theme.mapApps
        case "Documents": return Theme.mapDocuments
        case "Messages": return Theme.mapICloud
        case "Developer": return Theme.mapDeveloper
        case "Photos", "Photos & Media": return Theme.mapPhotos
        case "System": return Theme.mapSystem
        case "iCloud Drive": return Theme.mapICloud
        case "Free": return Theme.mapFree
        default: return Theme.mapOther
        }
    }
}

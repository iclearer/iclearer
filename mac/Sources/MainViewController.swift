import AppKit

final class MainViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private var items: [CacheItem] = []
    private var selected = Set<UUID>()
    private var isBusy = false
    private var maxBytes: Int64 = 1
    private var disk = DiskProbe.current()

    private let sidebar = NSView()
    private let ring = RingView()
    private let diskPercentLabel = makeLabel("—", size: 22, weight: .bold, color: .white, align: .center)
    private let diskFreeLabel = makeLabel("Checking disk…", size: 11, weight: .medium, color: NSColor.white.withAlphaComponent(0.65), align: .center)
    private let saveCaption = makeLabel("YOU'LL FREE", size: 11, weight: .semibold, color: NSColor.white.withAlphaComponent(0.55), align: .center)
    private let saveValue = makeLabel("0 MB", size: 36, weight: .bold, color: Theme.accent, align: .center)
    private let saveDetail = makeLabel("Nothing selected", size: 12, weight: .medium, color: NSColor.white.withAlphaComponent(0.7), align: .center)
    private let scanBar = NSProgressIndicator()
    private let scanStatus = makeLabel("Ready to scan", size: 11, weight: .regular, color: NSColor.white.withAlphaComponent(0.55), align: .center)
    private let scanSpinner = NSProgressIndicator()
    private let scanButton = makePillButton("Scan Mac", accent: true)

    private let table = NSTableView()
    private let scroll = NSScrollView()
    private let safeButton = makePillButton("Safe only", accent: false)
    private let noneButton = makePillButton("Clear picks", accent: false)
    private let deleteButton = makePillButton("Clean Up", accent: true)
    private let footerStatus = makeLabel("Scan to find caches.", size: 12, weight: .regular, color: .secondaryLabelColor)

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 1040, height: 680))
        view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildInterface()
        refreshDisk()
        updateSavings()
        scan()
    }

    private func buildInterface() {
        sidebar.wantsLayer = true
        sidebar.layer?.backgroundColor = Theme.sidebar.cgColor
        sidebar.translatesAutoresizingMaskIntoConstraints = false

        let brand = makeLabel("Clearaer", size: 24, weight: .semibold, color: .white, align: .center)
        let brandSub = makeLabel("Disk cache cleaner", size: 12, weight: .medium, color: NSColor.white.withAlphaComponent(0.5), align: .center)

        ring.translatesAutoresizingMaskIntoConstraints = false
        diskPercentLabel.translatesAutoresizingMaskIntoConstraints = false

        scanBar.isIndeterminate = false
        scanBar.minValue = 0
        scanBar.maxValue = 1
        scanBar.doubleValue = 0
        scanBar.controlSize = .small
        scanBar.style = .bar
        scanBar.translatesAutoresizingMaskIntoConstraints = false

        scanSpinner.style = .spinning
        scanSpinner.controlSize = .small
        scanSpinner.appearance = NSAppearance(named: .darkAqua)
        scanSpinner.isDisplayedWhenStopped = false
        scanSpinner.translatesAutoresizingMaskIntoConstraints = false

        scanButton.target = self
        scanButton.action = #selector(scan)
        scanButton.keyEquivalent = "r"
        scanButton.keyEquivalentModifierMask = .command

        safeButton.target = self
        safeButton.action = #selector(selectSafe)
        noneButton.target = self
        noneButton.action = #selector(selectNone)
        deleteButton.target = self
        deleteButton.action = #selector(confirmDelete)
        deleteButton.keyEquivalent = "\r"
        deleteButton.keyEquivalentModifierMask = .command
        deleteButton.bezelColor = Theme.accent

        table.headerView = nil
        table.rowHeight = 64
        table.backgroundColor = .clear
        table.selectionHighlightStyle = .none
        table.allowsMultipleSelection = false
        table.dataSource = self
        table.delegate = self
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("row"))
        column.width = 700
        table.addTableColumn(column)
        table.intercellSpacing = NSSize(width: 0, height: 8)

        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        footerStatus.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(sidebar)
        view.addSubview(scroll)
        view.addSubview(safeButton)
        view.addSubview(noneButton)
        view.addSubview(deleteButton)
        view.addSubview(footerStatus)

        [brand, brandSub, ring, diskPercentLabel, diskFreeLabel, saveCaption, saveValue, saveDetail, scanBar, scanStatus, scanSpinner, scanButton].forEach {
            sidebar.addSubview($0)
        }

        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: view.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 280),

            brand.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 28),
            brand.centerXAnchor.constraint(equalTo: sidebar.centerXAnchor),
            brandSub.topAnchor.constraint(equalTo: brand.bottomAnchor, constant: 2),
            brandSub.centerXAnchor.constraint(equalTo: sidebar.centerXAnchor),

            ring.topAnchor.constraint(equalTo: brandSub.bottomAnchor, constant: 24),
            ring.centerXAnchor.constraint(equalTo: sidebar.centerXAnchor),
            ring.widthAnchor.constraint(equalToConstant: 132),
            ring.heightAnchor.constraint(equalToConstant: 132),
            diskPercentLabel.centerXAnchor.constraint(equalTo: ring.centerXAnchor),
            diskPercentLabel.centerYAnchor.constraint(equalTo: ring.centerYAnchor, constant: -8),
            diskFreeLabel.topAnchor.constraint(equalTo: diskPercentLabel.bottomAnchor, constant: 0),
            diskFreeLabel.centerXAnchor.constraint(equalTo: ring.centerXAnchor),
            diskFreeLabel.widthAnchor.constraint(equalToConstant: 100),

            saveCaption.topAnchor.constraint(equalTo: ring.bottomAnchor, constant: 28),
            saveCaption.centerXAnchor.constraint(equalTo: sidebar.centerXAnchor),
            saveValue.topAnchor.constraint(equalTo: saveCaption.bottomAnchor, constant: 4),
            saveValue.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 16),
            saveValue.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -16),
            saveDetail.topAnchor.constraint(equalTo: saveValue.bottomAnchor, constant: 4),
            saveDetail.centerXAnchor.constraint(equalTo: sidebar.centerXAnchor),

            scanBar.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 28),
            scanBar.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -28),
            scanBar.topAnchor.constraint(equalTo: saveDetail.bottomAnchor, constant: 22),
            scanStatus.topAnchor.constraint(equalTo: scanBar.bottomAnchor, constant: 6),
            scanStatus.leadingAnchor.constraint(equalTo: scanBar.leadingAnchor),
            scanStatus.trailingAnchor.constraint(equalTo: scanBar.trailingAnchor),

            scanButton.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor, constant: -28),
            scanButton.centerXAnchor.constraint(equalTo: sidebar.centerXAnchor),
            scanButton.widthAnchor.constraint(equalToConstant: 160),
            scanSpinner.centerYAnchor.constraint(equalTo: scanButton.centerYAnchor),
            scanSpinner.trailingAnchor.constraint(equalTo: scanButton.leadingAnchor, constant: -8),

            scroll.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: 20),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scroll.topAnchor.constraint(equalTo: view.topAnchor, constant: 18),
            scroll.bottomAnchor.constraint(equalTo: deleteButton.topAnchor, constant: -16),

            deleteButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -22),
            deleteButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -18),
            deleteButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 180),
            noneButton.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -8),
            noneButton.centerYAnchor.constraint(equalTo: deleteButton.centerYAnchor),
            safeButton.trailingAnchor.constraint(equalTo: noneButton.leadingAnchor, constant: -8),
            safeButton.centerYAnchor.constraint(equalTo: deleteButton.centerYAnchor),
            footerStatus.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            footerStatus.centerYAnchor.constraint(equalTo: deleteButton.centerYAnchor),
            footerStatus.trailingAnchor.constraint(lessThanOrEqualTo: safeButton.leadingAnchor, constant: -12)
        ])
    }

    private var selectedBytes: Int64 {
        items.filter { selected.contains($0.id) }.reduce(0) { $0 + $1.bytes }
    }

    private var selectedCount: Int {
        items.filter { selected.contains($0.id) }.count
    }

    private func refreshDisk() {
        disk = DiskProbe.current()
        ring.progress = CGFloat(disk.usedFraction)
        diskPercentLabel.stringValue = "\(disk.percentUsed)%"
        diskFreeLabel.stringValue = "\(AppFormat.bytes(disk.free)) free"
    }

    private func updateSavings() {
        let bytes = selectedBytes
        saveValue.stringValue = AppFormat.bytes(bytes)
        if isBusy && items.isEmpty {
            saveCaption.stringValue = "FOUND SO FAR"
            saveDetail.stringValue = "Measuring folders…"
        } else if selectedCount == 0 {
            saveCaption.stringValue = "YOU'LL FREE"
            saveDetail.stringValue = items.isEmpty ? "Scan to find caches" : "Select folders to clean"
        } else {
            saveCaption.stringValue = "YOU'LL FREE"
            saveDetail.stringValue = "\(selectedCount) folder\(selectedCount == 1 ? "" : "s") selected"
        }
        deleteButton.title = selectedCount == 0
            ? "Clean Up"
            : "Clean Up · \(AppFormat.bytes(bytes))"
        deleteButton.isEnabled = !isBusy && selectedCount > 0
        noneButton.isEnabled = !isBusy && selectedCount > 0
        safeButton.isEnabled = !isBusy && !items.isEmpty
    }

    private func setBusy(_ busy: Bool) {
        isBusy = busy
        scanButton.isEnabled = !busy
        if busy {
            scanSpinner.startAnimation(nil)
        } else {
            scanSpinner.stopAnimation(nil)
        }
        updateSavings()
    }

    @objc private func scan() {
        guard !isBusy else { return }
        items = []
        selected = []
        table.reloadData()
        setBusy(true)
        scanBar.doubleValue = 0
        scanStatus.stringValue = "Starting scan…"
        footerStatus.stringValue = "Scanning cache folders…"
        refreshDisk()
        updateSavings()

        DispatchQueue.global(qos: .userInitiated).async {
            let found = CacheScanner.scan { progress in
                DispatchQueue.main.async {
                    self.scanBar.doubleValue = progress.fraction
                    self.scanStatus.stringValue = progress.label
                    self.saveCaption.stringValue = "FOUND SO FAR"
                    self.saveValue.stringValue = AppFormat.bytes(progress.foundBytes)
                    self.saveDetail.stringValue = progress.foundCount == 0
                        ? "Measuring folders…"
                        : "\(progress.foundCount) folders · \(AppFormat.bytes(progress.foundBytes))"
                }
            }
            DispatchQueue.main.async {
                self.items = found
                self.maxBytes = max(found.map(\.bytes).max() ?? 1, 1)
                self.selected = Set(found.filter { $0.safety == .safe }.map(\.id))
                self.table.reloadData()
                self.refreshDisk()
                self.setBusy(false)
                self.scanBar.doubleValue = 1
                if found.isEmpty {
                    self.scanStatus.stringValue = "No large caches found"
                    self.footerStatus.stringValue = "Nothing over 1 MB."
                } else {
                    let total = found.reduce(Int64(0)) { $0 + $1.bytes }
                    self.scanStatus.stringValue = "Scan complete"
                    self.footerStatus.stringValue = "Found \(found.count) folders · \(AppFormat.bytes(total)) recoverable."
                }
                self.updateSavings()
            }
        }
    }

    @objc private func selectSafe() {
        selected = Set(items.filter { $0.safety == .safe }.map(\.id))
        table.reloadData()
        updateSavings()
    }

    @objc private func selectNone() {
        selected.removeAll()
        table.reloadData()
        updateSavings()
    }

    @objc private func confirmDelete() {
        let chosen = items.filter { selected.contains($0.id) }
        guard !chosen.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = "Move \(AppFormat.bytes(selectedBytes)) to Trash?"
        alert.informativeText = "\(chosen.count) folders will be moved to Trash. You can restore them if needed."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        delete(chosen)
    }

    private func delete(_ chosen: [CacheItem]) {
        setBusy(true)
        scanBar.doubleValue = 0
        scanStatus.stringValue = "Cleaning…"
        footerStatus.stringValue = "Moving \(chosen.count) items to Trash…"
        DispatchQueue.global(qos: .userInitiated).async {
            var failures: [String] = []
            var freed: Int64 = 0
            for (index, item) in chosen.enumerated() {
                DispatchQueue.main.async {
                    self.scanBar.doubleValue = Double(index) / Double(max(chosen.count, 1))
                    self.scanStatus.stringValue = "Removing \(item.name)…"
                    self.saveCaption.stringValue = "CLEANING"
                    self.saveValue.stringValue = AppFormat.bytes(freed)
                    self.saveDetail.stringValue = "\(index) of \(chosen.count)"
                }
                do {
                    try CacheCleaner.moveToTrash(item.path)
                    freed += item.bytes
                } catch {
                    failures.append("\(item.name): \(error.localizedDescription)")
                }
            }
            DispatchQueue.main.async {
                self.items.removeAll { item in
                    chosen.contains(where: { $0.id == item.id }) && !FileManager.default.fileExists(atPath: item.path)
                }
                self.selected = Set(self.items.map(\.id)).intersection(self.selected)
                self.maxBytes = max(self.items.map(\.bytes).max() ?? 1, 1)
                self.table.reloadData()
                self.refreshDisk()
                self.setBusy(false)
                self.scanBar.doubleValue = 1
                self.scanStatus.stringValue = failures.isEmpty ? "Cleaned" : "Finished with errors"
                if failures.isEmpty {
                    self.footerStatus.stringValue = "Moved \(chosen.count) items to Trash · about \(AppFormat.bytes(freed))."
                } else {
                    self.footerStatus.stringValue = "Finished with \(failures.count) error(s). About \(AppFormat.bytes(freed)) moved."
                    let alert = NSAlert()
                    alert.messageText = "Some items could not be deleted"
                    alert.informativeText = failures.joined(separator: "\n")
                    alert.runModal()
                }
                self.updateSavings()
            }
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int { items.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = items[row]
        return CacheRowView(
            item: item,
            selected: selected.contains(item.id),
            maxBytes: maxBytes,
            onToggle: { [weak self] in self?.toggle(item) }
        )
    }

    private func toggle(_ item: CacheItem) {
        if selected.contains(item.id) {
            selected.remove(item.id)
        } else {
            selected.insert(item.id)
        }
        table.reloadData()
        updateSavings()
    }
}

private final class CacheRowView: NSTableCellView {
    init(item: CacheItem, selected: Bool, maxBytes: Int64, onToggle: @escaping () -> Void) {
        super.init(frame: NSRect(x: 0, y: 0, width: 700, height: 64))
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(selected ? 0.06 : 0.035).cgColor

        let check = NSButton(checkboxWithTitle: "", target: nil, action: nil)
        check.state = selected ? .on : .off
        check.translatesAutoresizingMaskIntoConstraints = false
        check.target = self
        check.action = #selector(pressed)
        self.onToggle = onToggle

        let name = makeLabel(item.name, size: 14, weight: .semibold, color: .labelColor)
        let path = makeLabel(item.path, size: 11, weight: .regular, color: .secondaryLabelColor)
        path.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        path.toolTip = item.path

        let pill = makeLabel(item.safety == .safe ? "Safe" : "Ask first", size: 10, weight: .bold, color: item.safety == .safe ? Theme.accentDeep : Theme.warning)
        pill.wantsLayer = true
        pill.layer?.cornerRadius = 8
        pill.layer?.backgroundColor = (item.safety == .safe ? Theme.accent : Theme.warning).withAlphaComponent(0.16).cgColor
        pill.alignment = .center

        let size = makeLabel(item.formattedSize, size: 14, weight: .semibold, color: .labelColor, align: .right)
        let bar = BarView()
        let logMax = log(Double(max(maxBytes, 2)))
        let logVal = log(Double(max(item.bytes, 1)))
        bar.progress = CGFloat(max(0.12, min(1, logVal / logMax)))
        bar.color = item.safety == .safe ? Theme.accent : Theme.warning
        bar.translatesAutoresizingMaskIntoConstraints = false

        [check, name, path, pill, size, bar].forEach { addSubview($0) }

        NSLayoutConstraint.activate([
            check.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            check.centerYAnchor.constraint(equalTo: centerYAnchor),
            name.leadingAnchor.constraint(equalTo: check.trailingAnchor, constant: 6),
            name.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            pill.leadingAnchor.constraint(equalTo: name.trailingAnchor, constant: 8),
            pill.centerYAnchor.constraint(equalTo: name.centerYAnchor),
            pill.widthAnchor.constraint(equalToConstant: 64),
            path.leadingAnchor.constraint(equalTo: name.leadingAnchor),
            path.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 3),
            path.trailingAnchor.constraint(lessThanOrEqualTo: size.leadingAnchor, constant: -12),
            size.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            size.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            size.widthAnchor.constraint(equalToConstant: 90),
            bar.trailingAnchor.constraint(equalTo: size.trailingAnchor),
            bar.topAnchor.constraint(equalTo: size.bottomAnchor, constant: 6),
            bar.widthAnchor.constraint(equalToConstant: 90),
            bar.heightAnchor.constraint(equalToConstant: 7)
        ])
    }

    private var onToggle: (() -> Void)?

    @objc private func pressed() {
        onToggle?()
    }

    required init?(coder: NSCoder) { nil }
}

enum AppFormat {
    static func bytes(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }
}

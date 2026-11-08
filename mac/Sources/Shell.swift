import AppKit

final class MainViewController: NSViewController {
    private let state = AppState.shared
    private let shell = GlassEffectView(kind: .windowShell)
    private let rootStack = NSStackView()
    private let sidebar = SidebarView()
    private let contentHost = NSView()
    private let contentPanel = NSView()
    private let headerTitle = makeLabel("Overview", size: 23, weight: .bold, color: Theme.Colors.text)
    private let headerSubtitle = makeLabel("Your Mac at a glance", size: 12.5, weight: .regular, color: Theme.Colors.muted)
    private let searchPill = SearchPillView()
    private let rescanPill = PillButton(title: "Rescan", style: .ghost)
    private let accountPill = AccountPillView()
    private let screenHost = NSView()
    private var currentScreenView: NSView?
    private var shownScreen: AppScreen?
    private let toast = ToastView()
    private let cleanupBar = CleanupBarView()
    private var sheetController: SheetPresenter?
    private var appearanceObserver: NSKeyValueObservation?
    private var reloadWorkItem: DispatchWorkItem?
    private var isReloading = false
    private var didStartInitialScan = false

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 1280, height: 800))
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.clear.cgColor
        view = root
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        sheetController = SheetPresenter(host: self)
        buildChrome()
        observe()
        sidebar.onNavigate = { [weak self] screen in
            self?.state.navigate(screen)
        }
        sidebar.onUpgrade = { [weak self] in
            self?.state.showSheet(.upgrade)
        }
        sidebar.onAccount = { [weak self] in
            SettingsTab.pending = .account
            self?.state.showSheet(.settings)
        }
        cleanupBar.onClean = { [weak self] in self?.requestCleanup() }
        toast.onUndo = { [weak self] in self?.state.undoLastCleanup() }
        searchPill.onChange = { [weak self] q in
            self?.state.setSearch(q)
            if let clean = self?.currentScreenView as? CleanScreen {
                clean.refreshFromState()
            }
        }
        // Prototype toolbar .pill — refresh glyph + label, cd2 chrome.
        rescanPill.symbolName = "arrow.clockwise"
        rescanPill.compact = true
        rescanPill.style = .ghost
        rescanPill.target = self
        rescanPill.action = #selector(menuRescan)
        rescanPill.heightAnchor.constraint(equalToConstant: 30).isActive = true
        accountPill.target = self
        accountPill.action = #selector(openAccount)
        reloadAll()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        applyContentAppearance()
        guard !didStartInitialScan else { return }
        didStartInitialScan = true
        if !state.license.onboardingComplete || state.license.email.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.state.showSheet(.onboarding)
            }
        } else if state.items.isEmpty && !state.isScanning {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                self.state.startScan()
            }
        }
    }

    private func buildChrome() {
        shell.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(shell)

        rootStack.orientation = .horizontal
        rootStack.spacing = 10
        rootStack.distribution = .fill
        rootStack.alignment = .height
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        rootStack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

        Theme.applyContentPanelStyle(to: contentPanel)
        contentPanel.translatesAutoresizingMaskIntoConstraints = false
        // Don’t clip toolbar pills at the rounded corner (Free · 500 MB avatar).
        contentPanel.layer?.masksToBounds = false
        contentPanel.layer?.cornerRadius = 20

        contentHost.translatesAutoresizingMaskIntoConstraints = false
        contentHost.setContentHuggingPriority(.defaultLow, for: .horizontal)
        contentHost.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        screenHost.translatesAutoresizingMaskIntoConstraints = false
        screenHost.wantsLayer = true
        screenHost.layer?.masksToBounds = true
        screenHost.setContentHuggingPriority(.defaultLow, for: .horizontal)

        headerTitle.setContentHuggingPriority(.defaultLow, for: .horizontal)
        headerTitle.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        headerSubtitle.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let titleTracking = NSMutableAttributedString(string: "Overview", attributes: [
            .font: NSFont.systemFont(ofSize: 23, weight: .bold),
            .foregroundColor: Theme.Colors.text,
            .kern: -0.025 * 23
        ])
        headerTitle.attributedStringValue = titleTracking

        let header = NSStackView(views: [headerTitle, headerSubtitle])
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = 2
        header.translatesAutoresizingMaskIntoConstraints = false
        header.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        searchPill.setContentCompressionResistancePriority(.required, for: .horizontal)
        rescanPill.setContentCompressionResistancePriority(.required, for: .horizontal)
        accountPill.setContentCompressionResistancePriority(.required, for: .horizontal)
        accountPill.setContentHuggingPriority(.required, for: .horizontal)
        let toolbarRight = NSStackView(views: [searchPill, rescanPill, accountPill])
        toolbarRight.orientation = .horizontal
        toolbarRight.spacing = 8
        toolbarRight.alignment = .centerY
        toolbarRight.translatesAutoresizingMaskIntoConstraints = false
        toolbarRight.setContentCompressionResistancePriority(.required, for: .horizontal)

        let top = NSView()
        top.translatesAutoresizingMaskIntoConstraints = false
        top.wantsLayer = true
        // Never clip the Free · 500 MB pill into a diamond at the corner.
        top.clipsToBounds = false
        toolbarRight.clipsToBounds = false
        top.addSubview(header)
        top.addSubview(toolbarRight)

        let topRule = NSView()
        topRule.translatesAutoresizingMaskIntoConstraints = false
        topRule.wantsLayer = true
        topRule.layer?.backgroundColor = Theme.Colors.separator.cgColor

        contentPanel.addSubview(top)
        contentPanel.addSubview(topRule)
        contentPanel.addSubview(screenHost)
        contentPanel.addSubview(cleanupBar)
        contentHost.addSubview(contentPanel)

        rootStack.addArrangedSubview(sidebar)
        rootStack.addArrangedSubview(contentHost)
        shell.addSubview(rootStack)
        view.addSubview(toast)

        sidebar.widthAnchor.constraint(equalToConstant: 240).isActive = true
        sidebar.setContentHuggingPriority(.required, for: .horizontal)
        sidebar.setContentCompressionResistancePriority(.required, for: .horizontal)
        cleanupBar.translatesAutoresizingMaskIntoConstraints = false
        toast.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            shell.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            shell.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            shell.topAnchor.constraint(equalTo: view.topAnchor),
            shell.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            rootStack.leadingAnchor.constraint(equalTo: shell.leadingAnchor),
            rootStack.trailingAnchor.constraint(equalTo: shell.trailingAnchor),
            rootStack.topAnchor.constraint(equalTo: shell.topAnchor),
            rootStack.bottomAnchor.constraint(equalTo: shell.bottomAnchor),

            contentPanel.leadingAnchor.constraint(equalTo: contentHost.leadingAnchor),
            contentPanel.trailingAnchor.constraint(equalTo: contentHost.trailingAnchor),
            contentPanel.topAnchor.constraint(equalTo: contentHost.topAnchor),
            contentPanel.bottomAnchor.constraint(equalTo: contentHost.bottomAnchor),
            contentHost.widthAnchor.constraint(greaterThanOrEqualToConstant: 640),

            top.leadingAnchor.constraint(equalTo: contentPanel.leadingAnchor, constant: 22),
            top.trailingAnchor.constraint(equalTo: contentPanel.trailingAnchor, constant: -22),
            top.topAnchor.constraint(equalTo: contentPanel.topAnchor, constant: 18),
            // Tall enough for the 32pt Free pill + title block without crushing.
            top.heightAnchor.constraint(equalToConstant: 56),
            header.leadingAnchor.constraint(equalTo: top.leadingAnchor),
            header.centerYAnchor.constraint(equalTo: top.centerYAnchor),
            toolbarRight.trailingAnchor.constraint(equalTo: top.trailingAnchor),
            toolbarRight.centerYAnchor.constraint(equalTo: top.centerYAnchor),
            toolbarRight.heightAnchor.constraint(equalToConstant: 32),
            toolbarRight.leadingAnchor.constraint(greaterThanOrEqualTo: header.trailingAnchor, constant: 16),
            accountPill.heightAnchor.constraint(equalToConstant: 32),

            topRule.leadingAnchor.constraint(equalTo: contentPanel.leadingAnchor),
            topRule.trailingAnchor.constraint(equalTo: contentPanel.trailingAnchor),
            topRule.topAnchor.constraint(equalTo: top.bottomAnchor, constant: 10),
            topRule.heightAnchor.constraint(equalToConstant: 1),

            screenHost.leadingAnchor.constraint(equalTo: contentPanel.leadingAnchor),
            screenHost.trailingAnchor.constraint(equalTo: contentPanel.trailingAnchor),
            screenHost.topAnchor.constraint(equalTo: topRule.bottomAnchor),
            screenHost.bottomAnchor.constraint(equalTo: contentPanel.bottomAnchor),

            // Floating glass pill — bottom-right of the Clean list (left of inspector ~292).
            cleanupBar.trailingAnchor.constraint(equalTo: contentPanel.trailingAnchor, constant: -316),
            cleanupBar.leadingAnchor.constraint(greaterThanOrEqualTo: contentPanel.leadingAnchor, constant: 36),
            cleanupBar.bottomAnchor.constraint(equalTo: contentPanel.bottomAnchor, constant: -22),
            cleanupBar.heightAnchor.constraint(equalToConstant: 52),

            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -28),
            toast.widthAnchor.constraint(lessThanOrEqualToConstant: 420)
        ])
    }

    private func scheduleReload() {
        reloadWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.reloadAll()
        }
        reloadWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }

    private func observe() {
        NotificationCenter.default.addObserver(forName: .iClearerStateChanged, object: nil, queue: .main) { [weak self] _ in
            self?.scheduleReload()
        }
        NotificationCenter.default.addObserver(forName: .iClearerLicenseChanged, object: nil, queue: .main) { [weak self] _ in
            self?.scheduleReload()
        }
        NotificationCenter.default.addObserver(forName: .iClearerShowSheet, object: nil, queue: .main) { [weak self] note in
            guard let raw = note.userInfo?["kind"] as? String, let kind = SheetKind(rawValue: raw) else { return }
            let reason = note.userInfo?["reason"] as? String
            self?.sheetController?.present(kind, reason: reason)
        }
        NotificationCenter.default.addObserver(forName: .iClearerQuickLook, object: nil, queue: .main) { [weak self] note in
            guard let raw = note.userInfo?["id"] as? String,
                  let id = UUID(uuidString: raw),
                  let file = self?.state.largeFiles.first(where: { $0.id == id }) else { return }
            self?.sheetController?.presentQuickLook(file: file)
        }
        NotificationCenter.default.addObserver(forName: .iClearerToast, object: nil, queue: .main) { [weak self] note in
            let message = note.userInfo?["message"] as? String ?? ""
            let undo = note.userInfo?["undo"] as? Bool ?? false
            self?.toast.show(message: message, undo: undo)
        }
        NotificationCenter.default.addObserver(forName: .iClearerNavigate, object: nil, queue: .main) { [weak self] note in
            if let raw = note.userInfo?["screen"] as? String, let screen = AppScreen(rawValue: raw) {
                self?.state.navigate(screen)
            }
        }
        // External capture scripts can post: com.iclearer.navigate with object = screen rawValue
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.iclearer.navigate"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            let raw = (note.object as? String)
                ?? (note.userInfo?["screen"] as? String)
            guard let raw, let screen = AppScreen(rawValue: raw) else { return }
            self?.state.navigate(screen)
        }
        appearanceObserver = view.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            self?.applyContentAppearance()
        }
    }

    private func applyContentAppearance() {
        Theme.applyContentPanelStyle(to: contentPanel)
        headerTitle.textColor = Theme.Colors.text
        headerSubtitle.textColor = Theme.Colors.muted
        Theme.refreshAppearance(in: view)
        sidebar.refreshAppearance()
        cleanupBar.refreshAppearance()
    }

    private func reloadAll() {
        guard !isReloading else { return }
        isReloading = true
        defer { isReloading = false }
        sidebar.reload(state: state)
        sidebar.isHidden = state.sidebarHidden
        let title = state.screen.title
        headerTitle.attributedStringValue = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 23, weight: .bold),
            .foregroundColor: Theme.Colors.text,
            .kern: -0.025 * 23
        ])
        headerSubtitle.stringValue = state.screen.subtitle

        // Profile letter = first character of email local-part (prototype `.av`).
        let local = state.license.email.split(separator: "@").first.map(String.init) ?? state.license.email
        let initial = (local.first.map { String($0).uppercased() }) ?? "Y"
        let accountCaption: String
        if state.isPro {
            accountCaption = state.license.plan == .once ? "Version 1" : "Yearly"
        } else {
            accountCaption = "Free · \(AppFormat.freeQuota(state.license.remainingFreeBytes)) left"
        }
        accountPill.reload(initial: initial, caption: accountCaption)
        rescanPill.isHidden = state.isScanning

        // Keep Clean mounted across scan/selection updates; rebuild only when the
        // destination screen changes (never loop-rebuild Overview on every notify).
        if state.screen == .clean, let clean = currentScreenView as? CleanScreen, shownScreen == .clean {
            clean.refreshFromState()
        } else if state.screen == .storageMap, let map = currentScreenView as? StorageMapScreen, shownScreen == .storageMap {
            map.refreshFromState()
        } else if state.screen == .largeFiles, let large = currentScreenView as? LargeFilesScreen, shownScreen == .largeFiles {
            large.refreshFromState()
        } else if state.screen == .apps, let apps = currentScreenView as? AppsScreen, shownScreen == .apps {
            apps.refreshFromState()
        } else if state.screen == .builders, let builders = currentScreenView as? BuildersScreen, shownScreen == .builders {
            builders.refreshFromState()
        } else if state.screen == .history, let history = currentScreenView as? HistoryScreen, shownScreen == .history {
            history.refreshFromState()
        } else if shownScreen != state.screen || currentScreenView == nil {
            shownScreen = state.screen
            let next = ScreenFactory.view(for: state.screen, state: state, host: self)
            currentScreenView?.removeFromSuperview()
            currentScreenView = next
            next.translatesAutoresizingMaskIntoConstraints = false
            screenHost.addSubview(next)
            NSLayoutConstraint.activate([
                next.leadingAnchor.constraint(equalTo: screenHost.leadingAnchor),
                next.trailingAnchor.constraint(equalTo: screenHost.trailingAnchor),
                next.topAnchor.constraint(equalTo: screenHost.topAnchor),
                next.bottomAnchor.constraint(equalTo: screenHost.bottomAnchor)
            ])
        } else if let overview = currentScreenView as? OverviewScreen {
            overview.refreshFromState()
        }

        let showBar = state.screen == .clean || (state.screen == .largeFiles && state.isPro)
        cleanupBar.isHidden = !showBar
        cleanupBar.reload(state: state)
        applyContentAppearance()
    }

    func requestCleanup(forceAsk: Bool = false) {
        if state.screen == .largeFiles {
            let bytes = state.largeFileSelectedBytes
            guard bytes > 0 else { return }
            sheetController?.presentMovingToTrash(bytes: bytes)
            let started = Date()
            state.trashSelectedLargeFiles { [weak self] freed, errorMessage in
                let elapsed = Date().timeIntervalSince(started)
                let delay = max(0, 0.85 - elapsed)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self?.sheetController?.dismissCurrent()
                    if freed > 0 {
                        self?.state.showToast("Moved \(AppFormat.bytes(freed)) to the Trash.", undo: false)
                    } else {
                        self?.state.showToast(errorMessage ?? "Couldn’t move those files to the Trash.", undo: false)
                    }
                }
            }
            return
        }
        switch state.cleanupGate() {
        case .empty:
            return
        case .needsUpgrade(let reason):
            state.showSheet(.upgrade, reason: reason)
        case .needsAskConfirm(let count):
            // Modal 1 (Ask first) → Modal 2 (Moving to Trash) → cleanup
            sheetController?.presentAskFirstConfirm(count: count) { [weak self] in
                self?.beginCleanupWithMovingSheet(acknowledgedAskFirst: true)
            }
        case .ready:
            // Safe-only: skip Ask first, go straight to Moving modal
            beginCleanupWithMovingSheet(acknowledgedAskFirst: true)
        }
    }

    /// Shows “Moving to the Trash…” then runs cleanup; dismisses when finished.
    private func beginCleanupWithMovingSheet(acknowledgedAskFirst: Bool) {
        let bytes = state.selectedBytes
        guard bytes > 0 else { return }
        sheetController?.presentMovingToTrash(bytes: bytes)
        let started = Date()
        state.performCleanup(acknowledgedAskFirst: acknowledgedAskFirst) { [weak self] in
            let elapsed = Date().timeIntervalSince(started)
            let delay = max(0, 0.85 - elapsed)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self?.sheetController?.dismissCurrent()
            }
        }
    }

    @objc private func openAccount() {
        SettingsTab.pending = .account
        state.showSheet(.settings)
    }

    // MARK: Menu actions

    @objc func menuRescan() {
        // Scan UI lives on Overview (prototype ovw ring).
        if state.screen != .overview {
            state.navigate(.overview)
        }
        state.startScan()
    }
    @objc func menuUndo() { state.undoLastCleanup() }
    @objc func menuSelectSafe() { state.selectSafeOnly() }
    @objc func menuClearPicks() { state.clearPicks() }
    @objc func menuSelectAll() {
        if state.screen == .clean { state.selectAllVisible() }
        else { state.showToast("Select All works on the Clean list.") }
    }
    @objc func menuSettings() {
        SettingsTab.pending = .general
        state.showSheet(.settings)
    }
    @objc func menuAccount() {
        SettingsTab.pending = .account
        state.showSheet(.settings)
    }
    @objc func menuUpgrade() { state.showSheet(.upgrade) }
    @objc func menuAbout() { state.showSheet(.about) }
    @objc func menuHelp() { state.showSheet(.help) }
    @objc func menuRules() { state.showSheet(.rules) }
    @objc func menuKeys() { state.showSheet(.keys) }
    @objc func menuSignIn() { state.showSheet(.signIn) }
    @objc func menuToggleSidebar() { state.toggleSidebar() }
    @objc func menuToggleInspector() { state.toggleInspector() }

    @objc func menuGoOverview() { state.navigate(.overview) }
    @objc func menuGoClean() { state.navigate(.clean) }
    @objc func menuGoMap() { state.navigate(.storageMap) }
    @objc func menuGoLarge() { state.navigate(.largeFiles) }
    @objc func menuGoApps() { state.navigate(.apps) }
    @objc func menuGoBuilders() { state.navigate(.builders) }
    @objc func menuGoHistory() { state.navigate(.history) }

    @objc func menuExport() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "iClearer-report.txt"
        panel.beginSheetModal(for: view.window!) { [weak self] result in
            guard result == .OK, let url = panel.url, let self else { return }
            var lines = ["iClearer report", "Plan: \(self.state.license.plan.displayName)", ""]
            for item in self.state.items {
                lines.append("\(item.name)\t\(item.formattedSize)\t\(item.safety.label)\t\(item.path)")
            }
            try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            self.state.showToast("Report exported.")
        }
    }

    @objc func menuAddProtected() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: view.window!) { [weak self] result in
            guard result == .OK, let url = panel.url else { return }
            self?.state.protectPath(url.path)
        }
    }
}

// MARK: - Sidebar

final class SidebarView: NSView {
    var onNavigate: ((AppScreen) -> Void)?
    var onUpgrade: (() -> Void)?
    var onAccount: (() -> Void)?

    private let stack = NSStackView()
    private let planCard = NSView()
    private let planTitle = makeLabel("Free plan", size: 13, weight: .semibold, color: Theme.Colors.text)
    private let planDetail = makeLabel("", size: 12, weight: .regular, color: Theme.Colors.muted)
    private let quotaBar = ProgressTrack()
    private let unlockButton = PillButton(title: "Unlock iClearer", style: .primary)
    private var navRows: [AppScreen: NavRowView] = [:]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false

        // Traffic-light clearance (window buttons live in the titlebar)
        let trafficSpace = NSView()
        trafficSpace.translatesAutoresizingMaskIntoConstraints = false
        trafficSpace.heightAnchor.constraint(equalToConstant: 28).isActive = true

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 1
        stack.translatesAutoresizingMaskIntoConstraints = false

        planCard.wantsLayer = true
        planCard.translatesAutoresizingMaskIntoConstraints = false
        quotaBar.translatesAutoresizingMaskIntoConstraints = false
        quotaBar.usesQuotaGradient = true
        unlockButton.compact = true
        unlockButton.target = self
        unlockButton.action = #selector(upgrade)

        let planStack = NSStackView(views: [planTitle, planDetail, quotaBar, unlockButton])
        planStack.orientation = .vertical
        planStack.alignment = .leading
        planStack.spacing = 6
        planStack.translatesAutoresizingMaskIntoConstraints = false
        planCard.addSubview(planStack)

        addSubview(trafficSpace)
        addSubview(stack)
        addSubview(planCard)

        NSLayoutConstraint.activate([
            trafficSpace.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            trafficSpace.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            trafficSpace.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),

            stack.topAnchor.constraint(equalTo: trafficSpace.bottomAnchor, constant: 4),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: planCard.topAnchor, constant: -10),

            planCard.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            planCard.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            planCard.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            planStack.leadingAnchor.constraint(equalTo: planCard.leadingAnchor, constant: 13),
            planStack.trailingAnchor.constraint(equalTo: planCard.trailingAnchor, constant: -13),
            planStack.topAnchor.constraint(equalTo: planCard.topAnchor, constant: 13),
            planStack.bottomAnchor.constraint(equalTo: planCard.bottomAnchor, constant: -13),
            quotaBar.heightAnchor.constraint(equalToConstant: 6),
            quotaBar.widthAnchor.constraint(equalTo: planStack.widthAnchor),
            unlockButton.widthAnchor.constraint(equalTo: planStack.widthAnchor)
        ])

        applyPlanCardChrome()
        buildNav()
    }

    required init?(coder: NSCoder) { nil }

    private func applyPlanCardChrome() {
        planCard.layer?.cornerRadius = 16
        planCard.layer?.backgroundColor = Theme.Colors.overlay.cgColor
        planCard.layer?.borderWidth = 1
        planCard.layer?.borderColor = NSColor.white.withAlphaComponent(0.3).cgColor
        // Inset highlight feel
        planCard.layer?.shadowColor = NSColor.white.cgColor
        planCard.layer?.shadowOpacity = 0.25
        planCard.layer?.shadowRadius = 0
        planCard.layer?.shadowOffset = CGSize(width: 0, height: 0.5)
    }

    func refreshAppearance() {
        applyPlanCardChrome()
        planTitle.textColor = Theme.Colors.text
        planDetail.textColor = Theme.Colors.muted
        for row in navRows.values { row.refreshAppearance() }
    }

    private func buildNav() {
        let groups: [(String, [AppScreen])] = [
            ("Clean", [.overview, .clean, .storageMap, .largeFiles, .apps, .builders]),
            ("Activity", [.history]),
            ("Coming in 1.1", [.duplicates, .maintenance])
        ]
        for (title, screens) in groups {
            let label = makeLabel(title, size: 11, weight: .semibold, color: Theme.Colors.muted)
            label.translatesAutoresizingMaskIntoConstraints = false
            let pad = NSView()
            pad.translatesAutoresizingMaskIntoConstraints = false
            pad.heightAnchor.constraint(equalToConstant: title == "Clean" ? 4 : 10).isActive = true
            stack.addArrangedSubview(pad)
            stack.addArrangedSubview(label)
            label.leadingAnchor.constraint(equalTo: stack.leadingAnchor, constant: 10).isActive = true
            for screen in screens {
                let row = NavRowView(screen: screen)
                row.target = self
                row.action = #selector(navClicked(_:))
                navRows[screen] = row
                stack.addArrangedSubview(row)
                row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            }
        }
    }

    @objc private func navClicked(_ sender: NavRowView) {
        onNavigate?(sender.screen)
    }

    @objc private func upgrade() { onUpgrade?() }

    func reload(state: AppState) {
        for (screen, row) in navRows {
            var sizeBadge: String?
            if !state.isScanning {
                switch screen {
                case .clean where state.totalFoundBytes > 0:
                    sizeBadge = AppFormat.bytes(state.totalFoundBytes)
                case .largeFiles:
                    let bytes = state.largeFilesBytes
                    if bytes > 0 { sizeBadge = AppFormat.bytes(bytes) }
                case .apps:
                    let bytes = state.appsBytes
                    if bytes > 0 { sizeBadge = AppFormat.bytes(bytes) }
                case .builders where state.buildersBytes() > 0:
                    sizeBadge = AppFormat.bytes(state.buildersBytes())
                default: break
                }
            }
            row.reload(selected: state.screen == screen, sizeBadge: sizeBadge)
        }

        planTitle.stringValue = state.license.plan.displayName
        if state.isPro {
            planDetail.stringValue = state.license.plan == .once
                ? "Updates until version 2"
                : "1 of \(state.license.macSeats) Mac used"
            quotaBar.isHidden = true
            unlockButton.title = "Account"
            unlockButton.action = #selector(account)
        } else {
            planDetail.stringValue = "\(AppFormat.freeQuota(state.license.remainingFreeBytes)) of cleanup left"
            quotaBar.isHidden = false
            let used = CGFloat(state.license.usedCleanupBytes) / CGFloat(LicenseState.freeQuotaBytes)
            quotaBar.progress = min(1, used)
            unlockButton.title = "Unlock iClearer"
            unlockButton.action = #selector(upgrade)
        }
        refreshAppearance()
    }

    @objc private func account() { onAccount?() }
}

// MARK: - NavRowView

final class NavRowView: NSControl {
    let screen: AppScreen
    private let badge = IconBadgeView()
    private let titleLabel = makeLabel("", size: 13, weight: .medium, color: Theme.Colors.text)
    private let sizeLabel = makeLabel("", size: 12, weight: .regular, color: Theme.Colors.muted)
    private let soonPill = makeLabel("1.1", size: 9.5, weight: .bold, color: Theme.Colors.onAccent, align: .center)
    private var selected = false
    private var hovering = false

    init(screen: AppScreen) {
        self.screen = screen
        super.init(frame: .zero)
        wantsLayer = true
        focusRingType = .none
        translatesAutoresizingMaskIntoConstraints = false

        badge.screen = screen
        badge.setSymbol(SFSymbol.forScreen(screen))
        titleLabel.stringValue = screen.title
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        soonPill.wantsLayer = true
        soonPill.layer?.cornerRadius = 99
        soonPill.layer?.backgroundColor = Theme.Colors.accent.cgColor
        soonPill.isHidden = !screen.isComingSoon

        sizeLabel.alignment = .right
        sizeLabel.setContentHuggingPriority(.required, for: .horizontal)

        addSubview(badge)
        addSubview(titleLabel)
        addSubview(soonPill)
        addSubview(sizeLabel)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 34),
            badge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 9),
            badge.centerYAnchor.constraint(equalTo: centerYAnchor),
            badge.widthAnchor.constraint(equalToConstant: 24),
            badge.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 9),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            soonPill.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 6),
            soonPill.centerYAnchor.constraint(equalTo: centerYAnchor),
            soonPill.widthAnchor.constraint(greaterThanOrEqualToConstant: 22),
            soonPill.heightAnchor.constraint(equalToConstant: 16),

            sizeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -9),
            sizeLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            sizeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: soonPill.trailingAnchor, constant: 6)
        ])
        applyChrome()
    }

    required init?(coder: NSCoder) { nil }

    func reload(selected: Bool, sizeBadge: String?) {
        self.selected = selected
        sizeLabel.stringValue = sizeBadge ?? ""
        sizeLabel.isHidden = sizeBadge == nil
        applyChrome()
    }

    func refreshAppearance() {
        titleLabel.textColor = Theme.Colors.text
        sizeLabel.textColor = Theme.Colors.muted
        soonPill.textColor = Theme.Colors.onAccent
        soonPill.layer?.backgroundColor = Theme.Colors.accent.cgColor
        applyChrome()
        badge.needsDisplay = true
    }

    private func applyChrome() {
        layer?.cornerRadius = 9
        if selected {
            layer?.backgroundColor = Theme.Colors.navSelected.cgColor
        } else if hovering {
            layer?.backgroundColor = Theme.Colors.overlay.cgColor
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let action else { return }
        NSApp.sendAction(action, to: target, from: self)
    }

    override func mouseEntered(with event: NSEvent) {
        hovering = true
        applyChrome()
    }

    override func mouseExited(with event: NSEvent) {
        hovering = false
        applyChrome()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }
}

// MARK: - Cleanup bar + toast

final class CleanupBarView: NSView {
    var onClean: (() -> Void)?
    private let glass = GlassEffectView(kind: .floating)
    private let caption = makeLabel("You’ll free", size: 13, weight: .regular, color: Theme.Colors.muted)
    private let amount = makeLabel("0 MB", size: 16, weight: .bold, color: Theme.Colors.text)
    private let quota = makeLabel("", size: 12.5, weight: .regular, color: Theme.Colors.muted)
    private let button = PillButton(title: "Clean Up", style: .primary)
    private var widthConstraint: NSLayoutConstraint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        // Transparent overlay — list content stays visible underneath.
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = false

        glass.wantsLayer = true
        glass.layer?.cornerRadius = 26
        glass.layer?.masksToBounds = true
        glass.translatesAutoresizingMaskIntoConstraints = false
        addSubview(glass)

        let tint = NSView()
        tint.wantsLayer = true
        tint.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.28).cgColor
        tint.translatesAutoresizingMaskIntoConstraints = false
        glass.addSubview(tint)

        button.compact = false
        button.target = self
        button.action = #selector(clean)

        // Never truncate “You’ll free … / 500 MB free left”.
        for label in [caption, amount, quota] {
            label.lineBreakMode = .byClipping
            label.setContentCompressionResistancePriority(.required, for: .horizontal)
            label.setContentHuggingPriority(.required, for: .horizontal)
        }

        let left = NSStackView(views: [caption, amount])
        left.orientation = .horizontal
        left.spacing = 8
        left.alignment = .lastBaseline
        left.translatesAutoresizingMaskIntoConstraints = false
        left.setContentHuggingPriority(.required, for: .horizontal)
        left.setContentCompressionResistancePriority(.required, for: .horizontal)

        addSubview(left)
        addSubview(quota)
        addSubview(button)

        let width = widthAnchor.constraint(equalToConstant: 420)
        widthConstraint = width

        NSLayoutConstraint.activate([
            glass.leadingAnchor.constraint(equalTo: leadingAnchor),
            glass.trailingAnchor.constraint(equalTo: trailingAnchor),
            glass.topAnchor.constraint(equalTo: topAnchor),
            glass.bottomAnchor.constraint(equalTo: bottomAnchor),
            tint.leadingAnchor.constraint(equalTo: glass.leadingAnchor),
            tint.trailingAnchor.constraint(equalTo: glass.trailingAnchor),
            tint.topAnchor.constraint(equalTo: glass.topAnchor),
            tint.bottomAnchor.constraint(equalTo: glass.bottomAnchor),

            left.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            left.centerYAnchor.constraint(equalTo: centerYAnchor),
            quota.leadingAnchor.constraint(equalTo: left.trailingAnchor, constant: 14),
            quota.centerYAnchor.constraint(equalTo: centerYAnchor),
            button.leadingAnchor.constraint(equalTo: quota.trailingAnchor, constant: 18),
            button.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            button.centerYAnchor.constraint(equalTo: centerYAnchor),
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 132),
            heightAnchor.constraint(equalToConstant: 52),
            width
        ])
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        applyChrome()
    }

    required init?(coder: NSCoder) { nil }

    func refreshAppearance() {
        applyChrome()
        caption.textColor = Theme.Colors.muted
        amount.textColor = Theme.Colors.text
        quota.textColor = Theme.Colors.muted
    }

    private func applyChrome() {
        layer?.cornerRadius = 26
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.35
        layer?.shadowRadius = 22
        layer?.shadowOffset = CGSize(width: 0, height: -8)
        layer?.masksToBounds = false
        glass.layer?.cornerRadius = 26
    }

    func reload(state: AppState) {
        if state.screen == .largeFiles {
            let count = state.largeFileSelection.count
            let bytes = state.largeFileSelectedBytes
            caption.stringValue = "\(count) selected"
            amount.stringValue = AppFormat.bytes(bytes)
            quota.stringValue = ""
            quota.isHidden = true
            button.title = "Move to Trash"
            button.isEnabled = count > 0 && !state.isBusy
        } else {
            let bytes = state.selectedBytes
            caption.stringValue = "You’ll free"
            amount.stringValue = AppFormat.bytes(bytes)
            if state.isPro {
                quota.stringValue = ""
                quota.isHidden = true
            } else {
                // Full free-plan line, e.g. "500 MB free left".
                quota.stringValue = "\(AppFormat.freeQuota(state.license.remainingFreeBytes)) free left"
                quota.isHidden = false
            }
            let over = !state.isPro && bytes > state.license.remainingFreeBytes
            button.title = over ? "Unlock to clean" : "Clean Up"
            button.isEnabled = bytes > 0 && !state.isBusy
        }
        widthConstraint?.constant = measuredWidth()
        invalidateIntrinsicContentSize()
        needsLayout = true
        refreshAppearance()
    }

    private func measuredWidth() -> CGFloat {
        func textWidth(_ field: NSTextField) -> CGFloat {
            guard !field.isHidden, !field.stringValue.isEmpty else { return 0 }
            let font = field.font ?? .systemFont(ofSize: 13)
            return ceil((field.stringValue as NSString).size(withAttributes: [.font: font]).width)
        }
        let left = textWidth(caption) + 8 + textWidth(amount)
        let mid = quota.isHidden ? 0 : (14 + textWidth(quota))
        let btnTitle = button.title as NSString
        let btnFont = NSFont.systemFont(ofSize: 13, weight: .semibold)
        let btn = max(132, ceil(btnTitle.size(withAttributes: [.font: btnFont]).width) + 36)
        // padding leading 22 + gaps + trailing 14
        return 22 + left + mid + 18 + btn + 14
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: measuredWidth(), height: 52)
    }

    @objc private func clean() { onClean?() }
}

final class ToastView: NSView {
    var onUndo: (() -> Void)?
    private let label = makeLabel("", size: 13, weight: .medium, color: .white)
    private let undo = PillButton(title: "Undo", style: .ghost)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.backgroundColor = Theme.night.cgColor
        alphaValue = 0
        isHidden = true
        translatesAutoresizingMaskIntoConstraints = false
        undo.compact = true
        undo.style = .ghost
        // Toast ghost: light text on dark — override after style set via label tint
        undo.target = self
        undo.action = #selector(undoTap)
        let stack = NSStackView(views: [label, undo])
        stack.orientation = .horizontal
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])
    }

    required init?(coder: NSCoder) { nil }

    func show(message: String, undo: Bool) {
        label.stringValue = message
        self.undo.isHidden = !undo
        isHidden = false
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            animator().alphaValue = 1
        }
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(hide), object: nil)
        perform(#selector(hide), with: nil, afterDelay: undo ? 6.5 : 3.2)
    }

    @objc private func hide() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            animator().alphaValue = 0
        }, completionHandler: { self.isHidden = true })
    }

    @objc private func undoTap() { onUndo?(); hide() }
}

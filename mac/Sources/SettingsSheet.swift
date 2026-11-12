import AppKit

enum SettingsTab: Int, CaseIterable {
    case general
    case notifications
    case scanning
    case protectedItems
    case schedule
    case account

    /// Used when opening Settings from Account / Manage devices.
    static var pending: SettingsTab = .general

    var title: String {
        switch self {
        case .general: return "General"
        case .notifications: return "Notifications"
        case .scanning: return "Scanning"
        case .protectedItems: return "Protected"
        case .schedule: return "Schedule"
        case .account: return "Account"
        }
    }
}

/// Prototype Settings sheet (860×600, 200px nav) — matches handoff screens exactly.
final class SettingsController: NSViewController {
    private let initialTab: SettingsTab
    private var tab: SettingsTab
    private let sidebarStack = NSStackView()
    private let contentHost = NSView()
    private var navButtons: [SettingsTab: NSButton] = [:]
    private var largeFileLabel: NSTextField?
    /// Cached seat list from license-api (Account tab).
    private var knownDevices: [LicenseDeviceDTO] = []
    private var devicesLoading = false

    // Prototype sheet tokens (body.dk --cd / --cd2).
    private let sheetBG = NSColor(srgbRed: 0x1A / 255, green: 0x20 / 255, blue: 0x27 / 255, alpha: 1)
    private let sideBG = NSColor(srgbRed: 0x23 / 255, green: 0x2B / 255, blue: 0x34 / 255, alpha: 1)
    private let line = NSColor.white.withAlphaComponent(0.12)
    private let tx = NSColor(srgbRed: 0xF2 / 255, green: 0xF5 / 255, blue: 0xF8 / 255, alpha: 1)
    private let mu = NSColor(srgbRed: 0x9A / 255, green: 0xA8 / 255, blue: 0xB6 / 255, alpha: 1)
    private let navOn = NSColor.white.withAlphaComponent(0.14)

    init(initialTab: SettingsTab = SettingsTab.pending) {
        self.initialTab = initialTab
        self.tab = initialTab
        super.init(nibName: nil, bundle: nil)
        SettingsTab.pending = .general
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 860, height: 600))
        root.wantsLayer = true
        root.layer?.backgroundColor = sheetBG.cgColor
        root.layer?.cornerRadius = 26
        root.layer?.masksToBounds = true
        view = root

        // Sidebar — .stn: 200px, padding 20×12, border-right
        let sidebar = NSView()
        sidebar.wantsLayer = true
        sidebar.layer?.backgroundColor = sideBG.cgColor
        sidebar.translatesAutoresizingMaskIntoConstraints = false

        let divider = NSView()
        divider.wantsLayer = true
        divider.layer?.backgroundColor = line.cgColor
        divider.translatesAutoresizingMaskIntoConstraints = false

        let settingsTitle = makeLabel("Settings", size: 15, weight: .semibold, color: tx)

        sidebarStack.orientation = .vertical
        sidebarStack.alignment = .leading
        sidebarStack.spacing = 1 // .nv { margin-bottom: 1px }
        sidebarStack.translatesAutoresizingMaskIntoConstraints = false

        for item in SettingsTab.allCases {
            let button = NSButton(title: item.title, target: self, action: #selector(navTap(_:)))
            button.bezelStyle = .inline
            button.isBordered = false
            button.alignment = .left
            button.font = .systemFont(ofSize: 13, weight: .medium)
            button.contentTintColor = tx
            button.identifier = NSUserInterfaceItemIdentifier("\(item.rawValue)")
            button.wantsLayer = true
            button.layer?.cornerRadius = 9
            button.translatesAutoresizingMaskIntoConstraints = false
            // .stn .nv { padding: 7px 10px }
            button.heightAnchor.constraint(equalToConstant: 32).isActive = true
            navButtons[item] = button
            sidebarStack.addArrangedSubview(button)
            button.widthAnchor.constraint(equalTo: sidebarStack.widthAnchor).isActive = true
        }

        let done = makeGhostButton("Done")
        done.compact = true
        done.target = self
        done.action = #selector(close)

        sidebar.addSubview(settingsTitle)
        sidebar.addSubview(sidebarStack)
        sidebar.addSubview(done)
        settingsTitle.translatesAutoresizingMaskIntoConstraints = false
        done.translatesAutoresizingMaskIntoConstraints = false

        contentHost.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(sidebar)
        root.addSubview(divider)
        root.addSubview(contentHost)

        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: root.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 200),

            divider.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            divider.topAnchor.constraint(equalTo: root.topAnchor),
            divider.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),

            // .stn h3 { margin: 0 8px 14px } inside padding 20×12 → left 20, top 20
            settingsTitle.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 20),
            settingsTitle.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 20),

            // nav inset: padding 12 horizontal
            sidebarStack.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 12),
            sidebarStack.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -12),
            sidebarStack.topAnchor.constraint(equalTo: settingsTitle.bottomAnchor, constant: 14),

            // Done pinned to bottom (screenshots); inset matches .btn margin 8px + padding 12
            done.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 20),
            done.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor, constant: -20),

            contentHost.leadingAnchor.constraint(equalTo: divider.trailingAnchor),
            contentHost.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            contentHost.topAnchor.constraint(equalTo: root.topAnchor),
            contentHost.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])

        // Left-align nav titles inside the pill (NSButton centers by default).
        for button in navButtons.values {
            button.imagePosition = .imageLeading
            if let cell = button.cell as? NSButtonCell {
                cell.alignment = .left
            }
        }

        refreshNavChrome()
        renderTab()
    }

    @objc private func navTap(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue, let value = Int(raw),
              let next = SettingsTab(rawValue: value) else { return }
        tab = next
        refreshNavChrome()
        renderTab()
    }

    private func refreshNavChrome() {
        for (item, button) in navButtons {
            let on = item == tab
            button.layer?.backgroundColor = on ? navOn.cgColor : NSColor.clear.cgColor
            button.contentTintColor = tx
            // Horizontal text inset ≈ .nv padding 10px
            button.attributedTitle = NSAttributedString(
                string: "  \(item.title)",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                    .foregroundColor: tx
                ]
            )
        }
    }

    private func renderTab() {
        contentHost.subviews.forEach { $0.removeFromSuperview() }

        let body: NSView
        switch tab {
        case .general: body = buildGeneral()
        case .notifications: body = buildNotifications()
        case .scanning: body = buildScanning()
        case .protectedItems: body = buildProtected()
        case .schedule: body = buildSchedule()
        case .account: body = buildAccount()
        }
        body.translatesAutoresizingMaskIntoConstraints = false

        // Flipped so short content pins to the TOP (AppKit scroll docs sit at bottom otherwise).
        let doc = FlippedView()
        doc.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(body)

        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = doc

        contentHost.addSubview(scroll)
        // .stc { padding: 26px 28px } — content starts at the top
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: contentHost.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: contentHost.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: contentHost.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: contentHost.bottomAnchor),

            doc.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            doc.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            doc.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),

            body.leadingAnchor.constraint(equalTo: doc.leadingAnchor, constant: 28),
            body.trailingAnchor.constraint(equalTo: doc.trailingAnchor, constant: -28),
            body.topAnchor.constraint(equalTo: doc.topAnchor, constant: 22),
            body.bottomAnchor.constraint(equalTo: doc.bottomAnchor, constant: -28)
        ])
    }

    // MARK: - Tabs

    private func buildGeneral() -> NSView {
        let license = LicenseStore.current
        let stack = sectionStack(
            title: "General",
            subtitle: "How iClearer behaves on your Mac."
        )

        let appearance = SettingsSegment(
            labels: ["Light", "Dark"],
            selected: license.appearance == "light" ? 0 : 1
        ) { [weak self] idx in
            let value = idx == 0 ? "light" : "dark"
            LicenseStore.update { $0.appearance = value }
            NSApp.appearance = value == "light"
                ? NSAppearance(named: .aqua)
                : NSAppearance(named: .darkAqua)
            self?.renderTab()
        }
        addFullWidthRow(stack, settingsRow(
            title: "Appearance",
            subtitle: "Match your Mac, or choose one",
            trailing: appearance
        ))

        let trash = SettingsToggle(on: true, enabled: false) { _ in }
        addFullWidthRow(stack, settingsRow(
            title: "Move to Trash",
            subtitle: "iClearer never deletes permanently. This is always on.",
            trailing: trash
        ))

        let login = SettingsToggle(on: license.launchAtLogin, enabled: true) { [weak self] on in
            if !LicenseStore.current.plan.isSubscription {
                AppState.shared.showSheet(.upgrade, reason: "Open at login is part of monthly and yearly plans.")
                self?.renderTab()
                return
            }
            LicenseStore.update { $0.launchAtLogin = on }
        }
        addFullWidthRow(stack, settingsRow(
            title: "Open at login",
            subtitle: "Starts the menu bar monitor when you log in",
            trailing: login,
            badge: "1.1"
        ))

        let menuBar = SettingsToggle(on: license.menuBarItem, enabled: true) { [weak self] on in
            if !LicenseStore.current.plan.isSubscription {
                AppState.shared.showSheet(.upgrade, reason: "Menu bar monitor is part of monthly and yearly plans.")
                self?.renderTab()
                return
            }
            LicenseStore.update { $0.menuBarItem = on }
        }
        addFullWidthRow(stack, settingsRow(
            title: "Show in menu bar",
            subtitle: "Free space at a glance. Monthly and yearly plans.",
            trailing: menuBar,
            badge: "1.1",
            isLast: true
        ))
        return stack
    }

    private func buildNotifications() -> NSView {
        let license = LicenseStore.current
        let stack = sectionStack(
            title: "Notifications",
            subtitle: "What we email and notify you about."
        )

        let email = license.email.isEmpty ? "your email" : license.email
        addFullWidthRow(stack, settingsRow(
            title: "License, receipts and security",
            subtitle: "Required for your account. Sent to \(email)",
            trailing: SettingsToggle(on: true, enabled: false) { _ in }
        ))

        let updates = SettingsToggle(on: license.marketingOptIn, enabled: true) { on in
            LicenseStore.setMarketingOptIn(on)
        }
        addFullWidthRow(stack, settingsRow(
            title: "Product updates and new products",
            subtitle: "New versions, new features and other iClearer products",
            trailing: updates
        ))

        let low = SettingsToggle(on: license.lowSpaceAlerts, enabled: true) { [weak self] on in
            if !LicenseStore.current.plan.isSubscription {
                AppState.shared.showSheet(.upgrade, reason: "Low space alerts are part of monthly and yearly plans.")
                self?.renderTab()
                return
            }
            LicenseStore.update { $0.lowSpaceAlerts = on }
        }
        addFullWidthRow(stack, settingsRow(
            title: "Low space alerts",
            subtitle: "Notify me when free space drops below 20 GB. Monthly and yearly plans.",
            trailing: low,
            badge: "1.1"
        ))

        let scanDone = SettingsToggle(on: license.notifyScanFinished, enabled: true) { on in
            LicenseStore.update { $0.notifyScanFinished = on }
        }
        addFullWidthRow(stack, settingsRow(
            title: "Scan finished",
            subtitle: "Show a notification when a scan completes",
            trailing: scanDone,
            isLast: true
        ))
        return stack
    }

    private func buildScanning() -> NSView {
        let license = LicenseStore.current
        let stack = sectionStack(
            title: "Scanning",
            subtitle: "Choose what iClearer looks for."
        )

        addFullWidthRow(stack, settingsRow(
            title: "Everyday junk",
            subtitle: "Caches, logs, installers, Mail cache",
            trailing: SettingsToggle(on: license.scanEveryday, enabled: true) { on in
                LicenseStore.update { $0.scanEveryday = on }
            }
        ))

        addFullWidthRow(stack, settingsRow(
            title: "iOS backups and updates",
            subtitle: "Old device backups made in Finder",
            trailing: SettingsToggle(on: license.scanBackups, enabled: true) { on in
                LicenseStore.update { $0.scanBackups = on }
            }
        ))

        addFullWidthRow(stack, settingsRow(
            title: "Builders and AI tools",
            subtitle: "Xcode, npm, pip, Homebrew, Docker, AI models",
            trailing: SettingsToggle(on: license.scanBuilders, enabled: true) { on in
                LicenseStore.update { $0.scanBuilders = on }
            }
        ))

        let sizeLabel = makeLabel(
            "Show files larger than \(AppFormat.freeQuota(Int64(license.largeFileMinMB) * 1_000_000))",
            size: 12.5, weight: .regular, color: mu
        )
        largeFileLabel = sizeLabel

        let slider = NSSlider(
            value: Double(license.largeFileMinMB),
            minValue: 500,
            maxValue: 5000,
            target: self,
            action: #selector(largeFileChanged(_:))
        )
        slider.numberOfTickMarks = 0
        slider.isContinuous = true
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: 180).isActive = true

        let left = NSStackView(views: [
            makeLabel("Large file size", size: 13.5, weight: .semibold, color: tx),
            sizeLabel
        ])
        left.orientation = .vertical
        left.alignment = .leading
        left.spacing = 1

        let row = settingsRowViews(left: left, trailing: slider, isLast: true)
        addFullWidthRow(stack, row)
        return stack
    }

    private func buildProtected() -> NSView {
        let license = LicenseStore.current
        let stack = sectionStack(
            title: "Never touch",
            subtitle: "iClearer will skip these, always."
        )

        let always = groupLabel("ALWAYS PROTECTED")
        stack.addArrangedSubview(always)
        stack.setCustomSpacing(8, after: always)

        let protected: [(String, String)] = [
            ("Keychain", "Passwords and certificates"),
            ("Accounts", "Mail, iCloud and other sign-ins"),
            ("Editor user data", "Settings and extensions in Cursor, VS Code and similar"),
            ("Tokens, SSH keys, .env files", "Credentials in your developer folders"),
            ("Git folders", "Your repositories and history")
        ]
        for (idx, item) in protected.enumerated() {
            addFullWidthRow(stack, protectedRow(
                name: item.0,
                detail: item.1,
                isLast: idx == protected.count - 1 && license.protectedPaths.isEmpty
            ))
        }

        let yours = groupLabel("YOUR PROTECTED ITEMS")
        yours.alignment = .left
        stack.setCustomSpacing(20, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(yours)
        stack.setCustomSpacing(8, after: yours)

        if !license.isPro {
            let ban = upgradeBanner(
                text: "Adding your own protected items is part of iClearer.",
                tallerButtons: true
            )
            addFullWidthRow(stack, ban)
        } else if license.protectedPaths.isEmpty {
            let empty = makeLabel("Nothing added yet.", size: 12.5, weight: .regular, color: mu)
            empty.alignment = .left
            stack.addArrangedSubview(empty)
        } else {
            for (idx, path) in license.protectedPaths.enumerated() {
                let remove = tallerSettingsButton("Remove")
                remove.identifier = NSUserInterfaceItemIdentifier(path)
                remove.target = self
                remove.action = #selector(removeProtected(_:))
                addFullWidthRow(stack, settingsRow(
                    title: (path as NSString).lastPathComponent,
                    subtitle: path,
                    trailing: remove,
                    isLast: idx == license.protectedPaths.count - 1
                ))
            }
        }

        let add = tallerSettingsButton("Add folder…")
        add.target = self
        add.action = #selector(addProtectedFolder)
        if !license.isPro {
            add.title = "Add folder…"
            add.action = #selector(openUpgrade)
        }
        stack.setCustomSpacing(12, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(add)
        return stack
    }

    private func buildSchedule() -> NSView {
        let license = LicenseStore.current
        let scheduleTitle = makeLabel("Schedule", size: 21, weight: .bold, color: tx)
        scheduleTitle.alignment = .left
        let titleRow = NSStackView()
        titleRow.orientation = .horizontal
        titleRow.spacing = 8
        titleRow.alignment = .centerY
        titleRow.addArrangedSubview(scheduleTitle)
        titleRow.addArrangedSubview(chipBadge("1.1"))

        let subtitle = makeLabel("Scan automatically and tell you what it found.", size: 14, weight: .regular, color: mu)
        subtitle.alignment = .left
        let stack = NSStackView(views: [titleRow, subtitle])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.setCustomSpacing(20, after: subtitle)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let yearly = license.plan.isSubscription
        if !yearly {
            addFullWidthRow(stack, upgradeBanner(
                text: "Scheduled scans are part of monthly and yearly plans."
            ))
            stack.setCustomSpacing(12, after: stack.arrangedSubviews.last!)
        }

        let sched = SettingsToggle(on: license.scheduleEnabled && yearly, enabled: true) { [weak self] on in
            if !LicenseStore.current.plan.isSubscription {
                AppState.shared.showSheet(.upgrade, reason: "Scheduled scans are part of monthly and yearly plans.")
                self?.renderTab()
                return
            }
            LicenseStore.update { $0.scheduleEnabled = on }
        }
        addFullWidthRow(stack, settingsRow(
            title: "Scan on a schedule",
            subtitle: "iClearer never cleans by itself",
            trailing: sched
        ))

        let labels = ["Daily", "Weekly", "Monthly"]
        let selected: Int = {
            switch license.scheduleFrequency {
            case "Daily": return 0
            case "Monthly": return 2
            default: return 1
            }
        }()
        let freq = SettingsSegment(labels: labels, selected: selected) { idx in
            if !LicenseStore.current.plan.isSubscription {
                AppState.shared.showSheet(.upgrade, reason: "Scheduled scans are part of monthly and yearly plans.")
                return
            }
            LicenseStore.update { $0.scheduleFrequency = labels[idx] }
        }
        addFullWidthRow(stack, settingsRow(
            title: "How often",
            subtitle: "",
            trailing: freq,
            isLast: true
        ))
        return stack
    }

    private func buildAccount() -> NSView {
        // Merge of Settings→Account mock + Account sheet mock:
        // Account
        // email + plan · priority support
        // YOUR MACS · 1 OF N USED
        // This Mac … Active now … This Mac
        // Email updates (toggle)
        // License key + Copy
        // Restore purchase · Sign out
        // (Done stays in the Settings sidebar)
        let license = LicenseStore.current
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false

        let title = makeLabel("Account", size: 21, weight: .bold, color: tx)
        title.alignment = .left
        stack.addArrangedSubview(title)
        stack.setCustomSpacing(20, after: title)

        // Email row
        let emailTitle = license.email.isEmpty ? "No email yet" : license.email
        let planCaption: String = {
            switch license.plan {
            case .monthly, .yearly: return "\(license.plan.displayName) · priority support"
            case .once: return "\(license.plan.displayName) · covers version 1, updates until version 2"
            case .free: return LicensePlan.free.displayName
            }
        }()
        let emailRow = settingsRow(
            title: emailTitle,
            subtitle: planCaption,
            trailing: NSView()
        )
        stack.addArrangedSubview(emailRow)
        pinFullWidth(emailRow, in: stack)

        if license.isPro {
            refreshDevicesIfNeeded()
            let seatsTotal = max(1, license.macSeats)
            let seatsUsed = knownDevices.isEmpty ? (license.key.isEmpty ? 0 : 1) : knownDevices.count
            let seats = groupLabel("YOUR MACS · \(seatsUsed) OF \(seatsTotal) USED")
            seats.alignment = .left
            stack.setCustomSpacing(8, after: stack.arrangedSubviews.last!)
            stack.addArrangedSubview(seats)
            stack.setCustomSpacing(4, after: seats)

            let devices = knownDevices.isEmpty
                ? [LicenseDeviceDTO(
                    id: nil,
                    device_hash: DeviceIdentity.deviceHash,
                    device_name: DeviceIdentity.deviceName,
                    app_version: nil,
                    last_seen_at: nil,
                    created_at: nil
                )]
                : knownDevices

            for device in devices {
                let isThis = device.device_hash == DeviceIdentity.deviceHash
                let trimmedName = device.device_name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let name = trimmedName.isEmpty
                    ? (isThis ? DeviceIdentity.deviceName : "Mac")
                    : trimmedName
                let subtitle = isThis ? "This Mac · Active now" : "Linked to your license"
                // No Remove — seats are permanent once used (stops seat hopping).
                let trailing: NSView
                if isThis {
                    let badge = tallerSettingsButton("This Mac")
                    badge.isEnabled = false
                    trailing = badge
                } else {
                    let linked = tallerSettingsButton("Linked")
                    linked.isEnabled = false
                    trailing = linked
                }
                let deviceRow = settingsRow(title: name, subtitle: subtitle, trailing: trailing)
                stack.addArrangedSubview(deviceRow)
                pinFullWidth(deviceRow, in: stack)
            }

            let hint = makeLabel(
                "Signing in on a new Mac uses one seat. Seats stay linked — email support@iclearer.com if you replace a Mac.",
                size: 12, weight: .regular, color: mu
            )
            hint.alignment = .left
            hint.maximumNumberOfLines = 2
            hint.lineBreakMode = .byWordWrapping
            stack.setCustomSpacing(10, after: stack.arrangedSubviews.last!)
            stack.addArrangedSubview(hint)
            pinFullWidth(hint, in: stack)

            let upgrade = tallerSettingsButton("Upgrade plan", accent: true)
            upgrade.target = self
            upgrade.action = #selector(openUpgrade)
            let upgradeRow = settingsRow(
                title: "Change plan or Macs",
                subtitle: "Switch monthly, yearly, or one-time — or add Mac seats. Same license key.",
                trailing: upgrade
            )
            stack.setCustomSpacing(14, after: hint)
            stack.addArrangedSubview(upgradeRow)
            pinFullWidth(upgradeRow, in: stack)
        } else {
            let unlock = tallerSettingsButton("Unlock", accent: true)
            unlock.target = self
            unlock.action = #selector(openUpgrade)
            let freeRow = settingsRow(
                title: "Free plan",
                subtitle: "\(AppFormat.freeQuota(license.remainingFreeBytes)) of cleanup left. Scanning is always free.",
                trailing: unlock
            )
            stack.addArrangedSubview(freeRow)
            pinFullWidth(freeRow, in: stack)
        }

        // Email updates — place before license (only difference between the two mocks)
        let updatesRow = settingsRow(
            title: "Email updates",
            subtitle: "Product updates and new products from iClearer",
            trailing: SettingsToggle(on: license.marketingOptIn, enabled: true) { on in
                LicenseStore.setMarketingOptIn(on)
            }
        )
        stack.addArrangedSubview(updatesRow)
        pinFullWidth(updatesRow, in: stack)

        // License key
        if license.isPro {
            let copy = tallerSettingsButton("Copy")
            copy.target = self
            copy.action = #selector(copyKey)
            let keyText = license.key.isEmpty ? "ICLR-4F2A-9C71-B03E" : license.key
            let keyRow = settingsRow(
                title: "License key",
                subtitle: keyText,
                trailing: copy
            )
            stack.addArrangedSubview(keyRow)
            pinFullWidth(keyRow, in: stack)
        }

        let refresh = tallerSettingsButton("Refresh plan")
        refresh.target = self
        refresh.action = #selector(refreshPlan)
        let restore = tallerSettingsButton("Restore purchase")
        restore.target = self
        restore.action = #selector(restorePurchase)
        let signOutBtn = tallerSettingsButton("Sign out")
        signOutBtn.target = self
        signOutBtn.action = #selector(signOut)
        // Paid: Upgrade is also in the footer so it stays visible without scrolling.
        var footerButtons: [NSView] = [refresh, restore, signOutBtn]
        if license.isPro {
            let upgradeFooter = tallerSettingsButton("Upgrade plan", accent: true)
            upgradeFooter.target = self
            upgradeFooter.action = #selector(openUpgrade)
            footerButtons.insert(upgradeFooter, at: 0)
        }
        let footer = NSStackView(views: footerButtons)
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 10
        stack.setCustomSpacing(8, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(footer)
        return stack
    }

    // MARK: - Helpers

    private func sectionStack(title: String, subtitle: String) -> NSStackView {
        let t = makeLabel(title, size: 21, weight: .bold, color: tx)
        t.alignment = .left
        let s = makeLabel(subtitle, size: 14, weight: .regular, color: mu)
        s.alignment = .left
        let stack = NSStackView(views: [t, s])
        stack.orientation = .vertical
        // Leading keeps titles on the left; rows are stretched via pinFullWidth(_:).
        stack.alignment = .leading
        stack.spacing = 6
        stack.setCustomSpacing(20, after: s)
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    /// Stretch a settings row to the stack width so trailing controls sit on the right.
    private func pinFullWidth(_ view: NSView, in stack: NSStackView) {
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    private func addFullWidthRow(_ stack: NSStackView, _ row: NSView) {
        stack.addArrangedSubview(row)
        pinFullWidth(row, in: stack)
    }

    private func groupLabel(_ text: String) -> NSTextField {
        makeLabel(text, size: 11, weight: .semibold, color: mu)
    }

    /// Account + Protected only — same pill as Change email, +30% height.
    private func tallerSettingsButton(_ title: String, accent: Bool = false) -> PillButton {
        let button = accent ? makeAccentButton(title) : makeGhostButton(title)
        button.compact = true
        button.heightMultiplier = 1.3
        return button
    }

    private func chipBadge(_ text: String) -> NSView {
        // Round “1.1” version chip — fixed size so it never collapses in rows.
        let font = NSFont.systemFont(ofSize: 11.5, weight: .semibold)
        let textW = ceil((text as NSString).size(withAttributes: [.font: font]).width)
        let padH: CGFloat = 9
        let padV: CGFloat = 3
        let width = textW + padH * 2
        let height: CGFloat = 11.5 + padV * 2

        let label = makeLabel(text, size: 11.5, weight: .semibold, color: tx)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        let pad = NSView()
        pad.wantsLayer = true
        pad.layer?.cornerRadius = height / 2
        pad.layer?.backgroundColor = sideBG.cgColor
        pad.layer?.borderWidth = 1
        pad.layer?.borderColor = line.cgColor
        pad.translatesAutoresizingMaskIntoConstraints = false
        pad.addSubview(label)
        NSLayoutConstraint.activate([
            pad.widthAnchor.constraint(equalToConstant: width),
            pad.heightAnchor.constraint(equalToConstant: height),
            label.centerXAnchor.constraint(equalTo: pad.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: pad.centerYAnchor)
        ])
        pad.setContentHuggingPriority(.required, for: .horizontal)
        pad.setContentCompressionResistancePriority(.required, for: .horizontal)
        pad.setContentHuggingPriority(.required, for: .vertical)
        pad.setContentCompressionResistancePriority(.required, for: .vertical)
        return pad
    }

    private func upgradeBanner(text: String, tallerButtons: Bool = false) -> NSView {
        let lock = NSImageView(image: NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil)!)
        lock.contentTintColor = .white
        lock.translatesAutoresizingMaskIntoConstraints = false
        let badge = NSView()
        badge.wantsLayer = true
        badge.layer?.cornerRadius = 9
        badge.layer?.backgroundColor = NSColor(srgbRed: 0x82 / 255, green: 0xBC / 255, blue: 0xE7 / 255, alpha: 1).cgColor
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(lock)
        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: 18),
            badge.heightAnchor.constraint(equalToConstant: 18),
            lock.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            lock.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            lock.widthAnchor.constraint(equalToConstant: 10),
            lock.heightAnchor.constraint(equalToConstant: 10)
        ])

        let copy = makeLabel(text, size: 12.5, weight: .regular, color: mu)
        copy.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let unlock = tallerButtons ? tallerSettingsButton("Unlock") : {
            let b = makeGhostButton("Unlock")
            b.compact = true
            return b
        }()
        unlock.target = self
        unlock.action = #selector(openUpgrade)

        let wrap = NSView()
        wrap.wantsLayer = true
        wrap.layer?.cornerRadius = 14
        wrap.layer?.backgroundColor = sideBG.cgColor
        wrap.translatesAutoresizingMaskIntoConstraints = false
        let inner = NSStackView(views: [badge, copy, unlock])
        inner.orientation = .horizontal
        inner.alignment = .centerY
        inner.spacing = 10
        inner.translatesAutoresizingMaskIntoConstraints = false
        wrap.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 14),
            inner.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -14),
            inner.topAnchor.constraint(equalTo: wrap.topAnchor, constant: 11),
            inner.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -11)
        ])
        return wrap
    }

    /// `.fr` row: padding 12 0, border-bottom, title 13.5 / subtitle 12.5.
    private func settingsRow(
        title: String,
        subtitle: String,
        trailing: NSView,
        badge: String? = nil,
        isLast: Bool = false
    ) -> NSView {
        let titleLabel = makeLabel(title, size: 14, weight: .semibold, color: tx)
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        let titleStack = NSStackView(views: [titleLabel])
        titleStack.orientation = .horizontal
        titleStack.spacing = 8
        titleStack.alignment = .centerY
        titleStack.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        if let badge {
            let chip = chipBadge(badge)
            titleStack.addArrangedSubview(chip)
        }

        let leftViews: [NSView]
        if subtitle.isEmpty {
            leftViews = [titleStack]
        } else {
            leftViews = [titleStack, makeLabel(subtitle, size: 13, weight: .regular, color: mu)]
        }
        let left = NSStackView(views: leftViews)
        left.orientation = .vertical
        left.alignment = .leading
        left.spacing = 3
        return settingsRowViews(left: left, trailing: trailing, isLast: isLast)
    }

    private func settingsRowViews(left: NSView, trailing: NSView, isLast: Bool) -> NSView {
        left.setContentHuggingPriority(.defaultLow, for: .horizontal)
        left.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        trailing.setContentHuggingPriority(.required, for: .horizontal)
        trailing.translatesAutoresizingMaskIntoConstraints = false

        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false
        left.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(left)
        row.addSubview(trailing)

        // Airy rows like the General mock (~20px above/below text block).
        NSLayoutConstraint.activate([
            left.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            left.topAnchor.constraint(equalTo: row.topAnchor, constant: 20),
            left.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -20),
            left.trailingAnchor.constraint(lessThanOrEqualTo: trailing.leadingAnchor, constant: -16),

            trailing.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            trailing.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            row.widthAnchor.constraint(greaterThanOrEqualToConstant: 200)
        ])

        if !isLast {
            let hair = NSView()
            hair.wantsLayer = true
            hair.layer?.backgroundColor = line.cgColor
            hair.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(hair)
            NSLayoutConstraint.activate([
                hair.leadingAnchor.constraint(equalTo: row.leadingAnchor),
                hair.trailingAnchor.constraint(equalTo: row.trailingAnchor),
                hair.bottomAnchor.constraint(equalTo: row.bottomAnchor),
                hair.heightAnchor.constraint(equalToConstant: 1)
            ])
        }
        return row
    }

    private func protectedRow(name: String, detail: String, isLast: Bool) -> NSView {
        let lock = NSImageView(image: NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "Protected")!)
        lock.contentTintColor = .white
        lock.translatesAutoresizingMaskIntoConstraints = false
        let badge = NSView()
        badge.wantsLayer = true
        badge.layer?.cornerRadius = 9
        // Prototype lock bead gradient approx
        badge.layer?.backgroundColor = NSColor(srgbRed: 0x3B / 255, green: 0x7C / 255, blue: 0xB0 / 255, alpha: 1).cgColor
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(lock)
        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: 18),
            badge.heightAnchor.constraint(equalToConstant: 18),
            lock.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            lock.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            lock.widthAnchor.constraint(equalToConstant: 10),
            lock.heightAnchor.constraint(equalToConstant: 10)
        ])

        let text = NSStackView(views: [
            makeLabel(name, size: 13.5, weight: .semibold, color: tx),
            makeLabel(detail, size: 12.5, weight: .regular, color: mu)
        ])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 1

        let left = NSStackView(views: [badge, text])
        left.orientation = .horizontal
        left.alignment = .centerY
        left.spacing = 12
        left.translatesAutoresizingMaskIntoConstraints = false

        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(left)
        NSLayoutConstraint.activate([
            left.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            left.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            left.topAnchor.constraint(equalTo: row.topAnchor, constant: 12),
            left.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -12)
        ])
        if !isLast {
            let hair = NSView()
            hair.wantsLayer = true
            hair.layer?.backgroundColor = line.cgColor
            hair.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(hair)
            NSLayoutConstraint.activate([
                hair.leadingAnchor.constraint(equalTo: row.leadingAnchor),
                hair.trailingAnchor.constraint(equalTo: row.trailingAnchor),
                hair.bottomAnchor.constraint(equalTo: row.bottomAnchor),
                hair.heightAnchor.constraint(equalToConstant: 1)
            ])
        }
        return row
    }

    // MARK: - Actions

    @objc private func largeFileChanged(_ sender: NSSlider) {
        let stepped = Int((sender.doubleValue / 500.0).rounded() * 500)
        let mb = max(500, min(5000, stepped))
        sender.doubleValue = Double(mb)
        LicenseStore.update { $0.largeFileMinMB = mb }
        largeFileLabel?.stringValue = "Show files larger than \(AppFormat.freeQuota(Int64(mb) * 1_000_000))"
    }

    @objc private func addProtectedFolder() {
        guard LicenseStore.current.isPro else {
            openUpgrade()
            return
        }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: view.window!) { [weak self] result in
            guard result == .OK, let url = panel.url else { return }
            LicenseStore.update {
                if !$0.protectedPaths.contains(url.path) {
                    $0.protectedPaths.append(url.path)
                }
            }
            self?.renderTab()
        }
    }

    @objc private func removeProtected(_ sender: NSButton) {
        guard let path = sender.identifier?.rawValue else { return }
        LicenseStore.update { $0.protectedPaths.removeAll { $0 == path } }
        renderTab()
    }

    @objc private func copyKey() {
        var key = LicenseStore.current.key
        if key.isEmpty { key = "ICLR-4F2A-9C71-B03E" }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(key, forType: .string)
        AppState.shared.showToast("License key copied.")
    }

    private func refreshDevicesIfNeeded() {
        let license = LicenseStore.current
        guard license.isPro, !license.email.isEmpty, !license.key.isEmpty, !devicesLoading else { return }
        devicesLoading = true
        Task {
            let response = await LicenseAPI.listDevices(email: license.email, key: license.key)
            await MainActor.run {
                self.devicesLoading = false
                if response.ok {
                    self.knownDevices = response.devices ?? []
                    if let macs = response.macs {
                        LicenseStore.update { $0.macSeats = max(1, macs) }
                    }
                    if self.tab == .account { self.renderTab() }
                }
            }
        }
    }

    @objc private func refreshPlan() {
        let email = LicenseStore.current.email
        let key = LicenseStore.current.key
        guard !email.isEmpty, !key.isEmpty else {
            AppState.shared.showToast("Sign in with your email and license key first.")
            return
        }
        AppState.shared.showToast("Refreshing your plan…")
        Task {
            let response = await LicenseAPI.heartbeat(email: email, key: key)
            await MainActor.run {
                if response.ok {
                    LicenseStore.applyRemote(response)
                    self.renderTab()
                    AppState.shared.showToast(
                        LicenseStore.current.isPro
                            ? "You’re on \(LicenseStore.current.plan.displayName)."
                            : "Still on the free plan. Finish checkout, then tap Refresh plan."
                    )
                } else {
                    AppState.shared.showToast(response.error ?? "Could not refresh. Try again in a moment.")
                }
            }
        }
    }

    @objc private func restorePurchase() {
        let email = LicenseStore.current.email
        let key = LicenseStore.current.key
        guard !email.isEmpty, !key.isEmpty else {
            AppState.shared.showToast("Sign in with your email and license key first.")
            return
        }
        AppState.shared.showToast("Checking your license…")
        Task {
            let response = await LicenseAPI.activate(email: email, key: key)
            await MainActor.run {
                if response.ok {
                    LicenseStore.applyRemote(response)
                    self.renderTab()
                    AppState.shared.showToast(response.message ?? "Purchase restored.")
                } else {
                    AppState.shared.showToast(response.error ?? "No active purchase found.")
                }
            }
        }
    }

    @objc private func openUpgrade() {
        dismissSheet(from: view)
        AppState.shared.showSheet(.upgrade)
    }

    @objc private func signOut() {
        LicenseStore.signOut()
        LicenseStore.update {
            $0.email = ""
            $0.onboardingComplete = false
        }
        AppState.shared.showToast("Signed out.")
        dismissSheet(from: view)
        DispatchQueue.main.async { AppState.shared.showSheet(.onboarding) }
    }

    @objc private func close() { dismissSheet(from: view) }
}

// MARK: - Prototype toggle (.tg 42×26, on = #34C759)

final class SettingsToggle: NSControl {
    private var isOn: Bool
    private var isEnabledToggle: Bool
    private let change: (Bool) -> Void
    private let knob = NSView()

    init(on: Bool, enabled: Bool, change: @escaping (Bool) -> Void) {
        self.isOn = on
        self.isEnabledToggle = enabled
        self.change = change
        super.init(frame: NSRect(x: 0, y: 0, width: 42, height: 26))
        wantsLayer = true
        layer?.cornerRadius = 13
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 42).isActive = true
        heightAnchor.constraint(equalToConstant: 26).isActive = true

        knob.wantsLayer = true
        knob.layer?.backgroundColor = NSColor.white.cgColor
        knob.layer?.cornerRadius = 10
        knob.layer?.shadowColor = NSColor.black.cgColor
        knob.layer?.shadowOpacity = 0.35
        knob.layer?.shadowRadius = 2
        knob.layer?.shadowOffset = CGSize(width: 0, height: -1)
        knob.translatesAutoresizingMaskIntoConstraints = false
        addSubview(knob)
        NSLayoutConstraint.activate([
            knob.widthAnchor.constraint(equalToConstant: 20),
            knob.heightAnchor.constraint(equalToConstant: 20),
            knob.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        apply()
    }

    required init?(coder: NSCoder) { nil }

    override func mouseDown(with event: NSEvent) {
        guard isEnabledToggle else { return }
        isOn.toggle()
        apply()
        change(isOn)
    }

    private var knobLeading: NSLayoutConstraint?

    private func apply() {
        layer?.backgroundColor = isOn
            ? NSColor(srgbRed: 0x34 / 255, green: 0xC7 / 255, blue: 0x59 / 255, alpha: 1).cgColor
            : NSColor.white.withAlphaComponent(0.12).cgColor
        alphaValue = isEnabledToggle ? 1 : 0.4
        knobLeading?.isActive = false
        let c = knob.leadingAnchor.constraint(equalTo: leadingAnchor, constant: isOn ? 19 : 3)
        c.isActive = true
        knobLeading = c
    }
}

// MARK: - Prototype segment (.sg pill)

final class SettingsSegment: NSView {
    private let labels: [String]
    private var selected: Int
    private let onChange: (Int) -> Void
    private var buttons: [NSButton] = []

    init(labels: [String], selected: Int, onChange: @escaping (Int) -> Void) {
        self.labels = labels
        self.selected = selected
        self.onChange = onChange
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 99
        layer?.backgroundColor = NSColor(srgbRed: 0x23 / 255, green: 0x2B / 255, blue: 0x34 / 255, alpha: 1).cgColor
        translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2)
        ])

        for (idx, title) in labels.enumerated() {
            let btn = NSButton(title: title, target: self, action: #selector(tap(_:)))
            btn.bezelStyle = .inline
            btn.isBordered = false
            btn.font = .systemFont(ofSize: 12, weight: .medium)
            btn.tag = idx
            btn.wantsLayer = true
            btn.layer?.cornerRadius = 99
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.heightAnchor.constraint(equalToConstant: 24).isActive = true
            buttons.append(btn)
            stack.addArrangedSubview(btn)
        }
        refresh()
    }

    required init?(coder: NSCoder) { nil }

    @objc private func tap(_ sender: NSButton) {
        selected = sender.tag
        refresh()
        onChange(selected)
    }

    private func refresh() {
        let tx = NSColor(srgbRed: 0xF2 / 255, green: 0xF5 / 255, blue: 0xF8 / 255, alpha: 1)
        let onTx = NSColor(srgbRed: 0x14 / 255, green: 0x20 / 255, blue: 0x2B / 255, alpha: 1)
        for (idx, btn) in buttons.enumerated() {
            let on = idx == selected
            btn.layer?.backgroundColor = on ? NSColor.white.cgColor : NSColor.clear.cgColor
            btn.attributedTitle = NSAttributedString(
                string: "  \(labels[idx])  ",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                    .foregroundColor: on ? onTx : tx
                ]
            )
        }
    }
}

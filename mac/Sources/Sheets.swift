import AppKit
import ObjectiveC

final class SheetPresenter {
    private weak var host: NSViewController?
    private var current: NSWindow?

    init(host: NSViewController) {
        self.host = host
    }

    func present(_ kind: SheetKind, reason: String? = nil) {
        guard let host, let window = host.view.window else { return }
        if let current {
            window.endSheet(current)
            self.current = nil
        }
        let content: NSViewController
        switch kind {
        case .onboarding: content = OnboardingController()
        case .upgrade: content = UpgradeController(reason: reason)
        case .signIn: content = SignInController()
        case .account:
            content = SettingsController(initialTab: .account)
        case .settings:
            content = SettingsController(initialTab: SettingsTab.pending)
        case .about: content = SimpleSheetController(
            title: "iClearer",
            body: "Version 1.0\nClear space. Keep control.",
            button: "OK"
        )
        case .help: content = SimpleSheetController(
            title: "iClearer Help",
            body: "Scan. iClearer looks for caches, logs, leftovers, big files and apps. Nothing moves yet.\n\nReview. Every item says what it is and whether it comes back.\n\nClean up. Items go to the Trash. Undo works right away.\n\nStay safe. Keychain, accounts, editor data and developer credentials are never touched.",
            button: "Close"
        )
        case .rules: content = RulesController()
        case .keys: content = SimpleSheetController(
            title: "Keyboard shortcuts",
            body: "Overview to History   ⌘1 – ⌘9\nRescan   ⌘R\nUndo last cleanup   ⌘Z\nSelect Safe only   ⇧⌘S\nClear picks   ⇧⌘D\nSettings   ⌘,\nExport report   ⇧⌘E\nShow or hide sidebar   ⌥⌘S\nShow or hide inspector   ⌥⌘I",
            button: "Close"
        )
        }
        let height: CGFloat
        let width: CGFloat
        switch kind {
        case .settings, .account: height = 600; width = 860
        case .rules: height = 540; width = 560
        case .upgrade: height = 560; width = 560
        default: height = 440; width = 460
        }
        _ = content.view // force load
        content.view.frame = NSRect(x: 0, y: 0, width: width, height: height)
        let sheet: NSWindow
        if kind == .settings || kind == .account {
            // Modal only — no extra title bar / no background blur chrome.
            sheet = makePlainSheet(size: NSSize(width: width, height: height), content: content)
        } else {
            sheet = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                styleMask: [.titled],
                backing: .buffered,
                defer: false
            )
            sheet.contentViewController = content
            sheet.setContentSize(NSSize(width: width, height: height))
        }
        current = sheet
        window.beginSheet(sheet) { [weak self] _ in
            self?.current = nil
        }
    }

    /// Custom Ask-first confirm (not NSAlert) — matches Clean Up confirm mock.
    func presentAskFirstConfirm(count: Int, onTrash: @escaping () -> Void) {
        guard let host, let window = host.view.window else { return }
        dismissCurrent()
        let content = AskFirstConfirmController(count: count)
        _ = content.view
        let size = NSSize(width: 420, height: 220)
        content.view.frame = NSRect(origin: .zero, size: size)
        let sheet = makePlainSheet(size: size, content: content)
        current = sheet
        window.beginSheet(sheet) { [weak self] response in
            self?.current = nil
            if response == .OK {
                // Next runloop so this sheet fully ends before Moving sheet begins.
                DispatchQueue.main.async { onTrash() }
            }
        }
    }

    /// Progress sheet while items move to Trash.
    func presentMovingToTrash(bytes: Int64) {
        guard let host, let window = host.view.window else { return }
        dismissCurrent()
        let content = MovingToTrashController(bytes: bytes)
        _ = content.view
        let size = NSSize(width: 400, height: 240)
        content.view.frame = NSRect(origin: .zero, size: size)
        let sheet = makePlainSheet(size: size, content: content)
        current = sheet
        window.beginSheet(sheet) { [weak self] _ in
            self?.current = nil
        }
    }

    /// Large & Old Files Quick Look preview sheet.
    func presentQuickLook(file: LargeFileItem) {
        guard let host, let window = host.view.window else { return }
        dismissCurrent()
        let content = QuickLookController(file: file)
        _ = content.view
        let size = NSSize(width: 440, height: 420)
        content.view.frame = NSRect(origin: .zero, size: size)
        let sheet = makePlainSheet(size: size, content: content)
        current = sheet
        window.beginSheet(sheet) { [weak self] _ in
            self?.current = nil
        }
    }

    func dismissCurrent() {
        guard let current else { return }
        if let parent = current.sheetParent {
            parent.endSheet(current)
        } else {
            current.close()
        }
        self.current = nil
    }

    private func makePlainSheet(size: NSSize, content: NSViewController) -> NSWindow {
        let sheet = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        sheet.titleVisibility = .hidden
        sheet.titlebarAppearsTransparent = true
        sheet.contentViewController = content
        sheet.setContentSize(size)
        return sheet
    }
}

private func sheetRoot() -> NSView {
    let view = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 420))
    view.wantsLayer = true
    view.layer?.backgroundColor = Theme.Colors.content.cgColor
    view.layer?.cornerRadius = 26
    return view
}

func dismissSheet(from view: NSView) {
    guard let window = view.window, let parent = window.sheetParent else {
        view.window?.close()
        return
    }
    parent.endSheet(window)
}

// MARK: Onboarding

final class OnboardingController: NSViewController {
    private var step = 0
    private let emailField = NSTextField()
    private let errorLabel = makeLabel("", size: 12, weight: .medium, color: NSColor.systemRed)
    private var marketing = false
    private var fdaAllowed = false

    override func loadView() {
        view = sheetRoot()
        render()
    }

    private func render() {
        view.subviews.forEach { $0.removeFromSuperview() }
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        switch step {
        case 0:
            let title = makeLabel("Welcome to iClearer", size: 22, weight: .bold, color: Theme.ink, align: .center)
            let tag = makeLabel("Clear space. Keep control.", size: 14, weight: .medium, color: Theme.muted, align: .center)
            let bullets = makeMultilineLabel("• See everything before anything moves\n• Everything goes to the Trash, with Undo\n• Keychain and accounts can never be touched", size: 13, weight: .regular, color: Theme.ink)
            let next = makeAccentButton("Continue")
            next.target = self
            next.action = #selector(goEmail)
            [title, tag, bullets, next].forEach { stack.addArrangedSubview($0) }
        case 1:
            let title = makeLabel("What’s your email?", size: 22, weight: .bold, color: Theme.ink, align: .center)
            let body = makeMultilineLabel("We use it for your license, receipts and security notices, and to restore your plan on a new Mac.", size: 13, weight: .regular, color: Theme.muted)
            body.alignment = .center
            emailField.placeholderString = "you@example.com"
            // Prefill test account so QA can pass the email step quickly.
            let existing = LicenseStore.current.email
            emailField.stringValue = existing.isEmpty ? LicenseState.testEmail : existing
            emailField.font = .systemFont(ofSize: 14)
            emailField.translatesAutoresizingMaskIntoConstraints = false
            emailField.widthAnchor.constraint(equalToConstant: 300).isActive = true
            let market = NSButton(checkboxWithTitle: "Email me about updates and new products", target: self, action: #selector(toggleMarket))
            market.state = marketing ? .on : .off
            market.translatesAutoresizingMaskIntoConstraints = false
            let next = makeAccentButton("Continue")
            next.target = self
            next.action = #selector(goFDA)
            let signIn = NSButton(title: "Already have a license? Sign in or activate", target: self, action: #selector(openSignIn))
            signIn.isBordered = false
            signIn.font = .systemFont(ofSize: 12.5)
            signIn.contentTintColor = Theme.accent
            [title, body, emailField, errorLabel, market, next, signIn].forEach { stack.addArrangedSubview($0) }
        default:
            let title = makeLabel("Allow Full Disk Access", size: 22, weight: .bold, color: Theme.ink, align: .center)
            let body = makeMultilineLabel("To find hidden files, iClearer needs Full Disk Access. It only reads names and sizes, and moves things to the Trash when you say so.", size: 13, weight: .regular, color: Theme.muted)
            body.alignment = .center
            let toggle = NSButton(checkboxWithTitle: "I opened System Settings / will grant access", target: self, action: #selector(toggleFDA))
            toggle.state = fdaAllowed ? .on : .off
            let open = makeGhostButton("Open Full Disk Access")
            open.target = self
            open.action = #selector(openFDA)
            let startBtn = makeAccentButton("Start scan")
            startBtn.target = self
            startBtn.action = #selector(start)
            startBtn.isEnabled = true
            let skip = NSButton(title: "Skip for now", target: self, action: #selector(start))
            skip.isBordered = false
            skip.contentTintColor = Theme.muted
            [title, body, open, toggle, startBtn, skip].forEach { stack.addArrangedSubview($0) }
        }

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -28),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 360)
        ])
    }

    @objc private func goEmail() { step = 1; render() }
    @objc private func toggleMarket(_ sender: NSButton) { marketing = sender.state == .on }
    @objc private func toggleFDA(_ sender: NSButton) { fdaAllowed = sender.state == .on }
    @objc private func openFDA() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
        fdaAllowed = true
    }
    @objc private func openSignIn() {
        dismissSheet(from: view)
        AppState.shared.showSheet(.signIn)
    }
    @objc private func goFDA() {
        let email = emailField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard email.contains("@"), email.contains(".") else {
            errorLabel.stringValue = "Enter a valid email to continue."
            return
        }
        // Stay on Free plan so Overview / Clean match the free prototype; activate via Sign In + key for Pro.
        LicenseStore.setEmail(email, marketing: marketing)
        step = 2
        render()
    }
    @objc private func start() {
        if LicenseStore.current.email.isEmpty {
            errorLabel.stringValue = "Email is required."
            step = 1
            render()
            return
        }
        LicenseStore.completeOnboarding()
        dismissSheet(from: view)
        AppState.shared.startScan()
    }
}

// MARK: Upgrade / Sign in / Account

final class UpgradeController: NSViewController {
    private let reason: String?
    private var selectedPlan = 0 // 0 yearly, 1 monthly, 2 once
    private var planCards: [PlanCardView] = []

    init(reason: String?) {
        self.reason = reason
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let root = sheetRoot()
        root.frame = NSRect(x: 0, y: 0, width: 560, height: 560)
        view = root

        let icon = NSImageView()
        icon.image = Self.brandIcon()
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.wantsLayer = true
        icon.layer?.cornerRadius = 24
        icon.layer?.masksToBounds = true
        icon.translatesAutoresizingMaskIntoConstraints = false

        let title = makeLabel("Unlock iClearer", size: 24, weight: .bold, color: Theme.Colors.text, align: .center)
        let body = makeMultilineLabel(
            reason ?? "Everything your free plan hides, in one place.",
            size: 14, weight: .regular, color: Theme.Colors.muted
        )
        body.alignment = .center

        let features = [
            "Unlimited cleanup",
            "Exact locations and Reveal in Finder",
            "Full Storage Map, large files and app uninstaller",
            "History with restore and a never-touch list"
        ]
        let bullets = NSStackView()
        bullets.orientation = .vertical
        bullets.alignment = .leading
        bullets.spacing = 12
        bullets.translatesAutoresizingMaskIntoConstraints = false
        for line in features {
            bullets.addArrangedSubview(makeBulletRow(line))
        }

        let yearly = PlanCardView(price: "$29.99", term: "Yearly", selected: true)
        let monthly = PlanCardView(price: "$4.99", term: "Monthly", selected: false)
        let once = PlanCardView(price: "$79.99", term: "One-time", selected: false)
        planCards = [yearly, monthly, once]
        for (i, card) in planCards.enumerated() {
            card.planIndex = i
            let click = NSClickGestureRecognizer(target: self, action: #selector(pickPlan(_:)))
            card.addGestureRecognizer(click)
        }
        let plans = NSStackView(views: planCards)
        plans.orientation = .horizontal
        plans.spacing = 14
        plans.distribution = .fillEqually
        plans.translatesAutoresizingMaskIntoConstraints = false

        let later = PillButton(title: "Maybe later", style: .ghost)
        later.target = self
        later.action = #selector(close)

        let stack = NSStackView(views: [icon, title, body, bullets, plans, later])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 14
        stack.setCustomSpacing(8, after: title)
        stack.setCustomSpacing(18, after: body)
        stack.setCustomSpacing(22, after: bullets)
        stack.setCustomSpacing(22, after: plans)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 88),
            icon.heightAnchor.constraint(equalToConstant: 88),
            bullets.widthAnchor.constraint(equalToConstant: 440),
            plans.widthAnchor.constraint(equalToConstant: 480),
            plans.heightAnchor.constraint(equalToConstant: 92),
            later.widthAnchor.constraint(equalToConstant: 180),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32)
        ])
    }

    /// Glass-light brand mark for the Unlock sheet.
    private static func brandIcon() -> NSImage {
        let candidates: [URL?] = [
            Bundle.main.url(forResource: "iclearer-icon-glass-light", withExtension: "png"),
            Bundle.main.url(forResource: "iclearer-icon-glass-light", withExtension: "svg"),
            URL(fileURLWithPath: "/Users/daniel/PycharmProjects/iclearer/mac/Resources/iclearer-icon-glass-light.png"),
            URL(fileURLWithPath: "/Users/daniel/PycharmProjects/iclearer/website/public/assets/png/icon-glass-light-1024.png"),
            URL(fileURLWithPath: "/Users/daniel/PycharmProjects/iclearer/mac/Resources/iclearer-icon-glass-light.svg"),
            URL(fileURLWithPath: "/Users/daniel/PycharmProjects/iclearer/iclearer-icon-glass-light.svg")
        ]
        for url in candidates.compactMap({ $0 }) {
            if let img = NSImage(contentsOf: url) {
                img.size = NSSize(width: 88, height: 88)
                return img
            }
        }
        return NSApp.applicationIconImage ?? NSImage(size: NSSize(width: 88, height: 88))
    }

    private func makeBulletRow(_ text: String) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        let bead = NSView()
        bead.wantsLayer = true
        bead.layer?.backgroundColor = Theme.sky.cgColor
        bead.layer?.cornerRadius = 5
        bead.translatesAutoresizingMaskIntoConstraints = false
        let label = makeLabel(text, size: 13.5, weight: .regular, color: Theme.Colors.text)
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 2
        row.addArrangedSubview(bead)
        row.addArrangedSubview(label)
        NSLayoutConstraint.activate([
            bead.widthAnchor.constraint(equalToConstant: 10),
            bead.heightAnchor.constraint(equalToConstant: 10)
        ])
        return row
    }

    @objc private func pickPlan(_ sender: NSClickGestureRecognizer) {
        guard let card = sender.view as? PlanCardView else { return }
        selectedPlan = card.planIndex
        for c in planCards { c.setSelected(c.planIndex == selectedPlan) }
        // Prototype: tapping a plan card buys that plan.
        if selectedPlan == 2 { buyOnce() } else { buyYearly() }
    }

    @objc private func buyYearly() {
        let email = LicenseStore.current.email.isEmpty ? LicenseState.testEmail : LicenseStore.current.email
        _ = LicenseStore.activate(email: email, key: LicenseState.testKey)
        AppState.shared.showToast("iClearer unlocked (test activation).")
        dismissSheet(from: view)
    }

    @objc private func buyOnce() {
        let email = LicenseStore.current.email.isEmpty ? LicenseState.testEmail : LicenseStore.current.email
        _ = LicenseStore.activate(email: email, key: "ICLR-ONCE-TEST")
        AppState.shared.showToast("One-time plan unlocked (test).")
        dismissSheet(from: view)
    }

    @objc private func close() { dismissSheet(from: view) }
}

/// Pricing tile for the Unlock sheet — price + term, blue border when selected.
private final class PlanCardView: NSView {
    var planIndex = 0
    private let priceLabel: NSTextField
    private let termLabel: NSTextField
    private(set) var isPlanSelected: Bool

    init(price: String, term: String, selected: Bool) {
        self.isPlanSelected = selected
        self.priceLabel = makeLabel(price, size: 20, weight: .bold, color: Theme.Colors.text, align: .center)
        self.termLabel = makeLabel(term, size: 12.5, weight: .regular, color: Theme.Colors.muted, align: .center)
        super.init(frame: .zero)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        layer?.cornerRadius = 16
        layer?.backgroundColor = Theme.Colors.contentAlt.cgColor
        addSubview(priceLabel)
        addSubview(termLabel)
        NSLayoutConstraint.activate([
            priceLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            priceLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            termLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            termLabel.topAnchor.constraint(equalTo: priceLabel.bottomAnchor, constant: 4)
        ])
        setSelected(selected)
    }

    required init?(coder: NSCoder) { nil }

    func setSelected(_ on: Bool) {
        isPlanSelected = on
        layer?.borderWidth = on ? 1.5 : 1
        layer?.borderColor = on
            ? Theme.sky.cgColor
            : Theme.Colors.separator.cgColor
    }
}

final class SignInController: NSViewController {
    private let emailField = NSTextField()
    private let keyField = NSTextField()
    private let errorLabel = makeLabel("", size: 12, weight: .medium, color: .systemRed)

    override func loadView() {
        view = sheetRoot()
        let title = makeLabel("Sign in or activate", size: 22, weight: .bold, color: Theme.ink, align: .center)
        let body = makeMultilineLabel("Enter the email you bought with and your license key.\nTest: test@iclearer.com + ICLR-TEST-0001-FREE", size: 13, weight: .regular, color: Theme.muted)
        body.alignment = .center
        emailField.placeholderString = "Email"
        emailField.stringValue = LicenseStore.current.email
        emailField.translatesAutoresizingMaskIntoConstraints = false
        keyField.placeholderString = "License key, for example ICLR-TEST-0001-FREE"
        keyField.translatesAutoresizingMaskIntoConstraints = false
        emailField.widthAnchor.constraint(equalToConstant: 320).isActive = true
        keyField.widthAnchor.constraint(equalToConstant: 320).isActive = true
        let activateBtn = makeAccentButton("Activate")
        activateBtn.target = self
        activateBtn.action = #selector(activate)
        let cancel = makeGhostButton("Cancel")
        cancel.target = self
        cancel.action = #selector(close)
        let stack = NSStackView(views: [title, body, emailField, keyField, errorLabel, activateBtn, cancel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @objc private func activate() {
        let result = LicenseStore.activate(email: emailField.stringValue, key: keyField.stringValue)
        if result.ok {
            AppState.shared.showToast(result.message)
            dismissSheet(from: view)
        } else {
            errorLabel.stringValue = result.message
        }
    }
    @objc private func close() { dismissSheet(from: view) }
}

// Account lives inside Settings → Account tab (SettingsSheet.swift).

final class SimpleSheetController: NSViewController {
    private let sheetTitle: String
    private let body: String
    private let buttonTitle: String

    init(title: String, body: String, button: String) {
        self.sheetTitle = title
        self.body = body
        self.buttonTitle = button
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { nil }

    override func loadView() {
        view = sheetRoot()
        let title = makeLabel(sheetTitle, size: 22, weight: .bold, color: Theme.ink, align: .center)
        let body = makeMultilineLabel(self.body, size: 13, weight: .regular, color: Theme.ink)
        body.alignment = .left
        let button = makeAccentButton(buttonTitle)
        button.target = self
        button.action = #selector(close)
        let stack = NSStackView(views: [title, body, button])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.widthAnchor.constraint(equalToConstant: 360)
        ])
    }

    @objc private func close() { dismissSheet(from: view) }
}

final class RulesController: NSViewController {
    override func loadView() {
        view = sheetRoot()
        view.frame.size = NSSize(width: 560, height: 520)
        let title = makeLabel("Cleanup rules", size: 20, weight: .bold, color: Theme.ink)
        let body = makeMultilineLabel("The kinds of things iClearer can clean. Nothing else is ever touched.", size: 12.5, weight: .regular, color: Theme.muted)
        let rules: [(String, String, String)] = [
            ("App log files", "Safe", "Diagnostic logs apps write."),
            ("Browser cache", "Safe", "Saved pages and images."),
            ("System cache", "Safe", "Temporary files kept for speed."),
            ("Developer build files", "Safe", "Files tools rebuild from your projects."),
            ("Package manager cache", "Safe", "Downloads tools keep for reinstalls."),
            ("Old installer files", "Ask first", "Installers you already used."),
            ("Old device backups", "Ask first", "Device backups made in Finder."),
            ("System temporary files", "Ask first", "Temporary files from system updates."),
            ("Container cache", "Ask first", "Saved build layers."),
            ("AI model files", "Ask first", "Downloaded model files.")
        ]
        let list = NSStackView()
        list.orientation = .vertical
        list.alignment = .leading
        list.spacing = 6
        list.translatesAutoresizingMaskIntoConstraints = false
        for r in rules {
            list.addArrangedSubview(makeLabel("\(r.0)  ·  \(r.1)  —  \(r.2)", size: 12, weight: .regular, color: Theme.ink))
        }
        let closeBtn = makeAccentButton("Close")
        closeBtn.target = self
        closeBtn.action = #selector(close)
        let stack = NSStackView(views: [title, body, list, closeBtn])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 24)
        ])
    }

    @objc private func close() { dismissSheet(from: view) }
}

/// Clean Up confirm when Ask-first items are selected.
final class AskFirstConfirmController: NSViewController {
    private let count: Int

    init(count: Int) {
        self.count = count
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let root = sheetRoot()
        root.frame = NSRect(x: 0, y: 0, width: 420, height: 220)
        view = root

        let noun = count == 1 ? "item" : "items"
        let title = makeLabel(
            "\(count) \(noun) can’t always be rebuilt",
            size: 18, weight: .bold, color: Theme.Colors.text, align: .center
        )
        title.maximumNumberOfLines = 2
        title.lineBreakMode = .byWordWrapping

        let body = makeMultilineLabel(
            TimeMachineProbe.askConfirmSheetBody(),
            size: 13.5, weight: .regular, color: Theme.Colors.muted
        )
        body.alignment = .center

        let back = PillButton(title: "Go back", style: .ghost)
        back.target = self
        back.action = #selector(goBack)

        let trash = PillButton(title: "Move to Trash", style: .primary)
        trash.target = self
        trash.action = #selector(moveToTrash)

        let buttons = NSStackView(views: [back, trash])
        buttons.orientation = .horizontal
        buttons.spacing = 12
        buttons.distribution = .fillEqually
        buttons.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [title, body, buttons])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 14
        stack.setCustomSpacing(22, after: body)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            title.widthAnchor.constraint(equalToConstant: 340),
            body.widthAnchor.constraint(equalToConstant: 340),
            buttons.widthAnchor.constraint(equalToConstant: 300),
            buttons.heightAnchor.constraint(equalToConstant: 40),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -28)
        ])
    }

    @objc private func goBack() {
        guard let window = view.window, let parent = window.sheetParent else {
            view.window?.close()
            return
        }
        parent.endSheet(window, returnCode: .cancel)
    }

    @objc private func moveToTrash() {
        guard let window = view.window, let parent = window.sheetParent else {
            view.window?.close()
            return
        }
        parent.endSheet(window, returnCode: .OK)
    }
}

/// Shown while cleanup runs — glass check + “Moving to the Trash…”.
final class MovingToTrashController: NSViewController {
    private let bytes: Int64

    init(bytes: Int64) {
        self.bytes = bytes
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let root = sheetRoot()
        root.frame = NSRect(x: 0, y: 0, width: 400, height: 240)
        view = root

        let bead = LiquidGlassBeadView()
        bead.diameter = 72

        let title = makeLabel(
            "Moving to the Trash…",
            size: 20, weight: .bold, color: Theme.Colors.text, align: .center
        )
        let body = makeMultilineLabel(
            "\(AppFormat.bytes(bytes)) is being moved. You can undo it right after.",
            size: 13.5, weight: .regular, color: Theme.Colors.muted
        )
        body.alignment = .center

        let stack = NSStackView(views: [bead, title, body])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.setCustomSpacing(16, after: bead)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            bead.widthAnchor.constraint(equalToConstant: 72),
            bead.heightAnchor.constraint(equalToConstant: 72),
            body.widthAnchor.constraint(equalToConstant: 300),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -28)
        ])
    }
}

/// Large & Old Files Quick Look — preview + name + meta + Close.
final class QuickLookController: NSViewController {
    private let file: LargeFileItem

    init(file: LargeFileItem) {
        self.file = file
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let root = sheetRoot()
        root.frame = NSRect(x: 0, y: 0, width: 440, height: 420)
        view = root

        let preview = NSView()
        preview.wantsLayer = true
        preview.layer?.cornerRadius = 14
        preview.layer?.backgroundColor = Theme.Colors.contentAlt.cgColor
        preview.translatesAutoresizingMaskIntoConstraints = false

        let icon = NSImageView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.imageScaling = .scaleProportionallyUpOrDown
        if let symbol = NSImage(systemSymbolName: "doc", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 64, weight: .ultraLight)
            icon.image = symbol.withSymbolConfiguration(config)
            icon.contentTintColor = Theme.Colors.muted
        }
        preview.addSubview(icon)

        let title = makeLabel(file.name, size: 22, weight: .bold, color: Theme.Colors.text)
        title.maximumNumberOfLines = 2
        title.lineBreakMode = .byTruncatingMiddle

        let meta = makeLabel(
            "\(AppFormat.bytes(file.bytes)) · last opened \(file.ageLabel) ago · \(file.path)",
            size: 13.5, weight: .regular, color: Theme.Colors.muted
        )
        meta.maximumNumberOfLines = 2
        meta.lineBreakMode = .byWordWrapping

        let close = PillButton(title: "Close", style: .ghost)
        close.compact = true
        close.target = self
        close.action = #selector(closeSheet)

        let textStack = NSStackView(views: [title, meta])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 6
        textStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(preview)
        view.addSubview(textStack)
        view.addSubview(close)

        NSLayoutConstraint.activate([
            preview.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            preview.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            preview.topAnchor.constraint(equalTo: view.topAnchor, constant: 28),
            preview.heightAnchor.constraint(equalToConstant: 230),

            icon.centerXAnchor.constraint(equalTo: preview.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: preview.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 80),
            icon.heightAnchor.constraint(equalToConstant: 80),

            textStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            textStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            textStack.topAnchor.constraint(equalTo: preview.bottomAnchor, constant: 16),

            close.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            close.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -24),
            close.widthAnchor.constraint(greaterThanOrEqualToConstant: 88)
        ])
    }

    @objc private func closeSheet() {
        dismissSheet(from: view)
    }
}

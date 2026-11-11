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
        case .onboarding: height = 340; width = 440
        case .signIn: height = 360; width = 440
        default: height = 440; width = 460
        }
        _ = content.view // force load (onboarding/sign-in hug their content)
        let size: NSSize = {
            if kind == .onboarding || kind == .signIn {
                let fitted = content.view.frame.size
                if fitted.width >= 1, fitted.height >= 1 { return fitted }
            }
            let fallback = NSSize(width: width, height: height)
            if kind != .onboarding && kind != .signIn {
                content.view.frame = NSRect(origin: .zero, size: fallback)
            }
            return fallback
        }()
        let sheet: NSWindow
        if kind == .settings || kind == .account || kind == .onboarding || kind == .signIn {
            // Modal only — no extra title bar / no background blur chrome.
            sheet = makePlainSheet(size: size, content: content)
        } else {
            sheet = NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.titled],
                backing: .buffered,
                defer: false
            )
            sheet.contentViewController = content
            sheet.setContentSize(size)
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

private func sheetRoot(width: CGFloat = 520, height: CGFloat = 520) -> NSView {
    // Prototype `.sh` card: --cd dark #1A2027, radius 26.
    let view = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
    view.wantsLayer = true
    view.layer?.backgroundColor = NSColor(srgbRed: 0x1A / 255, green: 0x20 / 255, blue: 0x27 / 255, alpha: 1).cgColor
    view.layer?.cornerRadius = 26
    view.layer?.masksToBounds = true
    return view
}

private func brandSheetIcon(size: CGFloat = 88) -> NSImageView {
    let icon = NSImageView()
    icon.image = sheetBrandImage(size: size)
    icon.imageScaling = .scaleProportionallyUpOrDown
    icon.wantsLayer = true
    icon.layer?.cornerRadius = size * 0.22
    icon.layer?.masksToBounds = true
    icon.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        icon.widthAnchor.constraint(equalToConstant: size),
        icon.heightAnchor.constraint(equalToConstant: size)
    ])
    return icon
}

private func sheetBrandImage(size: CGFloat) -> NSImage {
    let candidates: [URL?] = [
        Bundle.main.url(forResource: "iclearer-icon-glass-light", withExtension: "png"),
        Bundle.main.url(forResource: "iclearer-icon-glass-light", withExtension: "svg"),
        URL(fileURLWithPath: "/Users/daniel/PycharmProjects/iclearer/mac/Resources/iclearer-icon-glass-light.png"),
        URL(fileURLWithPath: "/Users/daniel/PycharmProjects/iclearer/website/public/assets/png/icon-glass-light-1024.png")
    ]
    for url in candidates.compactMap({ $0 }) {
        if let img = NSImage(contentsOf: url) {
            img.size = NSSize(width: size, height: size)
            return img
        }
    }
    return NSApp.applicationIconImage ?? NSImage(size: NSSize(width: size, height: size))
}

/// Prototype `.in` field — rounded dark chrome with inset text.
private func makeSheetInput(placeholder: String, value: String = "") -> (wrap: NSView, field: NSTextField) {
    let field = NSTextField()
    field.placeholderString = placeholder
    field.stringValue = value
    field.font = .systemFont(ofSize: 14)
    field.isBordered = false
    field.isBezeled = false
    field.drawsBackground = false
    field.focusRingType = .none
    field.textColor = NSColor(srgbRed: 0xF2 / 255, green: 0xF5 / 255, blue: 0xF8 / 255, alpha: 1)
    field.translatesAutoresizingMaskIntoConstraints = false

    let wrap = NSView()
    wrap.wantsLayer = true
    wrap.layer?.cornerRadius = 12
    wrap.layer?.backgroundColor = NSColor(srgbRed: 0x23 / 255, green: 0x2B / 255, blue: 0x34 / 255, alpha: 1).cgColor
    wrap.layer?.borderWidth = 1.5
    wrap.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
    wrap.translatesAutoresizingMaskIntoConstraints = false
    wrap.addSubview(field)
    NSLayoutConstraint.activate([
        wrap.heightAnchor.constraint(equalToConstant: 44),
        field.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 14),
        field.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -14),
        field.centerYAnchor.constraint(equalTo: wrap.centerYAnchor)
    ])
    return (wrap, field)
}

private func makeGlossBead(size: CGFloat = 14) -> NSView {
    let bead = NSView()
    bead.wantsLayer = true
    bead.layer?.cornerRadius = size / 2
    // Prototype lock / bullet radial: #E3F2FC → #82BCE7 → #3B7CB0
    bead.layer?.backgroundColor = NSColor(srgbRed: 0x82 / 255, green: 0xBC / 255, blue: 0xE7 / 255, alpha: 1).cgColor
    bead.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        bead.widthAnchor.constraint(equalToConstant: size),
        bead.heightAnchor.constraint(equalToConstant: size)
    ])
    return bead
}

func dismissSheet(from view: NSView) {
    guard let window = view.window, let parent = window.sheetParent else {
        view.window?.close()
        return
    }
    parent.endSheet(window)
}

// MARK: Onboarding — Welcome → Email → Full Disk Access

final class OnboardingController: NSViewController {
    private var step = 0
    private var emailField: NSTextField!
    private let errorLabel = makeLabel("", size: 12.5, weight: .medium, color: NSColor(srgbRed: 0xD0 / 255, green: 0x45 / 255, blue: 0x3F / 255, alpha: 1))
    private var marketing = false
    private var fdaAllowed = false
    private var startButton: PillButton?
    private let tx = NSColor(srgbRed: 0xF2 / 255, green: 0xF5 / 255, blue: 0xF8 / 255, alpha: 1)
    private let mu = NSColor(srgbRed: 0x9A / 255, green: 0xA8 / 255, blue: 0xB6 / 255, alpha: 1)

    /// Compact card — content edge-to-edge with prototype `.sh` padding 28.
    private let cardW: CGFloat = 440
    private let edgePad: CGFloat = 28
    private var contentW: CGFloat { cardW - edgePad * 2 }

    override func loadView() {
        view = sheetRoot(width: cardW, height: 320)
        render()
    }

    private func render() {
        view.subviews.forEach { $0.removeFromSuperview() }

        // Full-width content column; sheet height hugs stack (equal pad top/bottom).
        let column = NSView()
        column.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(column)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        column.addSubview(stack)

        switch step {
        case 0: renderWelcome(into: stack)
        case 1: renderEmail(into: stack)
        default: renderFDA(into: stack)
        }

        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: edgePad),
            column.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -edgePad),
            column.topAnchor.constraint(equalTo: view.topAnchor, constant: edgePad),
            column.widthAnchor.constraint(equalToConstant: contentW),

            stack.leadingAnchor.constraint(equalTo: column.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: column.trailingAnchor),
            stack.topAnchor.constraint(equalTo: column.topAnchor),
            stack.bottomAnchor.constraint(equalTo: column.bottomAnchor)
        ])

        // Measure content, then shrink the sheet so bottom pad matches top.
        view.setFrameSize(NSSize(width: cardW, height: 900))
        view.layoutSubtreeIfNeeded()
        let fitted = ceil(stack.fittingSize.height) + edgePad * 2
        let size = NSSize(width: cardW, height: max(240, fitted))
        view.setFrameSize(size)
        view.window?.setContentSize(size)
    }

    private func fullWidth(_ view: NSView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: contentW).isActive = true
    }

    private func centeredBody(_ text: String) -> NSTextField {
        let body = makeMultilineLabel(text, size: 13.5, weight: .regular, color: mu)
        body.alignment = .center
        body.preferredMaxLayoutWidth = contentW
        fullWidth(body)
        return body
    }

    private func renderWelcome(into stack: NSStackView) {
        let icon = brandSheetIcon(size: 72)
        let title = makeLabel("Welcome to iClearer", size: 21, weight: .bold, color: tx, align: .center)
        let tag = makeLabel("Clear space. Keep control.", size: 13.5, weight: .regular, color: mu, align: .center)

        let bullets = NSStackView()
        bullets.orientation = .vertical
        bullets.alignment = .leading
        bullets.spacing = 6
        bullets.translatesAutoresizingMaskIntoConstraints = false
        fullWidth(bullets)
        for line in [
            "See everything before anything moves",
            "Everything goes to the Trash, with Undo",
            "Keychain and accounts can never be touched"
        ] {
            let label = makeLabel(line, size: 13.5, weight: .regular, color: tx)
            label.setContentHuggingPriority(.defaultLow, for: .horizontal)
            let row = NSStackView(views: [makeGlossBead(size: 12), label])
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 10
            bullets.addArrangedSubview(row)
        }

        let next = makeAccentButton("Continue")
        next.target = self
        next.action = #selector(goEmail)

        [icon, title, tag, bullets, next].forEach { stack.addArrangedSubview($0) }
        stack.setCustomSpacing(10, after: icon)
        stack.setCustomSpacing(4, after: title)
        stack.setCustomSpacing(12, after: tag)
        stack.setCustomSpacing(14, after: bullets)
    }

    private func renderEmail(into stack: NSStackView) {
        let title = makeLabel("What’s your email?", size: 21, weight: .bold, color: tx, align: .center)
        let body = centeredBody(
            "We use it for your license, receipts and security notices, and to restore your plan on a new Mac."
        )

        let existing = LicenseStore.current.email.isEmpty
            ? LicenseStore.pendingEmail
            : LicenseStore.current.email
        let input = makeSheetInput(
            placeholder: "you@example.com",
            value: existing.isEmpty ? "" : existing
        )
        emailField = input.field
        fullWidth(input.wrap)

        errorLabel.alignment = .center
        errorLabel.isHidden = errorLabel.stringValue.isEmpty
        fullWidth(errorLabel)

        let market = makeMarketingRow()
        fullWidth(market)

        let next = makeAccentButton("Continue")
        next.target = self
        next.action = #selector(goFDA)

        let footer = makeSignInFooter()

        [title, body, input.wrap, errorLabel, market, next, footer].forEach { stack.addArrangedSubview($0) }
        stack.setCustomSpacing(4, after: title)
        stack.setCustomSpacing(12, after: body)
        // Gap between email field and marketing checkbox (keep a little room for error text).
        stack.setCustomSpacing(errorLabel.isHidden ? 16 : 6, after: input.wrap)
        stack.setCustomSpacing(errorLabel.isHidden ? 0 : 10, after: errorLabel)
        stack.setCustomSpacing(12, after: market)
        stack.setCustomSpacing(10, after: next)
    }

    private func renderFDA(into stack: NSStackView) {
        let icon = brandSheetIcon(size: 72)
        let title = makeLabel("Allow Full Disk Access", size: 21, weight: .bold, color: tx, align: .center)
        let body = centeredBody(
            "To find hidden files, iClearer needs Full Disk Access. It only reads names and sizes, and moves things to the Trash when you say so."
        )

        let row = makeFDARow()
        fullWidth(row)

        let startBtn = makeAccentButton("Start scan")
        startBtn.target = self
        startBtn.action = #selector(start)
        startBtn.isEnabled = fdaAllowed
        startBtn.alphaValue = fdaAllowed ? 1 : 0.4
        startButton = startBtn

        [icon, title, body, row, startBtn].forEach { stack.addArrangedSubview($0) }
        stack.setCustomSpacing(10, after: icon)
        stack.setCustomSpacing(4, after: title)
        stack.setCustomSpacing(12, after: body)
        stack.setCustomSpacing(14, after: row)
    }

    private func makeMarketingRow() -> NSView {
        let box = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleMarket))
        box.state = marketing ? .on : .off
        box.translatesAutoresizingMaskIntoConstraints = false
        box.widthAnchor.constraint(equalToConstant: 18).isActive = true

        let title = makeLabel("Email me about updates and new products", size: 13, weight: .regular, color: tx)
        let note = makeLabel("Optional. You can unsubscribe anytime. We never share your email.", size: 12, weight: .regular, color: mu)
        let text = NSStackView(views: [title, note])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 2

        let row = NSStackView(views: [box, text])
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    private func makeSignInFooter() -> NSView {
        let prefix = makeLabel("Already have a license? ", size: 12.5, weight: .regular, color: mu)
        let link = NSButton(title: "Sign in or activate", target: self, action: #selector(openSignIn))
        link.isBordered = false
        link.font = .systemFont(ofSize: 12.5, weight: .semibold)
        link.contentTintColor = Theme.sky
        link.translatesAutoresizingMaskIntoConstraints = false
        let row = NSStackView(views: [prefix, link])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 0
        return row
    }

    private func makeFDARow() -> NSView {
        let wrap = NSView()
        wrap.wantsLayer = true
        wrap.layer?.cornerRadius = 14
        wrap.layer?.backgroundColor = NSColor(srgbRed: 0x23 / 255, green: 0x2B / 255, blue: 0x34 / 255, alpha: 1).cgColor
        wrap.layer?.borderWidth = 1
        wrap.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
        wrap.translatesAutoresizingMaskIntoConstraints = false

        let appIcon = NSView()
        appIcon.wantsLayer = true
        appIcon.layer?.cornerRadius = 8
        appIcon.layer?.backgroundColor = NSColor(srgbRed: 0x55 / 255, green: 0x6E / 255, blue: 0x99 / 255, alpha: 1).cgColor
        appIcon.translatesAutoresizingMaskIntoConstraints = false
        let grid = NSImageView(image: NSImage(systemSymbolName: "square.grid.2x2.fill", accessibilityDescription: nil)!)
        grid.contentTintColor = .white
        grid.translatesAutoresizingMaskIntoConstraints = false
        appIcon.addSubview(grid)

        let name = makeLabel("iClearer", size: 14, weight: .semibold, color: tx)
        let toggle = SettingsToggle(on: fdaAllowed, enabled: true) { [weak self] on in
            self?.fdaAllowed = on
            if on { self?.openFDA() }
            self?.startButton?.isEnabled = on
            self?.startButton?.alphaValue = on ? 1 : 0.4
        }

        let inner = NSStackView(views: [appIcon, name, NSView(), toggle])
        inner.orientation = .horizontal
        inner.alignment = .centerY
        inner.spacing = 12
        inner.translatesAutoresizingMaskIntoConstraints = false
        wrap.addSubview(inner)
        NSLayoutConstraint.activate([
            wrap.heightAnchor.constraint(equalToConstant: 48),
            appIcon.widthAnchor.constraint(equalToConstant: 28),
            appIcon.heightAnchor.constraint(equalToConstant: 28),
            grid.centerXAnchor.constraint(equalTo: appIcon.centerXAnchor),
            grid.centerYAnchor.constraint(equalTo: appIcon.centerYAnchor),
            grid.widthAnchor.constraint(equalToConstant: 15),
            grid.heightAnchor.constraint(equalToConstant: 15),
            inner.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 14),
            inner.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -14),
            inner.centerYAnchor.constraint(equalTo: wrap.centerYAnchor)
        ])
        return wrap
    }

    @objc private func goEmail() { step = 1; render() }
    @objc private func toggleMarket(_ sender: NSButton) { marketing = sender.state == .on }
    @objc private func openFDA() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
    @objc private func openSignIn() {
        dismissSheet(from: view)
        AppState.shared.showSheet(.signIn)
    }
    @objc private func goFDA() {
        let email = (emailField?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard email.contains("@"), email.contains(".") else {
            errorLabel.stringValue = "Enter a valid email address."
            render()
            return
        }
        // Prefill only — do not mark signed in until a key is activated.
        LicenseStore.setPendingAccount(email: email, marketing: marketing)
        AppState.shared.showToast("Creating your account…")
        Task {
            let response = await LicenseAPI.signup(email: email, marketing: marketing)
            await MainActor.run {
                if response.ok {
                    AppState.shared.showToast(
                        response.message ?? "We emailed your license key. Sign in to continue."
                    )
                    dismissSheet(from: self.view)
                    DispatchQueue.main.async {
                        AppState.shared.showSheet(.signIn)
                    }
                } else {
                    self.errorLabel.stringValue = response.error ?? "Could not create your account."
                    self.errorLabel.isHidden = false
                    self.render()
                }
            }
        }
    }
    @objc private func start() {
        guard fdaAllowed else { return }
        let email = LicenseStore.current.email.isEmpty
            ? LicenseStore.pendingEmail
            : LicenseStore.current.email
        if email.isEmpty {
            step = 1
            render()
            return
        }
        if LicenseStore.current.email.isEmpty {
            LicenseStore.setEmail(email, marketing: LicenseStore.pendingMarketing)
        }
        LicenseStore.completeOnboarding()
        dismissSheet(from: view)
        AppState.shared.startScan()
    }
}

// MARK: Upgrade / Sign in / Account

final class UpgradeController: NSViewController {
    private let reason: String?
    private var selectedPlan = Pricing.Plan.yearly
    private var selectedMacIndex = 0 // 0→1 Mac, 1→2, 2→5
    private var planCards: [PlanCardView] = []
    private var seatButtons: [NSButton] = []
    private var noteLabel: NSTextField!

    init(reason: String?) {
        self.reason = reason
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { nil }

    private var selectedMacs: Int { Pricing.macSeats[selectedMacIndex] }

    override func loadView() {
        let root = sheetRoot()
        root.frame = NSRect(x: 0, y: 0, width: 580, height: 640)
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

        let seatsLabel = makeLabel("How many Macs?", size: 13, weight: .semibold, color: Theme.Colors.muted, align: .center)
        seatButtons = Pricing.macSeats.enumerated().map { idx, count in
            let title = count == 1 ? "1 Mac" : "\(count) Macs"
            let b = NSButton(title: title, target: self, action: #selector(pickSeats(_:)))
            b.tag = idx
            b.bezelStyle = .rounded
            b.setButtonType(.toggle)
            b.state = idx == selectedMacIndex ? .on : .off
            return b
        }
        let seats = NSStackView(views: seatButtons)
        seats.orientation = .horizontal
        seats.spacing = 10
        seats.distribution = .fillEqually
        seats.translatesAutoresizingMaskIntoConstraints = false

        planCards = Pricing.Plan.allCases.map { plan in
            PlanCardView(
                price: Pricing.priceLabel(plan: plan, macs: selectedMacs),
                term: plan.label,
                selected: plan == selectedPlan
            )
        }
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

        noteLabel = makeMultilineLabel(seatNote(), size: 12.5, weight: .regular, color: Theme.Colors.muted)
        noteLabel.alignment = .center

        let buy = PillButton(title: "Continue to checkout", style: .primary)
        buy.target = self
        buy.action = #selector(buySelected)

        let later = PillButton(title: "Maybe later", style: .ghost)
        later.target = self
        later.action = #selector(close)

        let stack = NSStackView(views: [icon, title, body, bullets, seatsLabel, seats, plans, noteLabel, buy, later])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.setCustomSpacing(8, after: title)
        stack.setCustomSpacing(16, after: body)
        stack.setCustomSpacing(18, after: bullets)
        stack.setCustomSpacing(8, after: seatsLabel)
        stack.setCustomSpacing(14, after: seats)
        stack.setCustomSpacing(10, after: plans)
        stack.setCustomSpacing(16, after: noteLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 88),
            icon.heightAnchor.constraint(equalToConstant: 88),
            bullets.widthAnchor.constraint(equalToConstant: 440),
            seats.widthAnchor.constraint(equalToConstant: 360),
            plans.widthAnchor.constraint(equalToConstant: 500),
            plans.heightAnchor.constraint(equalToConstant: 92),
            noteLabel.widthAnchor.constraint(equalToConstant: 460),
            buy.widthAnchor.constraint(equalToConstant: 220),
            later.widthAnchor.constraint(equalToConstant: 180),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -28)
        ])
        refreshPlanCards()
    }

    private static func brandIcon() -> NSImage { sheetBrandImage(size: 88) }

    private func seatNote() -> String {
        let n = selectedMacs
        return "Each Mac you sign in on is linked to your license. \(n) Mac\(n == 1 ? "" : "s") max — seats stay linked once used."
    }

    private func refreshPlanCards() {
        for (i, card) in planCards.enumerated() {
            guard let plan = Pricing.Plan(rawValue: i) else { continue }
            card.update(
                price: Pricing.priceLabel(plan: plan, macs: selectedMacs),
                term: Pricing.termLabel(plan: plan, macs: selectedMacs)
            )
            card.setSelected(plan == selectedPlan)
        }
        noteLabel?.stringValue = seatNote()
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

    @objc private func pickSeats(_ sender: NSButton) {
        selectedMacIndex = sender.tag
        for b in seatButtons { b.state = b.tag == selectedMacIndex ? .on : .off }
        refreshPlanCards()
    }

    @objc private func pickPlan(_ sender: NSClickGestureRecognizer) {
        guard let card = sender.view as? PlanCardView,
              let plan = Pricing.Plan(rawValue: card.planIndex) else { return }
        selectedPlan = plan
        refreshPlanCards()
    }

    @objc private func buySelected() {
        var comps = URLComponents(string: "https://www.iclearer.com/")!
        comps.queryItems = [
            URLQueryItem(name: "buy", value: "1"),
            URLQueryItem(name: "plan", value: selectedPlan.apiValue),
            URLQueryItem(name: "macs", value: String(selectedMacs)),
            URLQueryItem(name: "email", value: LicenseStore.current.email),
            URLQueryItem(name: "key", value: LicenseStore.current.key)
        ]
        if let url = comps.url {
            NSWorkspace.shared.open(url)
            AppState.shared.showToast("Complete checkout in your browser. Your same key upgrades — each Mac is linked as a seat.")
        }
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
        self.termLabel = makeLabel(term, size: 11.5, weight: .regular, color: Theme.Colors.muted, align: .center)
        self.termLabel.maximumNumberOfLines = 2
        self.termLabel.lineBreakMode = .byWordWrapping
        super.init(frame: .zero)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        layer?.cornerRadius = 16
        layer?.backgroundColor = Theme.Colors.contentAlt.cgColor
        addSubview(priceLabel)
        addSubview(termLabel)
        NSLayoutConstraint.activate([
            priceLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            priceLabel.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            termLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            termLabel.topAnchor.constraint(equalTo: priceLabel.bottomAnchor, constant: 4),
            termLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
            termLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
            termLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -10)
        ])
        setSelected(selected)
    }

    func update(price: String, term: String) {
        priceLabel.stringValue = price
        termLabel.stringValue = term
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
    private var emailField: NSTextField!
    private var keyField: NSTextField!
    private let errorLabel = makeLabel("", size: 12.5, weight: .medium, color: NSColor(srgbRed: 0xD0 / 255, green: 0x45 / 255, blue: 0x3F / 255, alpha: 1))
    private let tx = NSColor(srgbRed: 0xF2 / 255, green: 0xF5 / 255, blue: 0xF8 / 255, alpha: 1)
    private let mu = NSColor(srgbRed: 0x9A / 255, green: 0xA8 / 255, blue: 0xB6 / 255, alpha: 1)
    private let cardW: CGFloat = 440
    private let edgePad: CGFloat = 28
    private var contentW: CGFloat { cardW - edgePad * 2 }

    override func loadView() {
        view = sheetRoot(width: cardW, height: 320)
        render()
    }

    private func render() {
        view.subviews.forEach { $0.removeFromSuperview() }

        let column = NSView()
        column.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(column)

        let title = makeLabel("Sign in or activate", size: 21, weight: .bold, color: tx, align: .center)
        let body = makeMultilineLabel(
            "Enter the email you bought with and your license key. Or send yourself the license key.",
            size: 13.5, weight: .regular, color: mu
        )
        body.alignment = .center
        body.preferredMaxLayoutWidth = contentW
        body.translatesAutoresizingMaskIntoConstraints = false
        body.widthAnchor.constraint(equalToConstant: contentW).isActive = true

        let prefill = LicenseStore.current.email.isEmpty
            ? LicenseStore.pendingEmail
            : LicenseStore.current.email
        let email = makeSheetInput(placeholder: "Email", value: prefill)
        emailField = email.field
        let key = makeSheetInput(placeholder: "License key, for example ICLR-XXXX-XXXX-XXXX")
        keyField = key.field
        email.wrap.widthAnchor.constraint(equalToConstant: contentW).isActive = true
        key.wrap.widthAnchor.constraint(equalToConstant: contentW).isActive = true
        errorLabel.alignment = .center
        errorLabel.isHidden = errorLabel.stringValue.isEmpty
        errorLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        errorLabel.widthAnchor.constraint(equalToConstant: contentW).isActive = true

        // Compact pills sized to their labels, centered as a pair (prototype sign-in).
        let linkBtn = makeGhostButton("Email me my key")
        linkBtn.target = self
        linkBtn.action = #selector(emailLink)
        let activateBtn = makeAccentButton("Activate")
        activateBtn.target = self
        activateBtn.action = #selector(activate)
        let actions = NSStackView(views: [linkBtn, activateBtn])
        actions.orientation = .horizontal
        actions.alignment = .centerY
        actions.distribution = .gravityAreas
        actions.spacing = 14
        actions.translatesAutoresizingMaskIntoConstraints = false

        let demo = makeLabel(
            "Demo: any key works. Add ONCE to the key for a one-time license.",
            size: 12, weight: .regular, color: mu, align: .center
        )

        let signup = makeSignUpFooter()

        let stack = NSStackView(views: [
            title, body, email.wrap, key.wrap, errorLabel, actions, demo, signup
        ])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.setCustomSpacing(6, after: title)
        stack.setCustomSpacing(14, after: body)
        stack.setCustomSpacing(8, after: email.wrap)
        stack.setCustomSpacing(errorLabel.isHidden ? 12 : 4, after: key.wrap)
        stack.setCustomSpacing(errorLabel.isHidden ? 0 : 12, after: errorLabel)
        stack.setCustomSpacing(12, after: actions)
        stack.setCustomSpacing(10, after: demo)
        stack.translatesAutoresizingMaskIntoConstraints = false
        column.addSubview(stack)

        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: edgePad),
            column.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -edgePad),
            column.topAnchor.constraint(equalTo: view.topAnchor, constant: edgePad),
            column.widthAnchor.constraint(equalToConstant: contentW),
            stack.leadingAnchor.constraint(equalTo: column.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: column.trailingAnchor),
            stack.topAnchor.constraint(equalTo: column.topAnchor),
            stack.bottomAnchor.constraint(equalTo: column.bottomAnchor)
        ])

        view.setFrameSize(NSSize(width: cardW, height: 900))
        view.layoutSubtreeIfNeeded()
        let fitted = ceil(stack.fittingSize.height) + edgePad * 2
        let size = NSSize(width: cardW, height: max(280, fitted))
        view.setFrameSize(size)
        view.window?.setContentSize(size)
    }

    private func makeSignUpFooter() -> NSView {
        let prefix = makeLabel("Don’t have an account? ", size: 12.5, weight: .regular, color: mu)
        let link = NSButton(title: "Sign up", target: self, action: #selector(openSignUp))
        link.isBordered = false
        link.font = .systemFont(ofSize: 12.5, weight: .semibold)
        link.contentTintColor = Theme.sky
        link.translatesAutoresizingMaskIntoConstraints = false
        let row = NSStackView(views: [prefix, link])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 0
        return row
    }

    @objc private func openSignUp() {
        dismissSheet(from: view)
        DispatchQueue.main.async {
            AppState.shared.showSheet(.onboarding)
        }
    }

    @objc private func emailLink() {
        let email = emailField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard email.contains("@"), email.contains(".") else {
            errorLabel.stringValue = "Enter a valid email address."
            render()
            return
        }
        errorLabel.stringValue = "Sending…"
        errorLabel.isHidden = false
        render()
        Task {
            // Resend the license key only — no magic web link.
            let response = await LicenseAPI.resendKey(email: email)
            await MainActor.run {
                if response.ok {
                    self.errorLabel.stringValue = ""
                    self.render()
                    AppState.shared.showToast(response.message ?? "We emailed your license key.")
                } else {
                    self.errorLabel.stringValue = response.error ?? "Could not send email."
                    self.errorLabel.isHidden = false
                    self.render()
                }
            }
        }
    }

    @objc private func activate() {
        let email = emailField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = keyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        errorLabel.stringValue = "Signing in…"
        errorLabel.isHidden = false
        render()
        Task {
            let response = await LicenseAPI.activate(email: email, key: key)
            await MainActor.run {
                if response.ok {
                    LicenseStore.applyRemote(response)
                    // Guarantee local credentials even if the payload omits fields.
                    LicenseStore.update {
                        if $0.email.isEmpty { $0.email = email.lowercased() }
                        if $0.key.isEmpty { $0.key = key.uppercased() }
                        $0.onboardingComplete = true
                    }
                    AppState.shared.showToast(response.message ?? "Signed in.")
                    dismissSheet(from: self.view)
                    return
                }
                // Offline / API down: allow seeded test keys only.
                let fallback = LicenseStore.activateOfflineFallback(email: email, key: key)
                if fallback.ok {
                    AppState.shared.showToast(fallback.message)
                    dismissSheet(from: self.view)
                } else {
                    self.errorLabel.stringValue = response.error ?? fallback.message
                    self.errorLabel.isHidden = false
                    self.render()
                }
            }
        }
    }
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

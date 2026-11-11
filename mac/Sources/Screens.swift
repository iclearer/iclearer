import AppKit

enum ScreenFactory {
    static func view(for screen: AppScreen, state: AppState, host: MainViewController) -> NSView {
        switch screen {
        case .overview: return OverviewScreen(state: state)
        case .clean: return CleanScreen(state: state)
        case .storageMap: return StorageMapScreen(state: state)
        case .largeFiles: return LargeFilesScreen(state: state)
        case .apps: return AppsScreen(state: state)
        case .builders: return BuildersScreen(state: state)
        case .history: return HistoryScreen(state: state)
        case .duplicates, .maintenance: return ComingSoonScreen(screen: screen, state: state)
        }
    }
}

// MARK: Overview

final class OverviewScreen: NSView {
    private let state: AppState
    private var lastFingerprint = ""

    init(state: AppState) {
        self.state = state
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        // Map measure is started with the PC scan; only kick one off if none is running.
        state.ensureStorageMap()
        lastFingerprint = fingerprint()
        rebuild()
    }

    required init?(coder: NSCoder) { nil }

    func refreshFromState() {
        let next = fingerprint()
        guard next != lastFingerprint else { return }
        lastFingerprint = next
        rebuild()
    }

    private func fingerprint() -> String {
        let p = state.scanProgress
        let mapSum = state.storageMapSlices?.reduce(Int64(0)) { $0 + $1.bytes } ?? -1
        return "\(state.isScanning)|\(Int(p.fraction * 100))|\(p.foundBytes)|\(p.foundCount)|\(p.label)|\(p.hint ?? "")|\(state.totalFoundBytes)|\(state.safeBytes)|\(state.isPro)|\(state.disk.free)|\(state.disk.used)|\(state.disk.total)|\(state.isMeasuringStorageMap)|\(mapSum)|\(state.largeFilesBytes)|\(state.largeFiles.count)"
    }

    private func rebuild() {
        subviews.forEach { $0.removeFromSuperview() }

        // Prototype ovw() when scan < 100: centered ring + “Scanning your Mac…”
        if state.isScanning {
            let scan = ScanProgressPanel(progress: state.scanProgress)
            scan.translatesAutoresizingMaskIntoConstraints = false
            addSubview(scan)
            NSLayoutConstraint.activate([
                scan.leadingAnchor.constraint(equalTo: leadingAnchor),
                scan.trailingAnchor.constraint(equalTo: trailingAnchor),
                scan.topAnchor.constraint(equalTo: topAnchor),
                scan.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
            return
        }

        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.scrollerStyle = .overlay
        scroll.translatesAutoresizingMaskIntoConstraints = false
        let doc = FlippedView()
        doc.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = doc
        addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let hero = HeroCardView()
        let foundLabel = makeLabel("", size: 12, weight: .semibold, color: NSColor.white.withAlphaComponent(0.8))
        foundLabel.attributedStringValue = NSAttributedString(string: "FOUND ON YOUR MAC", attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.8),
            .kern: 0.08 * 12
        ])
        // Hero big number = everything found. Safe amount is called out in the subtitle.
        let amountText = AppFormat.bytes(state.totalFoundBytes)
        let big = makeLabel(amountText, size: 60, weight: .bold, color: .white)
        big.attributedStringValue = NSAttributedString(string: amountText, attributes: [
            .font: NSFont.systemFont(ofSize: 60, weight: .bold),
            .foregroundColor: NSColor.white,
            .kern: -0.05 * 60
        ])
        let safeLine = makeMultilineLabel(
            "\(AppFormat.bytes(state.safeBytes)) of it is Safe to clear now. The rest needs a quick look from you.",
            size: 14.5, weight: .regular, color: NSColor.white.withAlphaComponent(0.9)
        )
        // Clean Safe = solid white; Review = frosted glass (stripe shows through).
        let cleanSafe = PillButton(title: "Clean Safe items", style: .soft)
        cleanSafe.target = self
        cleanSafe.action = #selector(goSafe)
        cleanSafe.wantsLayer = true
        cleanSafe.layer?.zPosition = 10
        let review = PillButton(title: "Review everything", style: .onDarkGhost)
        review.target = self
        review.action = #selector(goClean)
        review.wantsLayer = true
        review.layer?.zPosition = 10
        let actions = NSStackView(views: [cleanSafe, review])
        actions.orientation = .horizontal
        actions.spacing = 8
        actions.alignment = .centerY

        let heroStack = NSStackView(views: [foundLabel, big, safeLine, actions])
        heroStack.orientation = .vertical
        heroStack.alignment = .leading
        heroStack.spacing = 6
        heroStack.setCustomSpacing(18, after: safeLine)
        heroStack.translatesAutoresizingMaskIntoConstraints = false
        heroStack.wantsLayer = true
        heroStack.layer?.zPosition = 10
        hero.addSubview(heroStack)

        // Bead sits above the glass streak — never blurred/covered by it.
        let bead = LiquidGlassBeadView()
        bead.diameter = 140
        bead.wantsLayer = true
        bead.layer?.zPosition = 20
        bead.layer?.masksToBounds = false
        hero.addSubview(bead)

        let tiles = NSStackView()
        tiles.orientation = .horizontal
        tiles.distribution = .fillEqually
        tiles.spacing = 14
        tiles.translatesAutoresizingMaskIntoConstraints = false
        tiles.addArrangedSubview(makeTile(title: AppFormat.bytes(state.everydayBytes()), subtitle: "Everyday junk", screen: .clean))
        tiles.addArrangedSubview(makeTile(title: AppFormat.bytes(state.buildersBytes()), subtitle: "Builders and AI tools", screen: .builders))
        tiles.addArrangedSubview(makeTile(
            title: AppFormat.bytes(state.largeFilesBytes),
            subtitle: "Large and old files",
            screen: .largeFiles
        ))

        let diskCard = CardView()
        diskCard.kind = .contentAlt
        let diskTitle = makeLabel("Your disk", size: 14, weight: .semibold, color: Theme.Colors.text)
        let bar = SegmentBarView()
        // Overview bar matches prototype: Apps → Dev → Photos → Docs → System → Other → Free
        // (iCloud folded into Other, same as the handoff disk card).
        bar.slices = state.diskBarSlices().map {
            SegmentBarView.Slice(name: $0.name, bytes: $0.bytes, color: $0.color, isFree: $0.name == "Free")
        }
        bar.translatesAutoresizingMaskIntoConstraints = false
        let diskDetail = makeLabel(
            "\(AppFormat.bytes(state.disk.free)) free of \(AppFormat.bytes(state.disk.total)). Clean the Safe items to gain \(AppFormat.bytes(state.safeBytes)).",
            size: 12.5, weight: .regular, color: Theme.Colors.muted
        )
        diskDetail.maximumNumberOfLines = 2
        diskDetail.lineBreakMode = .byWordWrapping
        let diskStack = NSStackView(views: [diskTitle, bar, diskDetail])
        diskStack.orientation = .vertical
        diskStack.alignment = .leading
        diskStack.spacing = 10
        diskStack.translatesAutoresizingMaskIntoConstraints = false
        diskCard.addSubview(diskStack)

        var columnViews: [NSView] = [hero, tiles, diskCard]
        if !state.isPro {
            columnViews.append(makeUpsellBanner())
        }
        let column = NSStackView(views: columnViews)
        column.orientation = .vertical
        // Stretch hero / tiles / disk / upsell to the full content width (not centered).
        column.alignment = .width
        column.spacing = 14
        column.translatesAutoresizingMaskIntoConstraints = false
        column.setHuggingPriority(.defaultLow, for: .horizontal)
        doc.addSubview(column)

        tiles.setContentHuggingPriority(.defaultLow, for: .horizontal)
        hero.setContentHuggingPriority(.defaultLow, for: .horizontal)
        diskCard.setContentHuggingPriority(.defaultLow, for: .horizontal)

        NSLayoutConstraint.activate([
            // Document fills the clip view so cards can span the panel.
            doc.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            doc.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            doc.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),

            // Prototype #ct padding: 20px 22px — edge to edge inside the content panel.
            column.leadingAnchor.constraint(equalTo: doc.leadingAnchor, constant: 22),
            column.trailingAnchor.constraint(equalTo: doc.trailingAnchor, constant: -22),
            column.topAnchor.constraint(equalTo: doc.topAnchor, constant: 20),
            column.bottomAnchor.constraint(equalTo: doc.bottomAnchor, constant: -24),

            // Prototype hero padding 28×30, bead 140 @ right 34
            hero.heightAnchor.constraint(greaterThanOrEqualToConstant: 220),
            heroStack.leadingAnchor.constraint(equalTo: hero.leadingAnchor, constant: 30),
            heroStack.trailingAnchor.constraint(lessThanOrEqualTo: bead.leadingAnchor, constant: -16),
            heroStack.topAnchor.constraint(equalTo: hero.topAnchor, constant: 28),
            heroStack.bottomAnchor.constraint(equalTo: hero.bottomAnchor, constant: -28),
            safeLine.widthAnchor.constraint(lessThanOrEqualToConstant: 480),
            cleanSafe.heightAnchor.constraint(equalToConstant: 36),
            review.heightAnchor.constraint(equalToConstant: 36),

            bead.widthAnchor.constraint(equalToConstant: 140),
            bead.heightAnchor.constraint(equalToConstant: 140),
            bead.trailingAnchor.constraint(equalTo: hero.trailingAnchor, constant: -34),
            bead.centerYAnchor.constraint(equalTo: hero.centerYAnchor),

            bar.heightAnchor.constraint(equalToConstant: 16),
            bar.widthAnchor.constraint(equalTo: diskStack.widthAnchor),
            diskStack.leadingAnchor.constraint(equalTo: diskCard.leadingAnchor, constant: 18),
            diskStack.trailingAnchor.constraint(equalTo: diskCard.trailingAnchor, constant: -18),
            diskStack.topAnchor.constraint(equalTo: diskCard.topAnchor, constant: 16),
            diskStack.bottomAnchor.constraint(equalTo: diskCard.bottomAnchor, constant: -16),
            tiles.heightAnchor.constraint(equalToConstant: 122)
        ])
    }

    private func makeUpsellBanner() -> NSView {
        // Prototype: flex row lock | (h3 + span) | See plans
        let card = CardView()
        card.kind = .contentAlt
        let lock = LiquidLockBadgeView()
        lock.size = 28
        let title = makeLabel(
            "Free plan: \(AppFormat.freeQuota(state.license.remainingFreeBytes)) of cleanup left",
            size: 14, weight: .semibold, color: Theme.Colors.text
        )
        let body = makeLabel(
            "Scanning is always free. Locations, the full Storage Map and unlimited cleanup come with iClearer.",
            size: 12.5, weight: .regular, color: Theme.Colors.muted
        )
        body.maximumNumberOfLines = 2
        body.lineBreakMode = .byWordWrapping
        let text = NSStackView(views: [title, body])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 2
        text.translatesAutoresizingMaskIntoConstraints = false
        let see = PillButton(title: "See plans", style: .primary)
        see.compact = true
        see.target = self
        see.action = #selector(seePlans)
        see.wantsLayer = true
        see.layer?.zPosition = 2
        card.addSubview(lock)
        card.addSubview(text)
        card.addSubview(see)
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 76),
            lock.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            lock.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            lock.widthAnchor.constraint(equalToConstant: 28),
            lock.heightAnchor.constraint(equalToConstant: 28),
            text.leadingAnchor.constraint(equalTo: lock.trailingAnchor, constant: 14),
            text.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            text.trailingAnchor.constraint(lessThanOrEqualTo: see.leadingAnchor, constant: -16),
            see.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            see.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            see.heightAnchor.constraint(equalToConstant: 30),
            see.widthAnchor.constraint(greaterThanOrEqualToConstant: 102)
        ])
        return card
    }

    private func makeTile(title: String, subtitle: String, screen: AppScreen) -> NSView {
        // Prototype .tile: radius 20, padding 16, icon 30, b 21, span muted
        let card = CardView()
        card.kind = .contentAlt
        card.translatesAutoresizingMaskIntoConstraints = false

        let badge = IconBadgeView()
        badge.screen = screen == .clean ? .clean : screen
        badge.setSymbol(SFSymbol.forScreen(screen == .clean ? .clean : screen))
        badge.setBadgeSize(30)
        let t = makeLabel(title, size: 21, weight: .bold, color: Theme.Colors.text)
        t.attributedStringValue = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 21, weight: .bold),
            .foregroundColor: Theme.Colors.text,
            .kern: -0.03 * 21
        ])
        let s = makeLabel(subtitle, size: 12.5, weight: .regular, color: Theme.Colors.muted)
        let stack = NSStackView(views: [badge, t, s])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.setCustomSpacing(10, after: badge)
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: 30),
            badge.heightAnchor.constraint(equalToConstant: 30),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        let click = NSClickGestureRecognizer(target: self, action: #selector(tileClicked(_:)))
        card.addGestureRecognizer(click)
        card.identifier = NSUserInterfaceItemIdentifier(screen.rawValue)
        return card
    }

    @objc private func goSafe() {
        state.selectSafeOnly()
        state.navigate(.clean)
    }
    @objc private func goClean() { state.navigate(.clean) }
    @objc private func seePlans() { state.showSheet(.upgrade) }
    @objc private func tileClicked(_ sender: NSClickGestureRecognizer) {
        guard let view = sender.view,
              let raw = view.identifier?.rawValue,
              let screen = AppScreen(rawValue: raw) else { return }
        state.navigate(screen)
    }
}

/// Centered scan UI matching prototype `.scan` + progress ring (`#7FB8E6` → `#3FA877`).
final class ScanProgressPanel: NSView {
    private let ring = ScanRingView()
    private let titleLabel = makeLabel("Scanning your Mac…", size: 20, weight: .semibold, color: Theme.Colors.text)
    private let detailLabel = makeLabel("", size: 13, weight: .regular, color: Theme.Colors.muted)

    init(progress: ScanProgress) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true

        ring.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.alignment = .center
        detailLabel.alignment = .center
        detailLabel.maximumNumberOfLines = 2

        let stack = NSStackView(views: [ring, titleLabel, detailLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.setCustomSpacing(14, after: ring)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            // Bigger than prototype 210 — reads closer to the reference crop.
            ring.widthAnchor.constraint(equalToConstant: 280),
            ring.heightAnchor.constraint(equalToConstant: 280),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -12),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
            detailLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 420)
        ])
        apply(progress)
    }

    required init?(coder: NSCoder) { nil }

    private func apply(_ progress: ScanProgress) {
        ring.progress = max(0, min(1, progress.fraction))
        let pct = Int((progress.fraction * 100).rounded())
        ring.percentText = "\(pct)%"
        titleLabel.stringValue = progress.label.isEmpty ? "Scanning your Mac…" : progress.label
        if let hint = progress.hint, !hint.isEmpty {
            detailLabel.stringValue = hint
            detailLabel.textColor = Theme.Colors.accent
        } else {
            let items = AppFormat.count(progress.foundCount)
            let bytes = AppFormat.bytes(progress.foundBytes)
            detailLabel.stringValue = "\(items) items checked · \(bytes) found"
            detailLabel.textColor = Theme.Colors.muted
        }
        titleLabel.textColor = Theme.Colors.text
    }
}

/// Scan ring: thicker track, green → teal → blue stroke gradient along the arc.
final class ScanRingView: NSView {
    var progress: CGFloat = 0 {
        didSet { needsDisplay = true }
    }
    var percentText: String = "0%" {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let side = min(bounds.width, bounds.height)
        let inset: CGFloat = 8
        let rect = NSRect(
            x: (bounds.width - side) / 2 + inset,
            y: (bounds.height - side) / 2 + inset,
            width: side - inset * 2,
            height: side - inset * 2
        )
        // Prototype stroke 7 on 120 viewBox @ 210px ≈ 12pt; bump for the larger ring.
        let lineWidth: CGFloat = 14
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width / 2 - lineWidth / 2

        // Track
        let track = NSBezierPath()
        track.appendArc(withCenter: NSPoint(x: center.x, y: center.y), radius: radius, startAngle: 0, endAngle: 360)
        track.lineWidth = lineWidth
        NSColor(calibratedWhite: 1, alpha: 0.12).setStroke()
        track.stroke()

        guard progress > 0.001, let ctx = NSGraphicsContext.current?.cgContext else {
            drawPercent()
            return
        }

        // Path gradient: mint green → sky blue → mint green (reads green→blue mid-scan,
        // and green again when full). Painted as short arc segments along the stroke.
        let green = NSColor(hex: 0x3FA877)
        let teal = NSColor(hex: 0x5FD0C8)
        let blue = NSColor(hex: 0x7FB8E6)
        let start = CGFloat.pi / 2 // 12 o’clock
        let totalSweep = -2 * CGFloat.pi * progress
        let segments = max(24, Int(ceil(120 * progress)))

        ctx.saveGState()
        ctx.setLineWidth(lineWidth)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        for i in 0..<segments {
            let t0 = CGFloat(i) / CGFloat(segments)
            let t1 = CGFloat(i + 1) / CGFloat(segments)
            let a0 = start + totalSweep * t0
            let a1 = start + totalSweep * t1
            // Mid-scan: green at 12 o’clock → blue at the tip.
            // Full lap: green → blue → green so the join reads clean.
            let hueT = progress >= 0.995 ? t0 : (0.5 * t0)
            let color = Self.strokeColor(at: hueT, green: green, teal: teal, blue: blue)
            ctx.setStrokeColor(color.cgColor)
            ctx.beginPath()
            // Overlap slightly so round caps don’t leave gaps.
            let overlap: CGFloat = i == 0 ? 0 : 0.012
            ctx.addArc(
                center: center,
                radius: radius,
                startAngle: a0 + (totalSweep < 0 ? overlap : -overlap),
                endAngle: a1,
                clockwise: true
            )
            ctx.strokePath()
        }
        ctx.restoreGState()
        drawPercent()
    }

    /// Green → teal → blue → teal → green across a full lap.
    private static func strokeColor(at t: CGFloat, green: NSColor, teal: NSColor, blue: NSColor) -> NSColor {
        let x = max(0, min(1, t))
        if x < 0.25 {
            return blend(green, teal, x / 0.25)
        } else if x < 0.5 {
            return blend(teal, blue, (x - 0.25) / 0.25)
        } else if x < 0.75 {
            return blend(blue, teal, (x - 0.5) / 0.25)
        } else {
            return blend(teal, green, (x - 0.75) / 0.25)
        }
    }

    private static func blend(_ a: NSColor, _ b: NSColor, _ t: CGFloat) -> NSColor {
        let u = max(0, min(1, t))
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.usingColorSpace(.deviceRGB)?.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.usingColorSpace(.deviceRGB)?.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return NSColor(
            calibratedRed: ar + (br - ar) * u,
            green: ag + (bg - ag) * u,
            blue: ab + (bb - ab) * u,
            alpha: 1
        )
    }

    private func drawPercent() {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 44, weight: .bold),
            .foregroundColor: Theme.Colors.text
        ]
        let size = (percentText as NSString).size(withAttributes: attrs)
        let origin = NSPoint(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2 - 1
        )
        (percentText as NSString).draw(at: origin, withAttributes: attrs)
    }
}

/// Blue radial hero matching prototype `.hero` + diagonal glass streak + bead.
final class HeroCardView: NSView {
    private let base = CALayer()
    private let radial = CAGradientLayer()
    /// Prototype `.hero::after` — solid rgba(255,255,255,.12) band (clear edges, not a soft glow).
    private let streak = CALayer()
    private var didInstallStreak = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        layer?.cornerRadius = 24
        // Clip the stripe to the card, but keep subviews (bead) composited above.
        layer?.masksToBounds = true
        layer?.shadowColor = NSColor(hex: 0x1E5A96).cgColor
        layer?.shadowOpacity = 0.55
        layer?.shadowRadius = 22
        layer?.shadowOffset = CGSize(width: 0, height: -10)

        base.name = "heroBase"
        base.zPosition = 0
        base.backgroundColor = NSColor(hex: 0x173F68).cgColor
        layer?.addSublayer(base)

        radial.name = "heroGrad"
        radial.zPosition = 1
        radial.type = .radial
        radial.colors = [
            NSColor(hex: 0x58A0D6).cgColor,
            NSColor(hex: 0x2D6DA4).cgColor,
            NSColor(hex: 0x173F68).cgColor
        ]
        radial.locations = [0, 0.5, 1]
        // CSS radial at top-left; CALayer y-up → center (0,1)
        radial.startPoint = CGPoint(x: 0.0, y: 1.0)
        radial.endPoint = CGPoint(x: 1.15, y: -0.35)
        layer?.addSublayer(radial)

        // Clear glass stripe — flat band, capsule ends, BL → TR under the bead.
        streak.name = "heroStreak"
        streak.zPosition = 2
        streak.backgroundColor = NSColor.white.withAlphaComponent(0.16).cgColor
        layer?.addSublayer(streak)
        didInstallStreak = true
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        guard let layer else { return }
        layer.masksToBounds = true
        base.frame = bounds
        base.cornerRadius = 24
        radial.frame = bounds
        radial.cornerRadius = 24

        // CSS: left:-10%; right:-10%; top:38%; height:70px; rotate(-8deg)
        let streakH: CGFloat = 72
        streak.bounds = CGRect(x: 0, y: 0, width: bounds.width * 1.35, height: streakH)
        let cssTop = bounds.height * 0.38
        streak.position = CGPoint(x: bounds.midX, y: bounds.height - cssTop - streakH * 0.5)
        streak.transform = CATransform3DMakeRotation(8 * .pi / 180, 0, 0, 1)
        streak.cornerRadius = streakH / 2
        streak.zPosition = 2
        if !didInstallStreak {
            layer.insertSublayer(streak, above: radial)
            didInstallStreak = true
        }

        // Subview layers (text + bead) stay above the streak.
        for sub in subviews {
            sub.wantsLayer = true
            sub.layer?.zPosition = max(sub.layer?.zPosition ?? 0, 10)
        }
    }
}

// MARK: Clean

final class CleanScreen: NSView {
    private let state: AppState
    private let listStack = NSStackView()
    private let scroll = NSScrollView()
    private let listDoc = FlippedView()
    private let inspector = InspectorView()
    private var filterChips: [CleanFilterPill] = []
    private let bannersHost = NSStackView()
    private var freeBanner: NSView!
    private var askBanner: NSView!
    private var askBannerLabel: NSTextField!

    init(state: AppState) {
        self.state = state
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        build()
        reload()
    }

    required init?(coder: NSCoder) { nil }

    private func build() {
        listStack.orientation = .vertical
        listStack.spacing = 8
        listStack.alignment = .leading
        listStack.translatesAutoresizingMaskIntoConstraints = false

        listDoc.translatesAutoresizingMaskIntoConstraints = false
        listDoc.addSubview(listStack)

        scroll.documentView = listDoc
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        // Keep last rows reachable above the floating Clean Up pill (overlay, not a footer bar).
        scroll.automaticallyAdjustsContentInsets = false
        scroll.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 78, right: 0)
        scroll.scrollerInsets = NSEdgeInsets(top: 0, left: 0, bottom: 78, right: 0)

        inspector.translatesAutoresizingMaskIntoConstraints = false
        inspector.onReveal = { [weak self] item in
            guard let self else { return }
            if self.state.isPro {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
            } else {
                self.state.showSheet(.upgrade, reason: "Reveal in Finder is part of iClearer.")
            }
        }
        inspector.onNever = { [weak self] item in
            self?.state.protectPath(item.path)
        }
        inspector.onUpgrade = { [weak self] in
            self?.state.showSheet(.upgrade)
        }

        // All | Everyday | Builders — explicit pills (ChipButton was collapsing to 0×0).
        let titles = ["All", "Everyday", "Builders"]
        filterChips = titles.enumerated().map { index, title in
            let pill = CleanFilterPill(title: title, tag: index)
            pill.target = self
            pill.action = #selector(filterChip(_:))
            return pill
        }
        filterChips[0].isSelected = true

        let filterRow = NSStackView(views: filterChips)
        filterRow.orientation = .horizontal
        filterRow.spacing = 8
        filterRow.alignment = .centerY
        filterRow.translatesAutoresizingMaskIntoConstraints = false
        filterRow.setContentHuggingPriority(.required, for: .horizontal)
        filterRow.setContentCompressionResistancePriority(.required, for: .horizontal)

        let selectSafe = NSButton(title: "Select Safe only", target: self, action: #selector(selectSafeOnly))
        selectSafe.isBordered = false
        selectSafe.font = .systemFont(ofSize: 12.5, weight: .semibold)
        selectSafe.contentTintColor = Theme.Colors.accent
        selectSafe.translatesAutoresizingMaskIntoConstraints = false
        selectSafe.setContentHuggingPriority(.required, for: .horizontal)
        selectSafe.setContentCompressionResistancePriority(.required, for: .horizontal)

        let clearPicks = NSButton(title: "Clear picks", target: self, action: #selector(clearPicks))
        clearPicks.isBordered = false
        clearPicks.font = .systemFont(ofSize: 12.5, weight: .regular)
        clearPicks.contentTintColor = Theme.Colors.muted
        clearPicks.translatesAutoresizingMaskIntoConstraints = false
        clearPicks.setContentHuggingPriority(.required, for: .horizontal)
        clearPicks.setContentCompressionResistancePriority(.required, for: .horizontal)

        let leadingFlex = NSView()
        leadingFlex.translatesAutoresizingMaskIntoConstraints = false
        leadingFlex.setContentHuggingPriority(.defaultLow, for: .horizontal)
        leadingFlex.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // Keep Select Safe + Clear picks as a trailing pair (not stretched across the row).
        let actionsRow = NSStackView(views: [selectSafe, clearPicks])
        actionsRow.orientation = .horizontal
        actionsRow.spacing = 28
        actionsRow.alignment = .centerY
        actionsRow.translatesAutoresizingMaskIntoConstraints = false
        actionsRow.setContentHuggingPriority(.required, for: .horizontal)
        actionsRow.setContentCompressionResistancePriority(.required, for: .horizontal)

        let toolbar = NSStackView(views: [filterRow, leadingFlex, actionsRow])
        toolbar.orientation = .horizontal
        toolbar.spacing = 12
        toolbar.alignment = .centerY
        toolbar.distribution = .fill
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.setContentHuggingPriority(.required, for: .vertical)

        freeBanner = makeCleanFreeBanner()
        askBanner = makeAskFirstBanner()
        bannersHost.orientation = .vertical
        bannersHost.spacing = 8
        bannersHost.alignment = .leading
        bannersHost.translatesAutoresizingMaskIntoConstraints = false
        bannersHost.setContentHuggingPriority(.required, for: .vertical)
        bannersHost.setContentCompressionResistancePriority(.required, for: .vertical)
        bannersHost.addArrangedSubview(freeBanner)
        bannersHost.addArrangedSubview(askBanner)
        freeBanner.widthAnchor.constraint(equalTo: bannersHost.widthAnchor).isActive = true
        askBanner.widthAnchor.constraint(equalTo: bannersHost.widthAnchor).isActive = true

        addSubview(toolbar)
        addSubview(bannersHost)
        addSubview(scroll)
        addSubview(inspector)

        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            // Extra inset so Clear picks isn’t jammed against the inspector edge.
            toolbar.trailingAnchor.constraint(equalTo: inspector.leadingAnchor, constant: -28),
            toolbar.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            toolbar.heightAnchor.constraint(equalToConstant: 32),

            leadingFlex.widthAnchor.constraint(greaterThanOrEqualToConstant: 24),

            bannersHost.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            bannersHost.trailingAnchor.constraint(equalTo: inspector.leadingAnchor, constant: -12),
            bannersHost.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 12),

            scroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            scroll.topAnchor.constraint(equalTo: bannersHost.bottomAnchor, constant: 10),
            // Full height under the floating Clean Up overlay — files scroll beneath it.
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            scroll.trailingAnchor.constraint(equalTo: inspector.leadingAnchor, constant: -8),

            inspector.trailingAnchor.constraint(equalTo: trailingAnchor),
            inspector.topAnchor.constraint(equalTo: topAnchor),
            inspector.bottomAnchor.constraint(equalTo: bottomAnchor),
            inspector.widthAnchor.constraint(equalToConstant: 292),

            listStack.leadingAnchor.constraint(equalTo: listDoc.leadingAnchor),
            listStack.trailingAnchor.constraint(equalTo: listDoc.trailingAnchor),
            listStack.topAnchor.constraint(equalTo: listDoc.topAnchor),
            listStack.bottomAnchor.constraint(equalTo: listDoc.bottomAnchor, constant: -12),
            listStack.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -18)
        ])
    }

    private func makeCleanFreeBanner() -> NSView {
        // Full-width top strip (not a modal) — matches Clean free-plan bar in refs.
        let ban = NSView()
        ban.wantsLayer = true
        ban.translatesAutoresizingMaskIntoConstraints = false
        ban.layer?.cornerRadius = 14
        ban.layer?.backgroundColor = Theme.Colors.contentAlt.cgColor
        ban.setContentHuggingPriority(.required, for: .vertical)
        ban.setContentCompressionResistancePriority(.required, for: .vertical)

        let lock = LiquidLockBadgeView()
        lock.size = 20
        let text = makeLabel(
            "Item names, details, exact locations and Reveal in Finder are part of iClearer.",
            size: 13, weight: .regular, color: Theme.Colors.muted
        )
        text.maximumNumberOfLines = 1
        text.lineBreakMode = .byTruncatingTail
        text.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let unlock = NSButton(title: "Unlock", target: self, action: #selector(cleanUnlock))
        unlock.isBordered = false
        unlock.font = .systemFont(ofSize: 13, weight: .semibold)
        unlock.contentTintColor = Theme.Colors.accent
        unlock.translatesAutoresizingMaskIntoConstraints = false
        unlock.setContentHuggingPriority(.required, for: .horizontal)
        ban.addSubview(lock)
        ban.addSubview(text)
        ban.addSubview(unlock)
        NSLayoutConstraint.activate([
            ban.heightAnchor.constraint(equalToConstant: 46),
            lock.leadingAnchor.constraint(equalTo: ban.leadingAnchor, constant: 14),
            lock.centerYAnchor.constraint(equalTo: ban.centerYAnchor),
            lock.widthAnchor.constraint(equalToConstant: 20),
            lock.heightAnchor.constraint(equalToConstant: 20),
            text.leadingAnchor.constraint(equalTo: lock.trailingAnchor, constant: 12),
            text.centerYAnchor.constraint(equalTo: ban.centerYAnchor),
            text.trailingAnchor.constraint(lessThanOrEqualTo: unlock.leadingAnchor, constant: -12),
            unlock.trailingAnchor.constraint(equalTo: ban.trailingAnchor, constant: -16),
            unlock.centerYAnchor.constraint(equalTo: ban.centerYAnchor)
        ])
        return ban
    }

    private func makeAskFirstBanner() -> NSView {
        let ban = NSView()
        ban.wantsLayer = true
        ban.translatesAutoresizingMaskIntoConstraints = false
        ban.layer?.cornerRadius = 12
        ban.layer?.backgroundColor = Theme.Colors.askFill.cgColor
        ban.setContentHuggingPriority(.required, for: .vertical)

        let icon = NSImageView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        if let img = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil) {
            icon.image = img.withSymbolConfiguration(.init(pointSize: 14, weight: .semibold))
        }
        icon.contentTintColor = Theme.Colors.askText

        let text = makeLabel(
            TimeMachineProbe.askFirstWarningMessage(),
            size: 12.5, weight: .regular, color: Theme.Colors.askText
        )
        text.maximumNumberOfLines = 3
        text.lineBreakMode = .byWordWrapping
        askBannerLabel = text

        ban.addSubview(icon)
        ban.addSubview(text)
        NSLayoutConstraint.activate([
            ban.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            icon.leadingAnchor.constraint(equalTo: ban.leadingAnchor, constant: 14),
            icon.topAnchor.constraint(equalTo: ban.topAnchor, constant: 14),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),
            text.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            text.trailingAnchor.constraint(equalTo: ban.trailingAnchor, constant: -14),
            text.topAnchor.constraint(equalTo: ban.topAnchor, constant: 12),
            text.bottomAnchor.constraint(equalTo: ban.bottomAnchor, constant: -12)
        ])
        return ban
    }

    @objc private func cleanUnlock() { state.showSheet(.upgrade) }
    @objc private func selectSafeOnly() { state.selectSafeOnly(); reload() }
    @objc private func clearPicks() { state.clearPicks(); reload() }

    func refreshFromState() {
        reload()
    }

    private func reload() {
        inspector.isHidden = state.inspectorHidden
        inspector.reload(item: state.selectedItem, isPro: state.isPro)

        syncFilterChips()

        freeBanner.isHidden = state.isPro
        askBanner.isHidden = !state.hasAskFirstSelected
        if !askBanner.isHidden {
            askBannerLabel?.stringValue = TimeMachineProbe.askFirstWarningMessage()
        }
        bannersHost.isHidden = freeBanner.isHidden && askBanner.isHidden

        listStack.arrangedSubviews.forEach {
            listStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        let maxBytes = max(state.items.map(\.bytes).max() ?? 1, 1)
        let visible = state.visibleItems
        if visible.isEmpty {
            let empty = makeLabel(
                state.isScanning ? "Scanning…" : "No items match.",
                size: 13, weight: .regular, color: Theme.Colors.muted
            )
            listStack.addArrangedSubview(empty)
        } else {
            // Explicit group blocks: Everyday, then Builders.
            for group in [CleanGroup.everyday, CleanGroup.builders] {
                let groupItems = visible.filter { $0.group == group }
                guard !groupItems.isEmpty else { continue }
                let header = makeLabel(
                    group == .builders ? "BUILDERS" : "EVERYDAY",
                    size: 11, weight: .semibold, color: Theme.Colors.muted
                )
                header.setContentHuggingPriority(.defaultLow, for: .horizontal)
                listStack.addArrangedSubview(header)
                for item in groupItems {
                    let row = CleanRowView(
                        item: item,
                        checked: state.selected.contains(item.id),
                        isPro: state.isPro,
                        maxBytes: maxBytes,
                        onToggle: { [weak self] in self?.state.toggleSelection(item.id); self?.reload() },
                        onSelect: { [weak self] in self?.state.selectItem(item.id); self?.reload() }
                    )
                    listStack.addArrangedSubview(row)
                    row.widthAnchor.constraint(equalTo: listStack.widthAnchor).isActive = true
                }
            }
        }
    }

    @objc private func filterChip(_ sender: CleanFilterPill) {
        switch sender.tag {
        case 1: state.setFilter(.everyday)
        case 2: state.setFilter(.builders)
        default: state.setFilter(nil)
        }
        reload()
    }

    private func syncFilterChips() {
        let selectedTag: Int
        switch state.filterGroup {
        case .everyday: selectedTag = 1
        case .builders: selectedTag = 2
        case .none: selectedTag = 0
        }
        for chip in filterChips {
            chip.isSelected = chip.tag == selectedTag
        }
    }
}

/// Clean tab filter pill — All / Everyday / Builders.
final class CleanFilterPill: NSView {
    var target: AnyObject?
    var action: Selector?
    private let filterTag: Int
    private let titleLabel: NSTextField

    override var tag: Int { filterTag }

    var isSelected = false {
        didSet { applyChrome() }
    }

    init(title: String, tag: Int) {
        self.filterTag = tag
        self.titleLabel = NSTextField(labelWithString: title)
        super.init(frame: .zero)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(title)
        setAccessibilityIdentifier("clean-filter-\(title.lowercased())")

        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.drawsBackground = false
        titleLabel.font = .systemFont(ofSize: 12.5, weight: .medium)
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        let textWidth = ceil((title as NSString)
            .size(withAttributes: [.font: titleLabel.font as Any]).width)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: textWidth + 28),
            heightAnchor.constraint(equalToConstant: 30),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        applyChrome()
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyChrome()
    }

    private func applyChrome() {
        layer?.cornerRadius = 15
        if isSelected {
            layer?.backgroundColor = Theme.Colors.text.cgColor
            layer?.borderWidth = 0
            titleLabel.textColor = Theme.Colors.content
            titleLabel.font = .systemFont(ofSize: 12.5, weight: .semibold)
        } else {
            layer?.backgroundColor = Theme.Colors.contentAlt.cgColor
            layer?.borderWidth = 1
            layer?.borderColor = Theme.Colors.separator.cgColor
            titleLabel.textColor = Theme.Colors.text
            titleLabel.font = .systemFont(ofSize: 12.5, weight: .medium)
        }
    }

    override func mouseDown(with event: NSEvent) {
        if let action {
            NSApp.sendAction(action, to: target, from: self)
        }
    }
}

final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

/// Keeps short document views pinned to the top instead of vertically centered.
final class TopPinnedClipView: NSClipView {
    override var isFlipped: Bool { true }

    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var rect = super.constrainBoundsRect(proposedBounds)
        guard let doc = documentView else { return rect }
        if doc.frame.height <= bounds.height {
            rect.origin.y = 0
        }
        return rect
    }
}

final class CleanRowView: NSView, NSGestureRecognizerDelegate {
    private var onToggle: (() -> Void)?
    private var onSelect: (() -> Void)?
    private let check = NSButton(checkboxWithTitle: "", target: nil, action: nil)

    init(item: CacheItem, checked: Bool, isPro: Bool, maxBytes: Int64, onToggle: @escaping () -> Void, onSelect: @escaping () -> Void) {
        super.init(frame: .zero)
        self.onToggle = onToggle
        self.onSelect = onSelect
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.backgroundColor = Theme.Colors.contentAlt.cgColor
        if checked {
            layer?.borderWidth = 1
            layer?.borderColor = Theme.Colors.accent.withAlphaComponent(0.45).cgColor
        }

        check.target = self
        check.action = #selector(toggle)
        check.state = checked ? .on : .off
        check.translatesAutoresizingMaskIntoConstraints = false
        check.setContentHuggingPriority(.required, for: .horizontal)

        let badge = IconBadgeView()
        badge.screen = item.group == .builders ? .builders : .clean
        badge.setSymbol(SFSymbol.forScreen(badge.screen))
        badge.setBadgeSize(24)

        let name = makeLabel(item.displayName(isPro: isPro), size: 14, weight: .semibold, color: Theme.Colors.text)
        // List subtitle = “will it come back” blurb (paths live in the inspector).
        let path = makeLabel(
            isPro ? item.willComeBack : item.displayDetail(isPro: false),
            size: 12.5, weight: .regular, color: Theme.Colors.muted
        )
        let pill = PillLabel(text: item.safety.label, safe: item.safety == .safe)
        let size = makeLabel(item.formattedSize, size: 14, weight: .semibold, color: Theme.Colors.text, align: .right)
        let bar = ProgressTrack()
        let logMax = log(Double(max(maxBytes, 2)))
        let logVal = log(Double(max(item.bytes, 1)))
        bar.progress = CGFloat(max(0.12, min(1, logVal / logMax)))
        bar.usesQuotaGradient = true
        bar.translatesAutoresizingMaskIntoConstraints = false

        // Row click selects for the inspector only — must not steal checkbox mouse-downs
        // (default delaysPrimaryMouseButtonEvents blocked paid users from ticking items).
        let click = NSClickGestureRecognizer(target: self, action: #selector(selectRow))
        click.delaysPrimaryMouseButtonEvents = false
        click.delegate = self
        addGestureRecognizer(click)

        [check, badge, name, path, pill, size, bar].forEach { addSubview($0) }
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 64),
            check.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            check.centerYAnchor.constraint(equalTo: centerYAnchor),
            badge.leadingAnchor.constraint(equalTo: check.trailingAnchor, constant: 8),
            badge.centerYAnchor.constraint(equalTo: centerYAnchor),
            badge.widthAnchor.constraint(equalToConstant: 24),
            badge.heightAnchor.constraint(equalToConstant: 24),
            name.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 10),
            name.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            pill.leadingAnchor.constraint(equalTo: name.trailingAnchor, constant: 8),
            pill.centerYAnchor.constraint(equalTo: name.centerYAnchor),
            path.leadingAnchor.constraint(equalTo: name.leadingAnchor),
            path.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 3),
            path.trailingAnchor.constraint(lessThanOrEqualTo: size.leadingAnchor, constant: -10),
            size.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            size.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            size.widthAnchor.constraint(equalToConstant: 88),
            bar.trailingAnchor.constraint(equalTo: size.trailingAnchor),
            bar.topAnchor.constraint(equalTo: size.bottomAnchor, constant: 6),
            bar.widthAnchor.constraint(equalToConstant: 86),
            bar.heightAnchor.constraint(equalToConstant: 4)
        ])
    }

    required init?(coder: NSCoder) { nil }
    @objc private func toggle() { onToggle?() }
    @objc private func selectRow() { onSelect?() }

    func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer, shouldAttemptToRecognizeWith event: NSEvent) -> Bool {
        let point = convert(event.locationInWindow, from: nil)
        // Leave checkbox clicks to the button itself.
        return !check.frame.insetBy(dx: -6, dy: -6).contains(point)
    }
}

final class InspectorView: NSView {
    var onReveal: ((CacheItem) -> Void)?
    var onNever: ((CacheItem) -> Void)?
    var onUpgrade: (() -> Void)?
    private var item: CacheItem?

    func reload(item: CacheItem?, isPro: Bool) {
        self.item = item
        subviews.forEach { $0.removeFromSuperview() }
        wantsLayer = true
        layer?.cornerRadius = 0
        layer?.backgroundColor = Theme.Colors.contentAlt.cgColor
        layer?.borderWidth = 0
        // Left rule
        let rule = NSView()
        rule.wantsLayer = true
        rule.layer?.backgroundColor = Theme.Colors.separator.cgColor
        rule.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rule)
        NSLayoutConstraint.activate([
            rule.leadingAnchor.constraint(equalTo: leadingAnchor),
            rule.topAnchor.constraint(equalTo: topAnchor),
            rule.bottomAnchor.constraint(equalTo: bottomAnchor),
            rule.widthAnchor.constraint(equalToConstant: 1)
        ])

        guard let item else {
            let empty = makeLabel("Select an item", size: 13, weight: .regular, color: Theme.Colors.muted, align: .center)
            addSubview(empty)
            NSLayoutConstraint.activate([
                empty.centerXAnchor.constraint(equalTo: centerXAnchor),
                empty.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])
            return
        }

        let badge = IconBadgeView()
        badge.screen = item.group == .builders ? .builders : .clean
        badge.setSymbol(SFSymbol.forScreen(badge.screen))
        badge.setBadgeSize(40)
        let title = makeLabel(item.displayName(isPro: isPro), size: 18, weight: .semibold, color: Theme.Colors.text)
        let pill = PillLabel(text: item.safety.label, safe: item.safety == .safe)
        func section(_ text: String) -> NSTextField {
            let l = makeLabel(text.uppercased(), size: 11, weight: .semibold, color: Theme.Colors.muted)
            l.attributedStringValue = NSAttributedString(string: text.uppercased(), attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: Theme.Colors.muted,
                .kern: 0.08 * 11
            ])
            return l
        }
        let whatH = section("What it is")
        let whatBody: NSView = isPro
            ? makeMultilineLabel(item.detail, size: 13, weight: .regular, color: Theme.Colors.text)
            : makeInspectorLockBox("Item details are part of iClearer")
        let backH = section("Will it come back?")
        let back = makeMultilineLabel(item.willComeBack, size: 13, weight: .regular, color: Theme.Colors.text)
        let sizeH = section("Size")
        let size = makeLabel(item.formattedSize, size: 13, weight: .medium, color: Theme.Colors.text)
        let whereH = section("Where it lives")
        let whereBody: NSView
        if isPro {
            let whereL = makeMultilineLabel(item.path, size: 11, weight: .regular, color: Theme.Colors.text)
            whereL.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            whereBody = whereL
        } else {
            whereBody = makeInspectorLockBox("Locations are part of iClearer")
        }

        let stack = NSStackView(views: [badge, title, pill, whatH, whatBody, backH, back, sizeH, size, whereH, whereBody])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.setCustomSpacing(14, after: pill)
        stack.setCustomSpacing(14, after: whatBody)
        stack.setCustomSpacing(14, after: back)
        stack.setCustomSpacing(14, after: size)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        if isPro {
            let revealBtn = makeGhostButton("Reveal in Finder")
            revealBtn.compact = true
            revealBtn.target = self
            revealBtn.action = #selector(reveal)
            let neverBtn = makeGhostButton("Never touch")
            neverBtn.compact = true
            neverBtn.target = self
            neverBtn.action = #selector(neverTouch)
            let row = NSStackView(views: [revealBtn, neverBtn])
            row.orientation = .horizontal
            row.spacing = 8
            stack.addArrangedSubview(row)
        } else {
            let up = makeAccentButton("Unlock iClearer")
            up.target = self
            up.action = #selector(upgrade)
            stack.addArrangedSubview(up)
            up.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            badge.widthAnchor.constraint(equalToConstant: 40),
            badge.heightAnchor.constraint(equalToConstant: 40),
            whatBody.widthAnchor.constraint(equalTo: stack.widthAnchor),
            whereBody.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func makeInspectorLockBox(_ text: String) -> NSView {
        let box = CardView()
        box.kind = .content
        box.layer?.cornerRadius = 12
        let lock = LiquidLockBadgeView()
        lock.size = 22
        let label = makeLabel(text, size: 12.5, weight: .medium, color: Theme.Colors.text)
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 2
        box.addSubview(lock)
        box.addSubview(label)
        NSLayoutConstraint.activate([
            box.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            lock.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 10),
            lock.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            lock.widthAnchor.constraint(equalToConstant: 22),
            lock.heightAnchor.constraint(equalToConstant: 22),
            label.leadingAnchor.constraint(equalTo: lock.trailingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -10),
            label.centerYAnchor.constraint(equalTo: box.centerYAnchor)
        ])
        return box
    }

    @objc private func reveal() { if let item { onReveal?(item) } }
    @objc private func neverTouch() { if let item { onNever?(item) } }
    @objc private func upgrade() { onUpgrade?() }
}

// MARK: Storage Map

final class StorageMapScreen: NSView {
    private let state: AppState
    /// Defaults to Apps once real map data is ready.
    private var selectedIndex = 0
    private var didPickSelection = false

    init(state: AppState) {
        self.state = state
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        state.ensureStorageMap()
        rebuild()
    }

    required init?(coder: NSCoder) { nil }

    func refreshFromState() {
        rebuild()
    }

    private func rebuild() {
        subviews.forEach { $0.removeFromSuperview() }
        let slices = state.mapSlices()

        // Same pass as Overview scan — wait here until that combined scan finishes.
        let waitingForMap = state.storageMapSlices == nil
            && (state.isMeasuringStorageMap || state.isScanning)
        if waitingForMap {
            let message = state.isScanning
                ? (state.scanProgress.hint
                    ?? "Scanning your Mac… disk map is part of this progress.")
                : "Finishing disk map…"
            let label = makeLabel(
                message,
                size: 14, weight: .medium, color: Theme.Colors.muted, align: .center
            )
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: centerXAnchor),
                label.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])
            return
        }

        guard !slices.isEmpty else { return }
        if !didPickSelection, let ai = slices.firstIndex(where: { $0.name == "Apps" }) {
            selectedIndex = ai
        }
        selectedIndex = min(max(0, selectedIndex), slices.count - 1)
        let selected = slices[selectedIndex]

        let ring = RingChartView()
        ring.slices = slices.map { slice in
            // Inner ring is always full (incl. Free). Outer only where there are kids.
            let kids: [(CGFloat, NSColor)] = (slice.name == "Free")
                ? []
                : slice.children.map { (CGFloat($0.bytes), slice.color) }
            return RingChartView.Slice(
                weight: CGFloat(slice.bytes),
                color: slice.color,
                children: kids,
                leaveEmpty: false
            )
        }
        ring.centerTitle = AppFormat.mapSize(selected.bytes)
        ring.centerSubtitle = selected.name
        ring.highlightIndex = selectedIndex
        ring.showOuterDetail = true
        ring.translatesAutoresizingMaskIntoConstraints = false
        ring.setContentHuggingPriority(.required, for: .horizontal)
        ring.setContentCompressionResistancePriority(.required, for: .horizontal)

        // Prototype `.mp` / `.lg`: chart 400px, legend fills remaining; sizes use margin-left:auto.
        let legend = NSStackView()
        legend.orientation = .vertical
        legend.alignment = .leading
        legend.spacing = 2
        legend.translatesAutoresizingMaskIntoConstraints = false
        for (i, slice) in slices.enumerated() {
            let row = MapLegendRow(slice: slice, selected: i == selectedIndex, index: i)
            let click = NSClickGestureRecognizer(target: self, action: #selector(selectSlice(_:)))
            row.addGestureRecognizer(click)
            legend.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: legend.widthAnchor).isActive = true
        }

        let right = NSStackView(views: [legend])
        right.orientation = .vertical
        right.alignment = .leading
        right.spacing = 12
        right.translatesAutoresizingMaskIntoConstraints = false
        right.setContentHuggingPriority(.defaultLow, for: .horizontal)
        right.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        if !selected.children.isEmpty {
            if state.isPro {
                let drill = CardView()
                drill.kind = .contentAlt
                let title = makeLabel("Inside \(selected.name)", size: 14, weight: .semibold, color: Theme.Colors.text)
                title.setContentHuggingPriority(.defaultLow, for: .horizontal)
                let kids = NSStackView()
                kids.orientation = .vertical
                kids.alignment = .leading
                kids.spacing = 2
                kids.translatesAutoresizingMaskIntoConstraints = false
                kids.setContentHuggingPriority(.defaultLow, for: .horizontal)
                for child in selected.children {
                    let row = MapChildRow(name: child.name, bytes: child.bytes, color: selected.color)
                    kids.addArrangedSubview(row)
                    row.widthAnchor.constraint(equalTo: kids.widthAnchor).isActive = true
                }
                let stack = NSStackView(views: [title, kids])
                stack.orientation = .vertical
                stack.alignment = .leading
                stack.spacing = 8
                stack.translatesAutoresizingMaskIntoConstraints = false
                stack.setContentHuggingPriority(.defaultLow, for: .horizontal)
                drill.addSubview(stack)
                NSLayoutConstraint.activate([
                    stack.leadingAnchor.constraint(equalTo: drill.leadingAnchor, constant: 14),
                    stack.trailingAnchor.constraint(equalTo: drill.trailingAnchor, constant: -14),
                    stack.topAnchor.constraint(equalTo: drill.topAnchor, constant: 14),
                    stack.bottomAnchor.constraint(equalTo: drill.bottomAnchor, constant: -14),
                    kids.widthAnchor.constraint(equalTo: stack.widthAnchor),
                    stack.widthAnchor.constraint(equalTo: drill.widthAnchor, constant: -28)
                ])
                right.addArrangedSubview(drill)
                drill.widthAnchor.constraint(equalTo: right.widthAnchor).isActive = true
            } else {
                // Unlock strip — 66pt (~+50% on the previous 44pt).
                let drill = CardView()
                drill.kind = .contentAlt
                let lock = LiquidLockBadgeView()
                lock.size = 24
                let title = makeLabel("Drill-down is part of iClearer", size: 13, weight: .semibold, color: Theme.Colors.text)
                title.lineBreakMode = .byTruncatingTail
                title.maximumNumberOfLines = 1
                title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                let body = makeLabel("The free map shows the big picture only.", size: 11.5, weight: .regular, color: Theme.Colors.muted)
                body.lineBreakMode = .byTruncatingTail
                body.maximumNumberOfLines = 1
                body.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                let textCol = NSStackView(views: [title, body])
                textCol.orientation = .vertical
                textCol.alignment = .leading
                textCol.spacing = 1
                textCol.setContentHuggingPriority(.defaultLow, for: .horizontal)
                textCol.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                let unlock = PillButton(title: "Unlock", style: .primary)
                unlock.compact = true
                unlock.target = self
                unlock.action = #selector(upgrade)
                unlock.setContentHuggingPriority(.required, for: .horizontal)
                unlock.setContentCompressionResistancePriority(.required, for: .horizontal)
                drill.addSubview(lock)
                drill.addSubview(textCol)
                drill.addSubview(unlock)
                NSLayoutConstraint.activate([
                    drill.heightAnchor.constraint(equalToConstant: 66),
                    lock.leadingAnchor.constraint(equalTo: drill.leadingAnchor, constant: 12),
                    lock.centerYAnchor.constraint(equalTo: drill.centerYAnchor),
                    lock.widthAnchor.constraint(equalToConstant: 24),
                    lock.heightAnchor.constraint(equalToConstant: 24),
                    textCol.leadingAnchor.constraint(equalTo: lock.trailingAnchor, constant: 10),
                    textCol.centerYAnchor.constraint(equalTo: drill.centerYAnchor),
                    textCol.trailingAnchor.constraint(lessThanOrEqualTo: unlock.leadingAnchor, constant: -10),
                    unlock.leadingAnchor.constraint(greaterThanOrEqualTo: textCol.trailingAnchor, constant: 10),
                    unlock.trailingAnchor.constraint(equalTo: drill.trailingAnchor, constant: -12),
                    unlock.centerYAnchor.constraint(equalTo: drill.centerYAnchor),
                    unlock.widthAnchor.constraint(greaterThanOrEqualToConstant: 72)
                ])
                right.addArrangedSubview(drill)
                drill.widthAnchor.constraint(equalTo: right.widthAnchor).isActive = true
            }
        }

        // Chart left; legend fills remaining width (prototype grid 400px + 1fr).
        let wrap = NSStackView(views: [ring, right])
        wrap.orientation = .horizontal
        wrap.alignment = .centerY
        wrap.spacing = 24
        wrap.distribution = .fill
        wrap.translatesAutoresizingMaskIntoConstraints = false
        addSubview(wrap)

        NSLayoutConstraint.activate([
            wrap.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            wrap.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            wrap.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            wrap.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -12),
            ring.widthAnchor.constraint(equalToConstant: 400),
            ring.heightAnchor.constraint(equalToConstant: 400),
            right.widthAnchor.constraint(greaterThanOrEqualToConstant: 300)
        ])
    }

    @objc private func selectSlice(_ sender: NSClickGestureRecognizer) {
        guard let row = sender.view as? MapLegendRow else { return }
        didPickSelection = true
        selectedIndex = row.index
        rebuild()
    }

    @objc private func upgrade() { state.showSheet(.upgrade) }
}

private final class MapLegendRow: NSView {
    let index: Int

    init(slice: MapSlice, selected: Bool, index: Int) {
        self.index = index
        super.init(frame: .zero)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        layer?.cornerRadius = 10
        if selected {
            layer?.backgroundColor = Theme.Colors.contentAlt.cgColor
        }

        let swatch = NSView()
        swatch.wantsLayer = true
        swatch.layer?.backgroundColor = slice.color.cgColor
        swatch.layer?.cornerRadius = 4
        swatch.translatesAutoresizingMaskIntoConstraints = false
        let name = makeLabel(slice.name, size: 13.5, weight: .medium, color: Theme.Colors.text)
        name.lineBreakMode = .byTruncatingTail
        // Low hug so the name view can grow and push size to the trailing edge (margin-left:auto).
        name.setContentHuggingPriority(.defaultLow, for: .horizontal)
        name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let size = makeLabel(AppFormat.mapSize(slice.bytes), size: 13, weight: .regular, color: Theme.Colors.muted)
        size.alignment = .right
        size.lineBreakMode = .byClipping
        size.setContentHuggingPriority(.required, for: .horizontal)
        size.setContentCompressionResistancePriority(.required, for: .horizontal)
        addSubview(swatch)
        addSubview(name)
        addSubview(size)
        // Prototype `.lg span { margin-left: auto }` — size pinned trailing, name fills the middle.
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 34),
            swatch.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            swatch.centerYAnchor.constraint(equalTo: centerYAnchor),
            swatch.widthAnchor.constraint(equalToConstant: 11),
            swatch.heightAnchor.constraint(equalToConstant: 11),
            name.leadingAnchor.constraint(equalTo: swatch.trailingAnchor, constant: 10),
            name.centerYAnchor.constraint(equalTo: centerYAnchor),
            size.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            size.centerYAnchor.constraint(equalTo: centerYAnchor),
            name.trailingAnchor.constraint(lessThanOrEqualTo: size.leadingAnchor, constant: -12),
            size.leadingAnchor.constraint(greaterThanOrEqualTo: name.trailingAnchor, constant: 12),
            size.widthAnchor.constraint(greaterThanOrEqualToConstant: 52)
        ])
    }

    required init?(coder: NSCoder) { nil }
}

private final class MapChildRow: NSView {
    init(name: String, bytes: Int64, color: NSColor) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.defaultLow, for: .horizontal)

        let swatch = NSView()
        swatch.wantsLayer = true
        swatch.layer?.backgroundColor = color.cgColor
        swatch.layer?.cornerRadius = 4
        swatch.translatesAutoresizingMaskIntoConstraints = false

        let title = makeLabel(name, size: 13, weight: .medium, color: Theme.Colors.text)
        title.lineBreakMode = .byTruncatingTail
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        title.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let size = makeLabel(AppFormat.mapSize(bytes), size: 12.5, weight: .regular, color: Theme.Colors.muted)
        size.alignment = .right
        size.lineBreakMode = .byClipping
        size.setContentHuggingPriority(.required, for: .horizontal)
        size.setContentCompressionResistancePriority(.required, for: .horizontal)

        addSubview(swatch)
        addSubview(title)
        addSubview(size)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 30),
            swatch.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            swatch.centerYAnchor.constraint(equalTo: centerYAnchor),
            swatch.widthAnchor.constraint(equalToConstant: 10),
            swatch.heightAnchor.constraint(equalToConstant: 10),
            title.leadingAnchor.constraint(equalTo: swatch.trailingAnchor, constant: 10),
            title.centerYAnchor.constraint(equalTo: centerYAnchor),
            size.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            size.centerYAnchor.constraint(equalTo: centerYAnchor),
            title.trailingAnchor.constraint(lessThanOrEqualTo: size.leadingAnchor, constant: -10),
            size.widthAnchor.constraint(greaterThanOrEqualToConstant: 56),
            size.leadingAnchor.constraint(greaterThanOrEqualTo: title.trailingAnchor, constant: 10)
        ])
    }

    required init?(coder: NSCoder) { nil }
}

// MARK: Large files / Apps / Builders

final class LargeFilesScreen: NSView {
    private let state: AppState
    private var lastFingerprint = ""

    init(state: AppState) {
        self.state = state
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        lastFingerprint = fingerprint()
        rebuild()
        state.ensureLargeFiles()
    }

    required init?(coder: NSCoder) { nil }

    func refreshFromState() {
        let next = fingerprint()
        guard next != lastFingerprint else { return }
        lastFingerprint = next
        rebuild()
    }

    private func fingerprint() -> String {
        let ids = state.visibleLargeFiles().map(\.id.uuidString).joined(separator: ",")
        let sel = state.largeFileSelection.map(\.uuidString).sorted().joined(separator: ",")
        return "\(state.isPro)|\(state.searchQuery)|\(ids)|\(sel)|\(state.isScanning)|\(state.largeFiles.count)"
    }

    private func rebuild() {
        subviews.forEach { $0.removeFromSuperview() }

        // One top-aligned stack: compact banner, then rows (matches prototype locked UI).
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 4
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        if state.isPro {
            let mb = max(50, state.license.largeFileMinMB)
            let note = makeLabel(
                "Larger than \(mb) MB. Change this in Settings, Scanning.",
                size: 12.5, weight: .regular, color: Theme.Colors.muted
            )
            note.setContentHuggingPriority(.defaultLow, for: .horizontal)
            stack.addArrangedSubview(note)
            stack.setCustomSpacing(10, after: note)
        } else {
            let ban = makeLockedBanner()
            stack.addArrangedSubview(ban)
            stack.setCustomSpacing(8, after: ban)
            ban.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        let files = state.visibleLargeFiles()
        if files.isEmpty {
            let emptyTitle = state.isScanning || state.largeFiles.isEmpty
                ? (state.isScanning ? "Scanning…" : "Looking for large files…")
                : "Nothing here"
            let emptyHint = state.isScanning || state.largeFiles.isEmpty
                ? "Large files appear here when the scan finishes."
                : "No large files match. Try Rescan."
            let empty = makeLabel(emptyTitle, size: 15, weight: .semibold, color: Theme.Colors.text, align: .left)
            let hint = makeLabel(emptyHint, size: 12.5, weight: .regular, color: Theme.Colors.muted, align: .left)
            let box = NSStackView(views: [empty, hint])
            box.orientation = .vertical
            box.alignment = .leading
            box.spacing = 4
            box.edgeInsets = NSEdgeInsets(top: 18, left: 4, bottom: 18, right: 4)
            stack.addArrangedSubview(box)
        } else {
            for file in files {
                let row = LargeFileRowView(file: file, state: state)
                stack.addArrangedSubview(row)
                row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            }
        }

        let bottomPad = NSView()
        bottomPad.translatesAutoresizingMaskIntoConstraints = false
        bottomPad.heightAnchor.constraint(equalToConstant: state.isPro ? 88 : 20).isActive = true
        stack.addArrangedSubview(bottomPad)

        let doc = FlippedView()
        doc.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(stack)

        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.automaticallyAdjustsContentInsets = false
        let clip = TopPinnedClipView()
        clip.drawsBackground = false
        scroll.contentView = clip
        scroll.documentView = doc
        addSubview(scroll)

        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
            scroll.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: doc.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: doc.trailingAnchor),
            stack.topAnchor.constraint(equalTo: doc.topAnchor),
            stack.bottomAnchor.constraint(equalTo: doc.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor)
        ])
    }

    private func makeLockedBanner() -> NSView {
        // Prototype `.ban.n` — fixed-height strip (never expands into a full-page block).
        let ban = NSView()
        ban.wantsLayer = true
        ban.translatesAutoresizingMaskIntoConstraints = false
        ban.layer?.cornerRadius = 14
        ban.layer?.backgroundColor = Theme.Colors.contentAlt.cgColor

        let lock = LiquidLockBadgeView()
        lock.size = 18

        let text = makeLabel(
            "The free plan shows the size and kind of your top 5 large files. File names, locations and Quick Look are part of iClearer.",
            size: 12.5, weight: .regular, color: Theme.Colors.muted
        )
        text.maximumNumberOfLines = 2
        text.lineBreakMode = .byTruncatingTail
        text.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        text.setContentHuggingPriority(.defaultLow, for: .vertical)

        let unlock = NSButton(title: "Unlock", target: self, action: #selector(upgrade))
        unlock.isBordered = false
        unlock.font = .systemFont(ofSize: 12.5, weight: .semibold)
        unlock.contentTintColor = Theme.Colors.accent
        unlock.translatesAutoresizingMaskIntoConstraints = false
        unlock.setContentHuggingPriority(.required, for: .horizontal)
        unlock.setContentCompressionResistancePriority(.required, for: .horizontal)

        ban.addSubview(lock)
        ban.addSubview(text)
        ban.addSubview(unlock)

        let height = ban.heightAnchor.constraint(equalToConstant: 48)
        height.priority = .required
        NSLayoutConstraint.activate([
            height,
            lock.leadingAnchor.constraint(equalTo: ban.leadingAnchor, constant: 14),
            lock.centerYAnchor.constraint(equalTo: ban.centerYAnchor),
            lock.widthAnchor.constraint(equalToConstant: 18),
            lock.heightAnchor.constraint(equalToConstant: 18),
            text.leadingAnchor.constraint(equalTo: lock.trailingAnchor, constant: 10),
            text.centerYAnchor.constraint(equalTo: ban.centerYAnchor),
            text.trailingAnchor.constraint(equalTo: unlock.leadingAnchor, constant: -12),
            unlock.trailingAnchor.constraint(equalTo: ban.trailingAnchor, constant: -14),
            unlock.centerYAnchor.constraint(equalTo: ban.centerYAnchor)
        ])
        return ban
    }

    @objc private func upgrade() { state.showSheet(.upgrade) }
}

private final class LargeFileRowView: NSView {
    private let file: LargeFileItem
    private let state: AppState
    private let check = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private var tracking: NSTrackingArea?

    init(file: LargeFileItem, state: AppState) {
        self.file = file
        self.state = state
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 14
        build()
    }

    required init?(coder: NSCoder) { nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = Theme.Colors.contentAlt.cgColor
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    private func build() {
        let pro = state.isPro

        check.state = state.largeFileSelection.contains(file.id) ? .on : .off
        // Free plan: still clickable — opens Unlock instead of selecting.
        check.isEnabled = true
        check.alphaValue = pro ? 1 : 0.55
        check.target = self
        check.action = #selector(toggle)
        check.translatesAutoresizingMaskIntoConstraints = false

        let badge = IconBadgeView()
        badge.screen = .largeFiles
        badge.setSymbol(SFSymbol.forScreen(.largeFiles))
        badge.setBadgeSize(28)

        let title = makeLabel(
            pro ? file.name : file.kind,
            size: 14, weight: .semibold, color: Theme.Colors.text
        )
        title.lineBreakMode = .byTruncatingMiddle
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let meta: NSView
        if pro {
            meta = makeLabel(
                "Last opened \(file.ageLabel) ago · \(file.path)",
                size: 12.5, weight: .regular, color: Theme.Colors.muted
            )
        } else {
            let age = makeLabel(
                "Last opened \(file.ageLabel) ago · ",
                size: 12.5, weight: .regular, color: Theme.Colors.muted
            )
            let lock = LiquidLockBadgeView()
            lock.size = 14
            let locked = makeLabel(
                "Name and location locked",
                size: 12.5, weight: .regular, color: Theme.Colors.muted
            )
            let row = NSStackView(views: [age, lock, locked])
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 5
            row.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                lock.widthAnchor.constraint(equalToConstant: 14),
                lock.heightAnchor.constraint(equalToConstant: 14)
            ])
            meta = row
        }

        let left = NSStackView(views: [title, meta])
        left.orientation = .vertical
        left.alignment = .leading
        left.spacing = 2
        left.translatesAutoresizingMaskIntoConstraints = false
        left.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let ql = PillButton(title: "Quick Look", style: .ghost)
        ql.compact = true
        // Prototype uses the liquid lock badge when free; eye when unlocked.
        ql.symbolName = pro ? "eye" : nil
        ql.target = self
        ql.action = #selector(openQuickLook)
        ql.setContentHuggingPriority(.required, for: .horizontal)

        let size = makeLabel(
            AppFormat.bytes(file.bytes),
            size: 14, weight: .semibold, color: Theme.Colors.text, align: .right
        )
        size.setContentHuggingPriority(.required, for: .horizontal)

        addSubview(check)
        addSubview(badge)
        addSubview(left)
        addSubview(ql)
        addSubview(size)

        if pro {
            NSLayoutConstraint.activate([
                heightAnchor.constraint(equalToConstant: 58),
                check.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
                check.centerYAnchor.constraint(equalTo: centerYAnchor),
                badge.leadingAnchor.constraint(equalTo: check.trailingAnchor, constant: 8),
                badge.centerYAnchor.constraint(equalTo: centerYAnchor),
                badge.widthAnchor.constraint(equalToConstant: 28),
                badge.heightAnchor.constraint(equalToConstant: 28),
                left.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 12),
                left.centerYAnchor.constraint(equalTo: centerYAnchor),
                left.trailingAnchor.constraint(lessThanOrEqualTo: ql.leadingAnchor, constant: -12),
                ql.trailingAnchor.constraint(equalTo: size.leadingAnchor, constant: -14),
                ql.centerYAnchor.constraint(equalTo: centerYAnchor),
                size.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
                size.centerYAnchor.constraint(equalTo: centerYAnchor),
                size.widthAnchor.constraint(greaterThanOrEqualToConstant: 72)
            ])
        } else {
            let qlLock = LiquidLockBadgeView()
            qlLock.size = 14
            addSubview(qlLock)
            NSLayoutConstraint.activate([
                heightAnchor.constraint(equalToConstant: 58),
                check.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
                check.centerYAnchor.constraint(equalTo: centerYAnchor),
                badge.leadingAnchor.constraint(equalTo: check.trailingAnchor, constant: 8),
                badge.centerYAnchor.constraint(equalTo: centerYAnchor),
                badge.widthAnchor.constraint(equalToConstant: 28),
                badge.heightAnchor.constraint(equalToConstant: 28),
                left.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 12),
                left.centerYAnchor.constraint(equalTo: centerYAnchor),
                left.trailingAnchor.constraint(lessThanOrEqualTo: qlLock.leadingAnchor, constant: -10),
                qlLock.widthAnchor.constraint(equalToConstant: 14),
                qlLock.heightAnchor.constraint(equalToConstant: 14),
                qlLock.centerYAnchor.constraint(equalTo: centerYAnchor),
                qlLock.trailingAnchor.constraint(equalTo: ql.leadingAnchor, constant: -6),
                ql.trailingAnchor.constraint(equalTo: size.leadingAnchor, constant: -14),
                ql.centerYAnchor.constraint(equalTo: centerYAnchor),
                size.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
                size.centerYAnchor.constraint(equalTo: centerYAnchor),
                size.widthAnchor.constraint(greaterThanOrEqualToConstant: 72)
            ])
        }
    }

    @objc private func toggle() {
        if !state.isPro {
            check.state = .off
            state.showSheet(.upgrade, reason: "Selecting large files is part of iClearer.")
            return
        }
        state.toggleLargeFileSelection(file.id)
    }

    @objc private func openQuickLook() {
        if state.isPro {
            state.showQuickLook(file)
        } else {
            state.showSheet(.upgrade, reason: "Quick Look is part of iClearer.")
        }
    }
}

final class AppsScreen: NSView {
    private let state: AppState
    private var lastFingerprint = ""

    init(state: AppState) {
        self.state = state
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        lastFingerprint = fingerprint()
        rebuild()
        // Refresh when empty or when /Applications has apps the last scan dropped (e.g. symlinks).
        state.ensureApps(force: Self.appsListLooksIncomplete(state.apps))
    }

    required init?(coder: NSCoder) { nil }

    /// True if Finder’s Applications folder has an .app we aren’t showing yet.
    private static func appsListLooksIncomplete(_ apps: [AppLeftover]) -> Bool {
        if apps.isEmpty { return true }
        let shown = Set(apps.map { ($0.bundlePath as NSString).lastPathComponent })
        guard let kids = try? FileManager.default.contentsOfDirectory(atPath: "/Applications") else {
            return false
        }
        for name in kids where name.hasSuffix(".app") && name != "iClearer.app" {
            if !shown.contains(name) { return true }
        }
        return false
    }

    func refreshFromState() {
        let next = fingerprint()
        guard next != lastFingerprint else { return }
        lastFingerprint = next
        rebuild()
    }

    private func fingerprint() -> String {
        "\(state.isPro)|\(state.searchQuery)|\(state.apps.map(\.id.uuidString).joined())|\(state.isScanning)"
    }

    private func rebuild() {
        subviews.forEach { $0.removeFromSuperview() }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        let apps = state.visibleApps()
        if apps.isEmpty {
            let title = makeLabel(
                state.isScanning ? "Scanning…" : "Looking for apps…",
                size: 15, weight: .semibold, color: Theme.Colors.text
            )
            let hint = makeLabel(
                "Installed apps appear here when the scan finishes.",
                size: 12.5, weight: .regular, color: Theme.Colors.muted
            )
            let box = NSStackView(views: [title, hint])
            box.orientation = .vertical
            box.alignment = .leading
            box.spacing = 4
            box.edgeInsets = NSEdgeInsets(top: 12, left: 2, bottom: 12, right: 2)
            stack.addArrangedSubview(box)
        } else {
            for app in apps {
                let row = AppRowView(app: app, state: state)
                stack.addArrangedSubview(row)
                row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            }
        }

        let pad = NSView()
        pad.translatesAutoresizingMaskIntoConstraints = false
        pad.heightAnchor.constraint(equalToConstant: 20).isActive = true
        stack.addArrangedSubview(pad)

        let doc = FlippedView()
        doc.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(stack)

        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.automaticallyAdjustsContentInsets = false
        let clip = TopPinnedClipView()
        clip.drawsBackground = false
        scroll.contentView = clip
        scroll.documentView = doc
        addSubview(scroll)

        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
            scroll.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: doc.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: doc.trailingAnchor),
            stack.topAnchor.constraint(equalTo: doc.topAnchor),
            stack.bottomAnchor.constraint(equalTo: doc.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor)
        ])
    }

}

private final class AppRowView: NSView {
    private let app: AppLeftover
    private let state: AppState
    private var isUninstalling = false

    init(app: AppLeftover, state: AppState) {
        self.app = app
        self.state = state
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 14
        build()
    }

    required init?(coder: NSCoder) { nil }

    private func build() {
        let badge = NSImageView()
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.imageScaling = .scaleProportionallyUpOrDown
        badge.wantsLayer = true
        badge.layer?.cornerRadius = 8
        badge.layer?.masksToBounds = true
        if !app.bundlePath.isEmpty, FileManager.default.fileExists(atPath: app.bundlePath) {
            let icon = NSWorkspace.shared.icon(forFile: app.bundlePath)
            icon.size = NSSize(width: 34, height: 34)
            badge.image = icon
        } else if let fallback = NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil) {
            badge.image = fallback
            badge.contentTintColor = Theme.Colors.muted
        }

        let name = makeLabel(app.name, size: 14, weight: .semibold, color: Theme.Colors.text)

        let openedSuffix: String = {
            if app.lastUsed == "today" { return "opened today" }
            if app.lastUsed == "a while" { return "opened a while ago" }
            return "opened \(app.lastUsed) ago"
        }()

        let meta: NSView
        if state.isPro {
            meta = makeLabel(
                "\(AppFormat.bytes(app.appBytes)) app · \(AppFormat.bytes(app.leftoverBytes)) leftovers · \(openedSuffix)",
                size: 12.5, weight: .regular, color: Theme.Colors.muted
            )
        } else {
            let left = makeLabel(
                "\(AppFormat.bytes(app.appBytes)) app · ",
                size: 12.5, weight: .regular, color: Theme.Colors.muted
            )
            let lock = LiquidLockBadgeView()
            lock.size = 14
            let locked = makeLabel(
                "leftovers locked · \(openedSuffix)",
                size: 12.5, weight: .regular, color: Theme.Colors.muted
            )
            let rowMeta = NSStackView(views: [left, lock, locked])
            rowMeta.orientation = .horizontal
            rowMeta.alignment = .centerY
            rowMeta.spacing = 5
            rowMeta.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                lock.widthAnchor.constraint(equalToConstant: 14),
                lock.heightAnchor.constraint(equalToConstant: 14)
            ])
            meta = rowMeta
        }

        let inner = NSStackView(views: [name, meta])
        inner.orientation = .vertical
        inner.alignment = .leading
        inner.spacing = 2
        inner.translatesAutoresizingMaskIntoConstraints = false
        inner.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let size = makeLabel(
            AppFormat.bytes(state.isPro ? app.appBytes + app.leftoverBytes : app.appBytes),
            size: 14, weight: .semibold, color: Theme.Colors.text, align: .right
        )
        size.setContentHuggingPriority(.required, for: .horizontal)

        let action = PillButton(title: "Uninstall", style: .ghost)
        action.compact = true
        action.target = self
        action.action = #selector(requestUninstall)
        action.setContentHuggingPriority(.required, for: .horizontal)

        addSubview(badge)
        addSubview(inner)
        addSubview(size)
        addSubview(action)

        if state.isPro {
            NSLayoutConstraint.activate([
                heightAnchor.constraint(equalToConstant: 64),
                badge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
                badge.centerYAnchor.constraint(equalTo: centerYAnchor),
                badge.widthAnchor.constraint(equalToConstant: 34),
                badge.heightAnchor.constraint(equalToConstant: 34),
                inner.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 12),
                inner.centerYAnchor.constraint(equalTo: centerYAnchor),
                inner.trailingAnchor.constraint(lessThanOrEqualTo: size.leadingAnchor, constant: -10),
                size.trailingAnchor.constraint(equalTo: action.leadingAnchor, constant: -12),
                size.centerYAnchor.constraint(equalTo: centerYAnchor),
                size.widthAnchor.constraint(greaterThanOrEqualToConstant: 72),
                action.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
                action.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])
        } else {
            let qlLock = LiquidLockBadgeView()
            qlLock.size = 14
            addSubview(qlLock)
            NSLayoutConstraint.activate([
                heightAnchor.constraint(equalToConstant: 64),
                badge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
                badge.centerYAnchor.constraint(equalTo: centerYAnchor),
                badge.widthAnchor.constraint(equalToConstant: 34),
                badge.heightAnchor.constraint(equalToConstant: 34),
                inner.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 12),
                inner.centerYAnchor.constraint(equalTo: centerYAnchor),
                inner.trailingAnchor.constraint(lessThanOrEqualTo: size.leadingAnchor, constant: -10),
                size.trailingAnchor.constraint(equalTo: qlLock.leadingAnchor, constant: -10),
                size.centerYAnchor.constraint(equalTo: centerYAnchor),
                size.widthAnchor.constraint(greaterThanOrEqualToConstant: 72),
                qlLock.widthAnchor.constraint(equalToConstant: 14),
                qlLock.heightAnchor.constraint(equalToConstant: 14),
                qlLock.centerYAnchor.constraint(equalTo: centerYAnchor),
                qlLock.trailingAnchor.constraint(equalTo: action.leadingAnchor, constant: -6),
                action.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
                action.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])
        }
    }

    @objc private func requestUninstall() {
        guard !isUninstalling else { return }
        if !state.isPro {
            state.showSheet(.upgrade, reason: "App uninstaller is part of iClearer.")
            return
        }

        let alert = NSAlert()
        alert.messageText = "Uninstall \(app.name)?"
        alert.informativeText = "Moves \(app.name) to the Trash."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")
        guard let window = window else { return }
        // Sheet is snappier than a blocking app-modal alert.
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .alertFirstButtonReturn else { return }
            self.isUninstalling = true
            self.state.uninstallApp(self.app) { [weak self] freed, errorMessage in
                guard let self else { return }
                self.isUninstalling = false
                if freed > 0 {
                    self.state.showToast("\(self.app.name) moved to the Trash.", undo: false)
                } else if let errorMessage, !errorMessage.isEmpty {
                    self.state.showToast(errorMessage, undo: false)
                }
            }
        }
    }
}

final class BuildersScreen: NSView {
    private let state: AppState
    private var lastFingerprint = ""

    init(state: AppState) {
        self.state = state
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        lastFingerprint = fingerprint()
        rebuild()
    }

    required init?(coder: NSCoder) { nil }

    func refreshFromState() {
        let next = fingerprint()
        guard next != lastFingerprint else { return }
        lastFingerprint = next
        rebuild()
    }

    private func fingerprint() -> String {
        let rows = visibleBuilderItems().map { "\($0.id.uuidString):\($0.bytes)" }.joined()
        return "\(state.isPro)|\(state.isScanning)|\(rows)|\(state.searchQuery)"
    }

    /// Same rows as Clean → Builders — no empty Zero KB placeholders.
    private func visibleBuilderItems() -> [CacheItem] {
        var items = state.buildersItems()
        if !state.searchQuery.isEmpty {
            let q = state.searchQuery.lowercased()
            items = items.filter {
                $0.name.lowercased().contains(q)
                    || $0.genericName.lowercased().contains(q)
                    || $0.path.lowercased().contains(q)
            }
        }
        return items.sorted { $0.bytes > $1.bytes }
    }

    private func rebuild() {
        subviews.forEach { $0.removeFromSuperview() }

        let column = NSView()
        column.translatesAutoresizingMaskIntoConstraints = false

        let items = visibleBuilderItems()
        let gap: CGFloat = 14
        let tileH: CGFloat = 118
        let columnsPerRow = 3

        let grid = NSView()
        grid.translatesAutoresizingMaskIntoConstraints = false

        if items.isEmpty {
            let empty = makeLabel(
                state.isScanning ? "Scanning builders…" : "No builder leftovers found yet. Run Rescan.",
                size: 13, weight: .regular, color: Theme.Colors.muted
            )
            empty.translatesAutoresizingMaskIntoConstraints = false
            grid.addSubview(empty)
            NSLayoutConstraint.activate([
                empty.leadingAnchor.constraint(equalTo: grid.leadingAnchor),
                empty.trailingAnchor.constraint(lessThanOrEqualTo: grid.trailingAnchor),
                empty.topAnchor.constraint(equalTo: grid.topAnchor),
                empty.bottomAnchor.constraint(equalTo: grid.bottomAnchor)
            ])
        } else {
            let cards = items.map { makeTile(for: $0) }
            for card in cards { grid.addSubview(card) }

            var constraints: [NSLayoutConstraint] = []
            let rows = (items.count + columnsPerRow - 1) / columnsPerRow
            for (index, card) in cards.enumerated() {
                let row = index / columnsPerRow
                let col = index % columnsPerRow
                constraints.append(card.heightAnchor.constraint(equalToConstant: tileH))
                constraints.append(card.widthAnchor.constraint(
                    equalTo: grid.widthAnchor,
                    multiplier: 1.0 / CGFloat(columnsPerRow),
                    constant: -gap * CGFloat(columnsPerRow - 1) / CGFloat(columnsPerRow)
                ))
                if col == 0 {
                    constraints.append(card.leadingAnchor.constraint(equalTo: grid.leadingAnchor))
                } else {
                    constraints.append(card.leadingAnchor.constraint(
                        equalTo: cards[index - 1].trailingAnchor, constant: gap
                    ))
                }
                if row == 0 {
                    constraints.append(card.topAnchor.constraint(equalTo: grid.topAnchor))
                } else {
                    let above = cards[(row - 1) * columnsPerRow]
                    constraints.append(card.topAnchor.constraint(equalTo: above.bottomAnchor, constant: gap))
                }
                if row == rows - 1 {
                    constraints.append(card.bottomAnchor.constraint(lessThanOrEqualTo: grid.bottomAnchor))
                }
            }
            if let last = cards.last {
                constraints.append(last.bottomAnchor.constraint(equalTo: grid.bottomAnchor))
            }
            NSLayoutConstraint.activate(constraints)
        }

        let notice = makeLoginsCard()
        column.addSubview(grid)
        column.addSubview(notice)

        let doc = FlippedView()
        doc.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(column)

        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.automaticallyAdjustsContentInsets = false
        let clip = TopPinnedClipView()
        clip.drawsBackground = false
        scroll.contentView = clip
        scroll.documentView = doc
        addSubview(scroll)

        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
            scroll.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),

            column.leadingAnchor.constraint(equalTo: doc.leadingAnchor),
            column.trailingAnchor.constraint(equalTo: doc.trailingAnchor),
            column.topAnchor.constraint(equalTo: doc.topAnchor),
            column.bottomAnchor.constraint(equalTo: doc.bottomAnchor),
            column.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),

            grid.leadingAnchor.constraint(equalTo: column.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: column.trailingAnchor),
            grid.topAnchor.constraint(equalTo: column.topAnchor),

            notice.leadingAnchor.constraint(equalTo: column.leadingAnchor),
            notice.trailingAnchor.constraint(equalTo: column.trailingAnchor),
            notice.topAnchor.constraint(equalTo: grid.bottomAnchor, constant: gap),
            notice.bottomAnchor.constraint(equalTo: column.bottomAnchor)
        ])
    }

    private func makeTile(for item: CacheItem) -> NSView {
        let card = CardView()
        card.kind = .contentAlt
        card.translatesAutoresizingMaskIntoConstraints = false
        card.setContentHuggingPriority(.defaultLow, for: .horizontal)
        card.setContentCompressionResistancePriority(.fittingSizeCompression, for: .horizontal)

        let badge = IconBadgeView()
        badge.screen = .builders
        badge.setSymbol(SFSymbol.forScreen(.builders))
        badge.setBadgeSize(30)

        let sizeText = AppFormat.bytes(item.bytes)
        let size = makeLabel(sizeText, size: 21, weight: .bold, color: Theme.Colors.text)
        size.attributedStringValue = NSAttributedString(string: sizeText, attributes: [
            .font: NSFont.systemFont(ofSize: 21, weight: .bold),
            .foregroundColor: Theme.Colors.text,
            .kern: -0.03 * 21
        ])
        size.lineBreakMode = .byTruncatingTail
        size.setContentCompressionResistancePriority(.fittingSizeCompression, for: .horizontal)

        let captionText: String
        if state.isPro {
            captionText = item.name
        } else if let bucket = BuilderBucket.classify(item) {
            captionText = "\(bucket.freeKind) · scan only"
        } else {
            captionText = "\(shortFreeKind(for: item)) · scan only"
        }
        let caption = makeLabel(captionText, size: 12.5, weight: .regular, color: Theme.Colors.muted)
        caption.lineBreakMode = .byTruncatingTail
        caption.setContentCompressionResistancePriority(.fittingSizeCompression, for: .horizontal)

        let stack = NSStackView(views: [badge, size, caption])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.setCustomSpacing(10, after: badge)
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: 30),
            badge.heightAnchor.constraint(equalToConstant: 30),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16)
        ])

        let click = NSClickGestureRecognizer(target: self, action: #selector(openBuildersClean))
        card.addGestureRecognizer(click)
        return card
    }

    private func shortFreeKind(for item: CacheItem) -> String {
        let g = item.genericName.lowercased()
        if g.contains("package") { return "Package manager" }
        if g.contains("build") || g.contains("simulator") { return "Build tool" }
        if g.contains("container") || g.contains("docker") { return "Container tool" }
        if g.contains("ai") || g.contains("model") { return "AI tool" }
        if g.contains("python") || g.contains("runtime") { return "Language runtime" }
        return "Developer tool"
    }

    private func makeLoginsCard() -> NSView {
        let card = NSView()
        card.wantsLayer = true
        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer?.cornerRadius = 20
        card.layer?.backgroundColor = Theme.Colors.contentAlt.cgColor

        let title = makeLabel("Logins stay blocked", size: 14, weight: .semibold, color: Theme.Colors.text)
        let body = makeLabel(
            "iClearer never touches tokens, SSH keys, .env files or your git folders.",
            size: 12.5, weight: .regular, color: Theme.Colors.muted
        )
        body.maximumNumberOfLines = 2
        body.lineBreakMode = .byWordWrapping

        let stack = NSStackView(views: [title, body])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        return card
    }

    @objc private func openBuildersClean() {
        state.navigate(.clean)
        state.setFilter(.builders)
    }
}


// MARK: History / Coming soon

final class HistoryScreen: NSView {
    private let state: AppState
    private var lastFingerprint = ""

    init(state: AppState) {
        self.state = state
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        lastFingerprint = fingerprint()
        rebuild()
    }

    required init?(coder: NSCoder) { nil }

    func refreshFromState() {
        let next = fingerprint()
        guard next != lastFingerprint else { return }
        lastFingerprint = next
        rebuild()
    }

    private func fingerprint() -> String {
        let rows = state.history.map { "\($0.id.uuidString):\($0.restored):\($0.bytes)" }.joined()
        return "\(state.isPro)|\(rows)"
    }

    private func rebuild() {
        subviews.forEach { $0.removeFromSuperview() }

        // Free plan: locked upsell (prototype hsl) — Undo toast still works after cleanup.
        if !state.isPro {
            buildLockedUpsell()
            return
        }

        if state.history.isEmpty {
            let title = makeLabel("No cleanups yet", size: 18, weight: .semibold, color: Theme.Colors.text, align: .center)
            let body = makeLabel(
                "When you clean, uninstall, or move large files to the Trash, it appears here.",
                size: 13, weight: .regular, color: Theme.Colors.muted, align: .center
            )
            body.maximumNumberOfLines = 3
            body.lineBreakMode = .byWordWrapping
            let stack = NSStackView(views: [title, body])
            stack.orientation = .vertical
            stack.alignment = .centerX
            stack.spacing = 8
            stack.translatesAutoresizingMaskIntoConstraints = false
            addSubview(stack)
            NSLayoutConstraint.activate([
                stack.centerXAnchor.constraint(equalTo: centerXAnchor),
                stack.centerYAnchor.constraint(equalTo: centerYAnchor),
                body.widthAnchor.constraint(lessThanOrEqualToConstant: 360)
            ])
            return
        }

        let column = NSStackView()
        column.orientation = .vertical
        column.spacing = 8
        column.translatesAutoresizingMaskIntoConstraints = false

        for entry in state.history {
            column.addArrangedSubview(makeRow(entry))
        }

        let doc = FlippedView()
        doc.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(column)

        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.automaticallyAdjustsContentInsets = false
        let clip = TopPinnedClipView()
        clip.drawsBackground = false
        scroll.contentView = clip
        scroll.documentView = doc
        addSubview(scroll)

        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
            scroll.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),

            column.leadingAnchor.constraint(equalTo: doc.leadingAnchor),
            column.trailingAnchor.constraint(equalTo: doc.trailingAnchor),
            column.topAnchor.constraint(equalTo: doc.topAnchor),
            column.bottomAnchor.constraint(equalTo: doc.bottomAnchor),
            column.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor)
        ])
    }

    private func buildLockedUpsell() {
        // Prototype hsl hero: blue radial orb + white clock hands (not the sidebar SF Symbol).
        let icon = HistoryClockIconView()
        icon.diameter = 110

        let title = makeLabel("History with restore", size: 20, weight: .semibold, color: Theme.Colors.text, align: .center)
        let body = makeLabel(
            "See every cleanup and put anything back with one click. You can still undo your last cleanup for free.",
            size: 13.5, weight: .regular, color: Theme.Colors.muted, align: .center
        )
        body.maximumNumberOfLines = 4
        body.lineBreakMode = .byWordWrapping

        let unlock = PillButton(title: "Unlock iClearer", style: .primary)
        unlock.target = self
        unlock.action = #selector(unlockTap)

        let stack = NSStackView(views: [icon, title, body, unlock])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.setCustomSpacing(16, after: body)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -12),
            body.widthAnchor.constraint(lessThanOrEqualToConstant: 360),
            icon.widthAnchor.constraint(equalToConstant: 110),
            icon.heightAnchor.constraint(equalToConstant: 110)
        ])
    }

    private func makeRow(_ entry: HistoryEntry) -> NSView {
        let row = CardView()
        row.kind = .contentAlt
        row.translatesAutoresizingMaskIntoConstraints = false

        let badge = IconBadgeView()
        badge.screen = .history
        badge.setSymbol(SFSymbol.forScreen(.history))
        badge.setBadgeSize(34)

        let date = makeLabel(entry.formattedDate, size: 14, weight: .semibold, color: Theme.Colors.text)
        let summary = makeLabel(entry.summary, size: 12.5, weight: .regular, color: Theme.Colors.muted)
        summary.lineBreakMode = .byTruncatingTail
        let left = NSStackView(views: [date, summary])
        left.orientation = .vertical
        left.alignment = .leading
        left.spacing = 2
        left.translatesAutoresizingMaskIntoConstraints = false

        let size = makeLabel(AppFormat.bytes(entry.bytes), size: 13, weight: .semibold, color: Theme.Colors.text)

        let action: NSView
        if entry.restored {
            let done = makeLabel("Restored", size: 12.5, weight: .semibold, color: Theme.Colors.muted)
            action = done
        } else {
            let restore = PillButton(title: "Restore", style: .ghost)
            restore.compact = true
            restore.target = self
            restore.action = #selector(restoreTap(_:))
            restore.identifier = NSUserInterfaceItemIdentifier(entry.id.uuidString)
            action = restore
        }

        row.addSubview(badge)
        row.addSubview(left)
        row.addSubview(size)
        row.addSubview(action)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 64),
            badge.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            badge.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            badge.widthAnchor.constraint(equalToConstant: 34),
            badge.heightAnchor.constraint(equalToConstant: 34),

            left.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 12),
            left.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            left.trailingAnchor.constraint(lessThanOrEqualTo: size.leadingAnchor, constant: -12),

            action.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
            action.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            size.trailingAnchor.constraint(equalTo: action.leadingAnchor, constant: -12),
            size.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])
        return row
    }

    @objc private func unlockTap() {
        state.showSheet(.upgrade, reason: "History with restore is part of iClearer.")
    }

    @objc private func restoreTap(_ sender: Any?) {
        let idString: String?
        if let button = sender as? PillButton {
            idString = button.identifier?.rawValue
        } else if let control = sender as? NSControl {
            idString = control.identifier?.rawValue
        } else {
            idString = nil
        }
        guard let raw = idString, let id = UUID(uuidString: raw) else { return }
        state.restoreHistoryEntry(id)
    }
}


final class ComingSoonScreen: NSView {
    init(screen: AppScreen, state: AppState) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let badge = IconBadgeView()
        badge.screen = screen
        badge.setSymbol(SFSymbol.forScreen(screen))
        let title = makeLabel("\(screen.title) · Coming in 1.1", size: 20, weight: .bold, color: Theme.ink, align: .center)
        let body = makeMultilineLabel(screen.subtitle, size: 13, weight: .regular, color: Theme.muted)
        body.alignment = .center
        let button = makeAccentButton("What’s new in 1.1")
        button.target = self
        button.action = #selector(showNote)
        let stack = NSStackView(views: [badge, title, body, button])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            body.widthAnchor.constraint(lessThanOrEqualToConstant: 360),
            badge.widthAnchor.constraint(equalToConstant: 40),
            badge.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    required init?(coder: NSCoder) { nil }

    @objc private func showNote() {
        let alert = NSAlert()
        alert.messageText = "What’s new in 1.1"
        alert.informativeText = "• Duplicate files finder\n• Menu bar monitor with low-space alerts\n• Scheduled scans\n• Maintenance tasks"
        alert.runModal()
    }
}

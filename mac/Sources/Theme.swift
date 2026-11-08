import AppKit

// MARK: - Theme

enum Theme {
    // Brand (static brand palette)
    static let clearBlue = NSColor(hex: 0x3B7CB0)
    static let sky = NSColor(hex: 0x7FB8E6)
    static let glass = NSColor(hex: 0xDCE8F2)
    // Deep Night — darker than prototype #1a2027 so the panel doesn’t read washed.
    static let night = NSColor(hex: 0x0E1318)
    static let safeGreen = NSColor(hex: 0x3FA877)
    static let amber = NSColor(hex: 0xF2B34D)
    static let mist = NSColor(hex: 0xF5F7FA)

    /// Dynamic light/dark colors from design-tokens.json (appLight / appDark).
    enum Colors {
        static let text = dynamic(light: 0x14202B, dark: 0xF2F5F8)
        static let muted = dynamic(light: 0x667585, dark: 0x9AA8B6)
        static let separator = dynamic(
            light: NSColor(calibratedRed: 20 / 255, green: 40 / 255, blue: 60 / 255, alpha: 0.10),
            dark: NSColor(calibratedWhite: 1, alpha: 0.10)
        )
        // Darker Night panel + slightly lifted cards so tiles still separate.
        static let content = dynamic(light: 0xFFFFFF, dark: 0x0E1318)
        static let contentAlt = dynamic(light: 0xF2F5F9, dark: 0x182028)
        // Prototype accent `--ac:#7fb8e6` (See plans, primary CTAs).
        static let accent = dynamic(light: 0x2F6FA6, dark: 0x7FB8E6)
        static let onAccent = dynamic(light: 0xFFFFFF, dark: 0x06131F)
        static let safeText = dynamic(light: 0x1F8A5B, dark: 0x6FD0A2)
        static let safeFill = dynamic(
            light: NSColor(hex: 0x3FA877, alpha: 0.16),
            dark: NSColor(hex: 0x6FD0A2, alpha: 0.16)
        )
        static let askText = dynamic(light: 0xA35A00, dark: 0xF2B34D)
        static let askFill = dynamic(
            light: NSColor(hex: 0xF2B34D, alpha: 0.24),
            dark: NSColor(hex: 0xF2B34D, alpha: 0.20)
        )
        static let overlay = dynamic(
            light: NSColor(calibratedWhite: 1, alpha: 0.35),
            dark: NSColor(calibratedWhite: 0, alpha: 0.35)
        )
        static let navSelected = dynamic(
            light: NSColor(calibratedRed: 120 / 255, green: 150 / 255, blue: 180 / 255, alpha: 0.28),
            dark: NSColor(calibratedWhite: 1, alpha: 0.14)
        )
        static let insetHighlight = NSColor(calibratedWhite: 1, alpha: 0.45)
        static let softShadow = NSColor(calibratedWhite: 0, alpha: 0.22)

        private static func dynamic(light: UInt32, dark: UInt32) -> NSColor {
            dynamic(light: NSColor(hex: light), dark: NSColor(hex: dark))
        }

        private static func dynamic(light: NSColor, dark: NSColor) -> NSColor {
            NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            }
        }
    }

    // Backward-compatible aliases used across the app
    static var ink: NSColor { Colors.text }
    static var muted: NSColor { Colors.muted }
    static var accent: NSColor { Colors.accent }
    static var accentOn: NSColor { Colors.onAccent }
    static var contentAlt: NSColor { Colors.contentAlt }
    static var content: NSColor { Colors.content }
    static var separator: NSColor { Colors.separator }
    static var safeFill: NSColor { Colors.safeFill }
    static var askFill: NSColor { Colors.askFill }
    static var safeText: NSColor { Colors.safeText }
    static var askText: NSColor { Colors.askText }

    // Storage Map / Your disk — brighter palette matching the handoff ref.
    static let mapApps = NSColor(hex: 0x5E63E0)
    static let mapDeveloper = NSColor(hex: 0x4A5D78)
    static let mapPhotos = NSColor(hex: 0x34C759)
    static let mapDocuments = NSColor(hex: 0xFF9F0A)
    static let mapSystem = NSColor(hex: 0x8E99A4)
    static let mapICloud = NSColor(hex: 0x0A84FF)
    static let mapOther = NSColor(hex: 0xB8C0C8)
    static let mapFree = NSColor(hex: 0xC2CCD6)
    /// Dark cut / track between bar segments (reads as a clean gap).
    static let mapCut = NSColor(hex: 0x0E1318)

    static func sectionGradient(_ screen: AppScreen) -> (NSColor, NSColor) {
        switch screen {
        case .overview: return (NSColor(hex: 0x5FA6DA), NSColor(hex: 0x2D6DA4))
        case .clean: return (NSColor(hex: 0x7FCBE6), NSColor(hex: 0x2F95C4))
        case .storageMap: return (NSColor(hex: 0x58C193), NSColor(hex: 0x2A8F63))
        case .largeFiles: return (NSColor(hex: 0xF6C36B), NSColor(hex: 0xD9902B))
        case .apps: return (NSColor(hex: 0x8AA0C4), NSColor(hex: 0x556E99))
        case .builders: return (NSColor(hex: 0x6B8197), NSColor(hex: 0x34465A))
        case .history: return (NSColor(hex: 0x5FD0C8), NSColor(hex: 0x2A8F8F))
        case .duplicates: return (NSColor(hex: 0xF3A6C8), NSColor(hex: 0xC9578F))
        case .maintenance: return (NSColor(hex: 0xB4BCC6), NSColor(hex: 0x6F7B88))
        }
    }

    static func applyContentPanelStyle(to view: NSView) {
        view.wantsLayer = true
        view.layer?.cornerRadius = 20
        view.layer?.masksToBounds = false
        // Use static Night so vibrancy / appearance can’t wash the panel lighter.
        view.layer?.backgroundColor = Theme.night.cgColor
        view.layer?.borderWidth = 0.5
        view.layer?.borderColor = Colors.separator.cgColor
        view.layer?.shadowColor = NSColor.black.cgColor
        view.layer?.shadowOpacity = 0.28
        view.layer?.shadowRadius = 18
        view.layer?.shadowOffset = CGSize(width: 0, height: -4)
    }

    static func refreshAppearance(in view: NSView) {
        view.needsDisplay = true
        for sub in view.subviews {
            refreshAppearance(in: sub)
        }
    }
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8) & 0xFF) / 255
        let b = CGFloat(hex & 0xFF) / 255
        self.init(calibratedRed: r, green: g, blue: b, alpha: alpha)
    }
}

// MARK: - Labels

func makeLabel(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, align: NSTextAlignment = .left) -> NSTextField {
    let field = NSTextField(labelWithString: text)
    field.font = .systemFont(ofSize: size, weight: weight)
    field.textColor = color
    field.alignment = align
    field.lineBreakMode = .byTruncatingTail
    field.drawsBackground = false
    field.isBezeled = false
    field.translatesAutoresizingMaskIntoConstraints = false
    return field
}

func makeMultilineLabel(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSTextField {
    let field = makeLabel(text, size: size, weight: weight, color: color)
    field.maximumNumberOfLines = 0
    field.lineBreakMode = .byWordWrapping
    field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    return field
}

func makeAccentButton(_ title: String) -> PillButton {
    PillButton(title: title, style: .primary)
}

func makeGhostButton(_ title: String) -> PillButton {
    PillButton(title: title, style: .ghost)
}

// MARK: - GlassEffectView

final class GlassEffectView: NSVisualEffectView {
    enum Kind {
        case windowShell
        case sidebar
        case floating
    }

    init(kind: Kind) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        blendingMode = .behindWindow
        state = .followsWindowActiveState
        wantsLayer = true
        switch kind {
        case .windowShell:
            // Let desktop wallpaper show through like the prototype glass shell.
            material = .fullScreenUI
            appearance = NSAppearance(named: .darkAqua)
        case .sidebar:
            material = .sidebar
            appearance = NSAppearance(named: .darkAqua)
        case .floating:
            material = .hudWindow
            blendingMode = .withinWindow
        }
    }

    required init?(coder: NSCoder) { nil }
}

// MARK: - PillButton

final class PillButton: NSControl {
    enum Style {
        case primary
        case ghost
        case soft // white/soft CTA (hero Soft Safe)
        case onDarkGhost // translucent white on blue hero
    }

    var style: Style = .primary {
        didSet { updateLabel(); applyLayer(); needsDisplay = true }
    }

    var compact = false {
        didSet {
            updateCompactPadding()
            invalidateIntrinsicContentSize()
            needsDisplay = true
        }
    }

    /// Scales compact/regular height (e.g. 1.3 in Settings → Account / Protected).
    var heightMultiplier: CGFloat = 1 {
        didSet {
            updateCompactPadding()
            invalidateIntrinsicContentSize()
            needsDisplay = true
        }
    }

    private let titleLabel = NSTextField(labelWithString: "")
    private let iconView = NSImageView()
    private var tracking = false
    private var hovering = false

    convenience init(title: String, style: Style = .primary) {
        self.init(frame: .zero)
        self.style = style
        self.title = title
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        focusRingType = .none
        translatesAutoresizingMaskIntoConstraints = false

        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.drawsBackground = false
        titleLabel.alignment = .center
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.isHidden = true

        addSubview(iconView)
        addSubview(titleLabel)

        titleCenterX = titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor)
        titleLeadingPlain = titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 16)
        titleTrailingPlain = titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16)
        titleLeadingWithIcon = titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6)
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 13),
            iconView.heightAnchor.constraint(equalToConstant: 13),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleTrailingPlain,
            titleCenterX,
            titleLeadingPlain
        ])
        updateLabel()
        updateIconLayout()
        updateCompactPadding()
    }

    private var titleCenterX: NSLayoutConstraint!
    private var titleLeadingPlain: NSLayoutConstraint!
    private var titleTrailingPlain: NSLayoutConstraint!
    private var titleLeadingWithIcon: NSLayoutConstraint!

    private func updateIconLayout() {
        let hasIcon = !iconView.isHidden
        titleCenterX.isActive = !hasIcon
        titleLeadingPlain.isActive = !hasIcon
        titleLeadingWithIcon.isActive = hasIcon
        needsLayout = true
        invalidateIntrinsicContentSize()
    }

    required init?(coder: NSCoder) { nil }

    var title: String {
        get { titleLabel.stringValue }
        set {
            titleLabel.stringValue = newValue
            updateLabel()
            invalidateIntrinsicContentSize()
        }
    }

    var symbolName: String? {
        didSet {
            if let symbolName, let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
                let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
                iconView.image = image.withSymbolConfiguration(config)
                iconView.isHidden = false
            } else {
                iconView.isHidden = true
            }
            updateIconLayout()
        }
    }

    override var isEnabled: Bool {
        didSet { alphaValue = isEnabled ? 1 : 0.4; needsDisplay = true }
    }

    private func updateCompactPadding() {
        let pad: CGFloat = (compact ? 12 : 16) * max(1, heightMultiplier)
        titleLeadingPlain.constant = pad
        titleTrailingPlain.constant = -pad
    }

    override var intrinsicContentSize: NSSize {
        // Keep padding in sync with titleLeading/Trailing so compact never clips (“Unloc”).
        let m = max(1, heightMultiplier)
        let padH: CGFloat = (compact ? 12 : 16) * m
        let padV: CGFloat = (compact ? 6 : 9) * m
        let fontSize: CGFloat = (compact ? 12 : 13) * min(m, 1.15)
        let font = titleLabel.font ?? .systemFont(ofSize: fontSize, weight: .semibold)
        let textW = (title as NSString).size(withAttributes: [.font: font]).width
        let iconExtra: CGFloat = iconView.isHidden ? 0 : 18
        let textH: CGFloat = (compact ? 12.5 : 13) * m
        return NSSize(width: ceil(textW) + padH * 2 + iconExtra + 2, height: textH + padV * 2)
    }

    override func layout() {
        super.layout()
        applyLayer()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyLayer()
        updateLabel()
    }

    private func updateLabel() {
        switch style {
        case .primary:
            // Dark ink on #7FB8E6 (prototype --acf)
            titleLabel.textColor = NSColor(hex: 0x06131F)
            titleLabel.font = .systemFont(ofSize: compact ? 12 : 13, weight: .semibold)
            iconView.contentTintColor = NSColor(hex: 0x06131F)
        case .ghost:
            titleLabel.textColor = Theme.Colors.text
            titleLabel.font = .systemFont(ofSize: compact ? 12 : 13, weight: .semibold)
            iconView.contentTintColor = Theme.Colors.text
        case .soft:
            // Hero “Clean Safe items” / white CTAs — dark ink on white.
            titleLabel.textColor = NSColor(hex: 0x14202B)
            titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
            iconView.contentTintColor = NSColor(hex: 0x14202B)
        case .onDarkGhost:
            // White label on frosted glass — attributed + no vibrancy so AppKit can’t force dark ink.
            titleLabel.isHidden = false
            titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
            titleLabel.textColor = .white
            titleLabel.attributedStringValue = NSAttributedString(string: title, attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: NSColor.white
            ])
            iconView.contentTintColor = .white
        }
    }

    override var allowsVibrancy: Bool { style == .onDarkGhost ? false : super.allowsVibrancy }

    private func fillColor() -> NSColor {
        switch style {
        case .primary: return Theme.sky // #7FB8E6
        case .ghost: return Theme.Colors.contentAlt
        case .soft: return .white
        // Prototype .hero .btn.g — rgba(255,255,255,.2); stripe visible through.
        case .onDarkGhost: return NSColor.white.withAlphaComponent(0.20)
        }
    }

    private func borderColor() -> NSColor? {
        switch style {
        case .ghost: return Theme.Colors.separator
        case .onDarkGhost: return NSColor.white.withAlphaComponent(0.28)
        case .primary, .soft: return nil
        }
    }

    private func applyLayer() {
        layer?.cornerRadius = 999
        layer?.masksToBounds = false
        // Keep layer clear — fill is painted in draw(_:) so it isn't wiped by redraw.
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.borderWidth = 0
        switch style {
        case .primary:
            layer?.shadowColor = Theme.sky.cgColor
            layer?.shadowOpacity = 0.55
            layer?.shadowRadius = 14
            layer?.shadowOffset = CGSize(width: 0, height: -3)
        case .soft:
            layer?.shadowColor = NSColor.black.cgColor
            layer?.shadowOpacity = 0.35
            layer?.shadowRadius = 12
            layer?.shadowOffset = CGSize(width: 0, height: -6)
        case .ghost, .onDarkGhost:
            layer?.shadowOpacity = 0
        }
        layer?.opacity = (hovering && isEnabled) ? 0.92 : 1
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: bounds.height / 2, yRadius: bounds.height / 2)
        if style == .onDarkGhost {
            // Frosted glass fill only — title is the white NSTextField above.
            NSColor.white.withAlphaComponent(0.18).setFill()
            path.fill()
            NSColor.white.withAlphaComponent(0.35).setStroke()
            path.lineWidth = 1
            path.stroke()
            return
        }
        fillColor().setFill()
        path.fill()
        if let border = borderColor() {
            border.setStroke()
            path.lineWidth = 1
            path.stroke()
        }
        if style == .primary || style == .soft {
            let highlight = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: bounds.height / 2, yRadius: bounds.height / 2)
            NSColor.white.withAlphaComponent(style == .primary ? 0.28 : 0.55).setStroke()
            highlight.lineWidth = 0.8
            let clip = NSBezierPath(rect: NSRect(x: 0, y: bounds.midY, width: bounds.width, height: bounds.height / 2))
            NSGraphicsContext.current?.saveGraphicsState()
            clip.addClip()
            highlight.stroke()
            NSGraphicsContext.current?.restoreGraphicsState()
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        tracking = true
        layer?.opacity = 0.85
    }

    override func mouseUp(with event: NSEvent) {
        guard tracking else { return }
        tracking = false
        layer?.opacity = 1
        let loc = convert(event.locationInWindow, from: nil)
        if bounds.contains(loc), isEnabled, let action {
            NSApp.sendAction(action, to: target, from: self)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        hovering = true
        applyLayer()
    }

    override func mouseExited(with event: NSEvent) {
        hovering = false
        applyLayer()
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

// MARK: - IconBadgeView

final class IconBadgeView: NSView {
    private let imageView = NSImageView()
    private var size: CGFloat = 24
    private var glyphPointSize: CGFloat = 12.5

    var screen: AppScreen = .overview {
        didSet { needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false
        layer?.cornerRadius = 7
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.28
        layer?.shadowRadius = 1.6
        layer?.shadowOffset = CGSize(width: 0, height: -1)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentTintColor = .white
        imageView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 15),
            imageView.heightAnchor.constraint(equalToConstant: 15)
        ])
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) { nil }

    func setSymbol(_ name: String) {
        let config = NSImage.SymbolConfiguration(pointSize: glyphPointSize, weight: .semibold)
        imageView.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
    }

    func setBadgeSize(_ value: CGFloat) {
        size = value
        glyphPointSize = value >= 30 ? 15 : 12.5
        layer?.cornerRadius = value >= 30 ? 9 : 7
        invalidateIntrinsicContentSize()
        needsDisplay = true
        needsLayout = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let radius: CGFloat = size >= 30 ? 9 : 7
        let (c1, c2) = Theme.sectionGradient(screen)
        let gradient = NSGradient(starting: c1, ending: c2)
        let path = NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius)
        gradient?.draw(in: path, angle: -90)

        // Inset top-edge glass shine
        let highlight = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: radius - 0.5, yRadius: radius - 0.5)
        NSColor.white.withAlphaComponent(0.55).setStroke()
        highlight.lineWidth = 1
        let clip = NSBezierPath(rect: NSRect(x: 0, y: bounds.midY, width: bounds.width, height: bounds.height / 2))
        NSGraphicsContext.current?.saveGraphicsState()
        clip.addClip()
        highlight.stroke()
        NSGraphicsContext.current?.restoreGraphicsState()
    }

    override var intrinsicContentSize: NSSize { NSSize(width: size, height: size) }
}

// MARK: - SearchPillView

final class SearchPillView: NSView, NSTextFieldDelegate {
    var onChange: ((String) -> Void)?

    private let icon = NSImageView()
    private let field = NSTextField()

    var stringValue: String {
        get { field.stringValue }
        set { field.stringValue = newValue }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
        translatesAutoresizingMaskIntoConstraints = false
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .horizontal)

        icon.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")
        icon.contentTintColor = Theme.Colors.muted
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.imageScaling = .scaleProportionallyUpOrDown

        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 13, weight: .regular)
        field.textColor = Theme.Colors.text
        field.placeholderString = "Search"
        field.placeholderAttributedString = NSAttributedString(
            string: "Search",
            attributes: [
                .foregroundColor: NSColor.secondaryLabelColor,
                .font: NSFont.systemFont(ofSize: 13, weight: .regular)
            ]
        )
        field.lineBreakMode = .byTruncatingTail
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.delegate = self
        field.translatesAutoresizingMaskIntoConstraints = false

        addSubview(icon)
        addSubview(field)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 30),
            widthAnchor.constraint(equalToConstant: 170),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 170),
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 13),
            icon.heightAnchor.constraint(equalToConstant: 13),
            field.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
            field.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            field.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        applyChrome()
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyChrome()
        field.textColor = Theme.Colors.text
        icon.contentTintColor = Theme.Colors.muted
    }

    private func applyChrome() {
        layer?.masksToBounds = true
        layer?.cornerRadius = 15
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.08).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = Theme.Colors.separator.cgColor
    }

    func controlTextDidChange(_ obj: Notification) {
        onChange?(field.stringValue)
    }

    func focus() {
        window?.makeFirstResponder(field)
    }

    override var intrinsicContentSize: NSSize { NSSize(width: 170, height: 30) }
}

// MARK: - AccountPillView

/// Toolbar Free pill: [letter avatar] Free · 500 MB left — matches prototype `.pill` + `.av`.
final class AccountPillView: NSControl {
    private let row = NSStackView()
    private let avatar = NSView()
    private let avatarGrad = CAGradientLayer()
    private let initialLabel = makeLabel("Y", size: 11, weight: .bold, color: .white, align: .center)
    private let caption = makeLabel("Free · 500 MB left", size: 12.5, weight: .medium, color: .white)
    private var heightConstraint: NSLayoutConstraint!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        focusRingType = .none
        translatesAutoresizingMaskIntoConstraints = false
        clipsToBounds = false
        setContentCompressionResistancePriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)

        avatar.wantsLayer = true
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.layer?.masksToBounds = true
        avatarGrad.name = "avGrad"
        avatarGrad.colors = [NSColor(hex: 0x7FB8E6).cgColor, NSColor(hex: 0x3FA877).cgColor]
        avatarGrad.startPoint = CGPoint(x: 0.0, y: 0.0)
        avatarGrad.endPoint = CGPoint(x: 1.0, y: 1.0)
        avatar.layer?.addSublayer(avatarGrad)
        avatar.addSubview(initialLabel)

        caption.font = .systemFont(ofSize: 12.5, weight: .medium)
        caption.textColor = .white
        caption.setContentCompressionResistancePriority(.required, for: .horizontal)

        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 7
        row.translatesAutoresizingMaskIntoConstraints = false
        row.edgeInsets = NSEdgeInsets(top: 0, left: 6, bottom: 0, right: 12)
        row.addArrangedSubview(avatar)
        row.addArrangedSubview(caption)
        addSubview(row)

        heightConstraint = heightAnchor.constraint(equalToConstant: 32)
        heightConstraint.priority = .required
        NSLayoutConstraint.activate([
            heightConstraint,
            avatar.widthAnchor.constraint(equalToConstant: 20),
            avatar.heightAnchor.constraint(equalToConstant: 20),
            initialLabel.centerXAnchor.constraint(equalTo: avatar.centerXAnchor),
            initialLabel.centerYAnchor.constraint(equalTo: avatar.centerYAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        applyChrome()
    }

    required init?(coder: NSCoder) { nil }

    func reload(initial: String, caption text: String) {
        let letter = String(initial.prefix(1)).uppercased()
        initialLabel.stringValue = letter
        initialLabel.textColor = .white
        caption.stringValue = text
        caption.textColor = .white
        caption.font = .systemFont(ofSize: 12.5, weight: .medium)
        invalidateIntrinsicContentSize()
        needsLayout = true
        applyChrome()
    }

    override var intrinsicContentSize: NSSize {
        let font = caption.font ?? .systemFont(ofSize: 12.5, weight: .medium)
        let w = (caption.stringValue as NSString).size(withAttributes: [.font: font]).width
        return NSSize(width: 6 + 20 + 7 + ceil(w) + 12, height: 32)
    }

    override func layout() {
        super.layout()
        let side = min(avatar.bounds.width, avatar.bounds.height)
        let box = side > 0 ? avatar.bounds : CGRect(x: 0, y: 0, width: 20, height: 20)
        avatarGrad.frame = box
        avatarGrad.cornerRadius = box.height / 2
        avatar.layer?.cornerRadius = box.height / 2
        // Capsule radius must track height — fixed 99 + a crushed frame = diamond.
        layer?.cornerRadius = max(bounds.height, 1) / 2
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyChrome()
        caption.textColor = .white
        initialLabel.textColor = .white
    }

    private func applyChrome() {
        layer?.masksToBounds = true
        layer?.cornerRadius = max(bounds.height, 32) / 2
        layer?.backgroundColor = Theme.Colors.contentAlt.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = Theme.Colors.separator.cgColor
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled, let action else { return }
        NSApp.sendAction(action, to: target, from: self)
    }
}

// MARK: - ChipButton / FilterChip

final class ChipButton: NSControl {
    var isPressed = false {
        didSet { applyChrome(); updateLabel() }
    }

    private let titleLabel = NSTextField(labelWithString: "")

    convenience init(title: String) {
        self.init(frame: .zero)
        self.title = title
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        focusRingType = .none
        translatesAutoresizingMaskIntoConstraints = false
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.drawsBackground = false
        titleLabel.font = .systemFont(ofSize: 12.5, weight: .medium)
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 13),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -13),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 28)
        ])
        applyChrome()
        updateLabel()
    }

    required init?(coder: NSCoder) { nil }

    var title: String {
        get { titleLabel.stringValue }
        set {
            titleLabel.stringValue = newValue
            setAccessibilityLabel(newValue)
            invalidateIntrinsicContentSize()
            needsUpdateConstraints = true
        }
    }

    override var intrinsicContentSize: NSSize {
        let font = titleLabel.font ?? .systemFont(ofSize: 12.5, weight: .medium)
        let w = (title as NSString).size(withAttributes: [.font: font]).width
        return NSSize(width: max(40, ceil(w) + 26), height: 28)
    }

    override var fittingSize: NSSize { intrinsicContentSize }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyChrome()
        updateLabel()
    }

    private func updateLabel() {
        titleLabel.textColor = isPressed ? Theme.Colors.content : Theme.Colors.text
    }

    private func applyChrome() {
        layer?.cornerRadius = 99
        if isPressed {
            // Selected: solid white (or ink) pill with dark text — matches Clean filter refs.
            layer?.backgroundColor = Theme.Colors.text.cgColor
            layer?.borderWidth = 0
            layer?.borderColor = nil
        } else {
            // Unselected: filled dark pill + hairline border.
            layer?.backgroundColor = Theme.Colors.contentAlt.cgColor
            layer?.borderWidth = 1
            layer?.borderColor = Theme.Colors.separator.cgColor
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled, let action else { return }
        NSApp.sendAction(action, to: target, from: self)
    }
}

typealias FilterChip = ChipButton

// MARK: - PillLabel (Safe / Ask)

final class PillLabel: NSTextField {
    convenience init(text: String, safe: Bool) {
        self.init(labelWithString: text)
        font = .systemFont(ofSize: 10, weight: .bold)
        textColor = safe ? Theme.Colors.safeText : Theme.Colors.askText
        alignment = .center
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = (safe ? Theme.Colors.safeFill : Theme.Colors.askFill).cgColor
        translatesAutoresizingMaskIntoConstraints = false
    }

    override var intrinsicContentSize: NSSize {
        var size = super.intrinsicContentSize
        size.width += 16
        size.height += 4
        return size
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        let safe = textColor == Theme.Colors.safeText || stringValue == "Safe"
        textColor = safe ? Theme.Colors.safeText : Theme.Colors.askText
        layer?.backgroundColor = (safe ? Theme.Colors.safeFill : Theme.Colors.askFill).cgColor
    }
}

// MARK: - CardView

final class CardView: NSView {
    enum Kind {
        case contentAlt // cd2 fill
        case content    // opaque content
        case glass      // translucent overlay
    }

    var kind: Kind = .contentAlt {
        didSet { applyChrome() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        applyChrome()
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyChrome()
    }

    private func applyChrome() {
        layer?.cornerRadius = 20
        layer?.borderWidth = 1
        layer?.borderColor = Theme.Colors.separator.cgColor
        switch kind {
        case .contentAlt:
            layer?.backgroundColor = Theme.Colors.contentAlt.cgColor
            layer?.shadowOpacity = 0
        case .content:
            layer?.backgroundColor = Theme.Colors.content.cgColor
            layer?.shadowColor = NSColor.black.cgColor
            layer?.shadowOpacity = 0.12
            layer?.shadowRadius = 12
            layer?.shadowOffset = CGSize(width: 0, height: -2)
        case .glass:
            layer?.backgroundColor = Theme.Colors.overlay.cgColor
            layer?.borderColor = NSColor.white.withAlphaComponent(0.3).cgColor
            layer?.shadowOpacity = 0
        }
    }
}

// MARK: - Charts / progress

final class SegmentBarView: NSView {
    struct Slice {
        var name: String
        var bytes: Int64
        var color: NSColor
        var isFree: Bool
    }

    var slices: [Slice] = [] {
        didSet {
            needsDisplay = true
            hideTip()
        }
    }

    private var hoverIndex: Int?
    private var tipView: SegmentBarTipView?
    private var tracking: NSTrackingArea?

    override var isFlipped: Bool { false }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        tracking = area
    }

    override func mouseMoved(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        guard let index = hitSlice(at: loc) else {
            hideTip()
            return
        }
        showTip(for: index)
    }

    override func mouseEntered(with event: NSEvent) {
        mouseMoved(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        hideTip()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { hideTip() }
    }

    override func draw(_ dirtyRect: NSRect) {
        // Pill clip + Night track so 2pt gaps read as clean cuts (prototype `.bar`).
        let track = NSBezierPath(roundedRect: bounds, xRadius: bounds.height / 2, yRadius: bounds.height / 2)
        track.addClip()
        Theme.mapCut.setFill()
        bounds.fill()

        for (i, rect) in sliceRects().enumerated() {
            let slice = slices[i]
            // Free stays light and solid so it doesn’t look like an empty track gap.
            let fill = slice.isFree ? Theme.mapFree : slice.color
            fill.setFill()
            rect.fill()
        }
    }

    private func sliceRects() -> [NSRect] {
        let total = max(slices.reduce(CGFloat(0)) { $0 + CGFloat($1.bytes) }, 0.0001)
        var x: CGFloat = 0
        let gap: CGFloat = 2
        var rects: [NSRect] = []
        let lastVisibleIndex = slices.lastIndex(where: { $0.bytes > 0 })
        for (i, slice) in slices.enumerated() {
            guard slice.bytes > 0 else {
                rects.append(.zero)
                continue
            }
            let raw = bounds.width * (CGFloat(slice.bytes) / total)
            let isLast = i == lastVisibleIndex
            let w = max(slice.isFree ? 8 : 3, raw - (isLast ? 0 : gap))
            rects.append(NSRect(x: x, y: 0, width: w, height: bounds.height))
            x += w + (isLast ? 0 : gap)
        }
        return rects
    }

    private func hitSlice(at point: NSPoint) -> Int? {
        guard bounds.contains(point) else { return nil }
        for (i, rect) in sliceRects().enumerated() where rect.insetBy(dx: -1, dy: 0).contains(point) {
            return i
        }
        return nil
    }

    private func showTip(for index: Int) {
        guard slices.indices.contains(index) else { return }
        let slice = slices[index]
        let rects = sliceRects()
        guard rects.indices.contains(index) else { return }
        let segment = rects[index]

        if tipView == nil {
            let tip = SegmentBarTipView()
            tipView = tip
        }
        guard let tip = tipView else { return }
        tip.configure(title: slice.name, detail: AppFormat.mapSize(slice.bytes))
        tip.layoutSize()

        // Host on the window content view so the tip isn’t clipped by the card.
        guard let host = window?.contentView else { return }
        if tip.superview !== host {
            tip.removeFromSuperview()
            host.addSubview(tip)
        }

        let segmentMid = NSPoint(x: segment.midX, y: bounds.maxY)
        let inWindow = convert(segmentMid, to: nil)
        let inHost = host.convert(inWindow, from: nil)
        let tipW = tip.frame.width
        let tipH = tip.frame.height
        var tipX = inHost.x - tipW / 2
        tipX = max(8, min(tipX, host.bounds.width - tipW - 8))
        let tipY = inHost.y + 10
        tip.frame = NSRect(x: tipX, y: tipY, width: tipW, height: tipH)
        tip.arrowOffset = inHost.x - tip.frame.minX
        tip.needsDisplay = true
        tip.isHidden = false
        hoverIndex = index
    }

    private func hideTip() {
        hoverIndex = nil
        tipView?.isHidden = true
        tipView?.removeFromSuperview()
        tipView = nil
    }
}

/// Compact macOS Storage–style hover tip: name + size, arrow pointing at the bar segment.
private final class SegmentBarTipView: NSView {
    private let titleLabel = makeLabel("", size: 12, weight: .semibold, color: .white)
    private let detailLabel = makeLabel("", size: 11, weight: .regular, color: NSColor.white.withAlphaComponent(0.72))
    /// Distance from tip’s leading edge to the arrow tip (in tip coords).
    var arrowOffset: CGFloat = 20

    private let arrowH: CGFloat = 6
    private let padX: CGFloat = 10
    private let padY: CGFloat = 7

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        addSubview(detailLabel)
    }

    required init?(coder: NSCoder) { nil }

    func configure(title: String, detail: String) {
        titleLabel.stringValue = title
        detailLabel.stringValue = detail
    }

    func layoutSize() {
        titleLabel.sizeToFit()
        detailLabel.sizeToFit()
        let contentW = max(titleLabel.frame.width, detailLabel.frame.width)
        let w = max(72, contentW + padX * 2)
        let h = titleLabel.frame.height + 2 + detailLabel.frame.height + padY * 2 + arrowH
        frame.size = NSSize(width: w, height: h)
        let textTop = h - padY - titleLabel.frame.height
        titleLabel.frame = NSRect(
            x: padX,
            y: textTop,
            width: contentW,
            height: titleLabel.frame.height
        )
        detailLabel.frame = NSRect(
            x: padX,
            y: textTop - 2 - detailLabel.frame.height,
            width: contentW,
            height: detailLabel.frame.height
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        let bubble = NSRect(x: 0, y: arrowH, width: bounds.width, height: bounds.height - arrowH)
        let path = NSBezierPath(roundedRect: bubble, xRadius: 8, yRadius: 8)
        let ax = min(max(10, arrowOffset), bounds.width - 10)
        path.move(to: NSPoint(x: ax - 6, y: arrowH))
        path.line(to: NSPoint(x: ax, y: 0))
        path.line(to: NSPoint(x: ax + 6, y: arrowH))
        path.close()

        NSColor(calibratedWhite: 0.12, alpha: 0.92).setFill()
        path.fill()

        // Soft edge like System Settings.
        NSColor.white.withAlphaComponent(0.08).setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }
}

final class RingChartView: NSView {
    struct Slice {
        var weight: CGFloat
        var color: NSColor
        var children: [(CGFloat, NSColor)]
        /// Free space — keep that sector empty (no fill on either ring).
        var leaveEmpty: Bool = false
    }

    var slices: [Slice] = [] {
        didSet { needsDisplay = true }
    }
    var centerTitle = ""
    var centerSubtitle = ""
    var highlightIndex: Int = 0
    /// When false (Free plan), outer drill-down ring is heavily muted.
    var showOuterDetail = true

    override func draw(_ dirtyRect: NSRect) {
        let inset: CGFloat = 2
        let rect = bounds.insetBy(dx: inset, dy: inset)
        let center = NSPoint(x: rect.midX, y: rect.midY)
        // Thick middle ring; outer a bit thinner but clearly visible (handoff ref).
        let scale = min(rect.width, rect.height) / 400
        let innerR = 56 * scale
        let midOuterR = 124 * scale
        let outerInnerR = 132 * scale
        let outerR = 188 * scale
        let total = max(slices.reduce(0) { $0 + $1.weight }, 0.0001)
        let gapRad: CGFloat = 0.012
        let kidGapRad: CGFloat = 0.006
        let startAngle: CGFloat = -.pi / 2

        // Outer ring — only where a category has children (Free stays open).
        var a = startAngle
        for (i, slice) in slices.enumerated() {
            let sweep = CGFloat(slice.weight / total) * 2 * .pi
            defer { a += sweep }
            guard !slice.children.isEmpty else { continue }

            let kidTotal = max(slice.children.reduce(0) { $0 + $1.0 }, 0.0001)
            var b = a
            for (j, kid) in slice.children.enumerated() {
                let kidSweep = sweep * (kid.0 / kidTotal)
                let b0 = b + kidGapRad
                let b1 = b + kidSweep - kidGapRad
                if b1 > b0 {
                    let alpha: CGFloat = showOuterDetail
                        ? (i == highlightIndex ? max(0.70, 0.95 - CGFloat(j) * 0.06) : 0.78)
                        : 0.18
                    annularSector(center: center, r0: outerInnerR, r1: outerR, a0: b0, a1: b1)
                        .fill(with: slice.color.withAlphaComponent(alpha))
                }
                b += kidSweep
            }
        }

        // Inner (middle) ring — always complete, brighter than before.
        a = startAngle
        for (i, slice) in slices.enumerated() {
            let sweep = CGFloat(slice.weight / total) * 2 * .pi
            defer { a += sweep }
            let a0 = a + gapRad
            let a1 = a + sweep - gapRad
            guard a1 > a0 else { continue }
            let alpha: CGFloat = i == highlightIndex ? 1 : 0.78
            annularSector(center: center, r0: innerR, r1: midOuterR, a0: a0, a1: a1)
                .fill(with: slice.color.withAlphaComponent(alpha))
        }

        let titleSizePt = max(22, min(32, innerR * 0.95))
        if !centerTitle.isEmpty {
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: titleSizePt, weight: .bold),
                .foregroundColor: Theme.Colors.text,
                .kern: -0.03 * titleSizePt
            ]
            let titleSize = (centerTitle as NSString).size(withAttributes: titleAttrs)
            (centerTitle as NSString).draw(
                at: NSPoint(x: center.x - titleSize.width / 2, y: center.y + 2),
                withAttributes: titleAttrs
            )
        }
        if !centerSubtitle.isEmpty {
            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: Theme.Colors.muted
            ]
            let subSize = (centerSubtitle as NSString).size(withAttributes: subAttrs)
            (centerSubtitle as NSString).draw(
                at: NSPoint(x: center.x - subSize.width / 2, y: center.y - titleSizePt * 0.72),
                withAttributes: subAttrs
            )
        }
    }

    /// Filled donut wedge — same geometry as the prototype SVG `arc()` helper.
    /// Angles are SVG-style radians: −π/2 at top, increasing clockwise on screen.
    private func annularSector(center: NSPoint, r0: CGFloat, r1: CGFloat, a0: CGFloat, a1: CGFloat) -> NSBezierPath {
        func pt(_ a: CGFloat, _ r: CGFloat) -> NSPoint {
            NSPoint(x: center.x + r * cos(a), y: center.y - r * sin(a))
        }
        // AppKit arc angles: 0 = right, CCW positive → map SVG angle a → −a°.
        func deg(_ a: CGFloat) -> CGFloat { -a * 180 / .pi }

        let path = NSBezierPath()
        path.move(to: pt(a0, r1))
        path.appendArc(
            withCenter: center,
            radius: r1,
            startAngle: deg(a0),
            endAngle: deg(a1),
            clockwise: true
        )
        path.line(to: pt(a1, r0))
        path.appendArc(
            withCenter: center,
            radius: r0,
            startAngle: deg(a1),
            endAngle: deg(a0),
            clockwise: false
        )
        path.close()
        return path
    }
}

private extension NSBezierPath {
    func fill(with color: NSColor) {
        color.setFill()
        fill()
    }
}

final class ProgressTrack: NSView {
    var progress: CGFloat = 0 {
        didSet { needsDisplay = true }
    }
    var fillColor: NSColor = Theme.Colors.accent
    var usesQuotaGradient = false

    override func draw(_ dirtyRect: NSRect) {
        let radius = bounds.height / 2
        let track = NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius)
        Theme.Colors.separator.setFill()
        track.fill()
        let width = max(4, bounds.width * max(0, min(1, progress)))
        let fillRect = NSRect(x: 0, y: 0, width: width, height: bounds.height)
        if usesQuotaGradient {
            let gradient = NSGradient(starting: NSColor(hex: 0x7FB8E6), ending: NSColor(hex: 0x3FA877))
            let path = NSBezierPath(roundedRect: fillRect, xRadius: radius, yRadius: radius)
            gradient?.draw(in: path, angle: 0)
        } else {
            let fill = NSBezierPath(roundedRect: fillRect, xRadius: radius, yRadius: radius)
            fillColor.setFill()
            fill.fill()
        }
    }
}

final class LockOverlayView: NSView {
    var titleText = "Unlock iClearer"
    var bodyText = "Exact names, paths and tools are part of iClearer."
    var onUnlock: (() -> Void)?

    private let titleLabel = makeLabel("", size: 16, weight: .semibold, color: Theme.Colors.text, align: .center)
    private let bodyLabel = makeMultilineLabel("", size: 13, weight: .regular, color: Theme.Colors.muted)
    private let button = PillButton(title: "Unlock iClearer", style: .primary)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false

        let lock = NSImageView(image: NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "Locked")!)
        lock.contentTintColor = Theme.Colors.accent
        lock.translatesAutoresizingMaskIntoConstraints = false

        bodyLabel.alignment = .center
        button.target = self
        button.action = #selector(unlock)

        [lock, titleLabel, bodyLabel, button].forEach { addSubview($0) }
        NSLayoutConstraint.activate([
            lock.centerXAnchor.constraint(equalTo: centerXAnchor),
            lock.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -48),
            titleLabel.topAnchor.constraint(equalTo: lock.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            bodyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 40),
            bodyLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40),
            button.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 14),
            button.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
        applyChrome()
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyChrome()
        titleLabel.textColor = Theme.Colors.text
        bodyLabel.textColor = Theme.Colors.muted
    }

    private func applyChrome() {
        layer?.backgroundColor = Theme.Colors.content.withAlphaComponent(0.72).cgColor
    }

    func refresh() {
        titleLabel.stringValue = titleText
        bodyLabel.stringValue = bodyText
    }

    @objc private func unlock() { onUnlock?() }
}

enum SFSymbol {
    static func forScreen(_ screen: AppScreen) -> String {
        switch screen {
        case .overview: return "circle.grid.2x2.fill"
        case .clean: return "trash"
        case .storageMap: return "chart.pie.fill"
        case .largeFiles: return "doc.fill"
        case .apps: return "square.grid.2x2.fill"
        case .builders: return "chevron.left.forwardslash.chevron.right"
        case .history: return "clock.arrow.circlepath"
        case .duplicates: return "doc.on.doc"
        case .maintenance: return "wrench.and.screwdriver"
        }
    }
}

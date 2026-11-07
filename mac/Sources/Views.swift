import AppKit

enum Theme {
    static let accent = NSColor(calibratedRed: 0.18, green: 0.72, blue: 0.55, alpha: 1)
    static let accentDeep = NSColor(calibratedRed: 0.08, green: 0.42, blue: 0.34, alpha: 1)
    static let sidebar = NSColor(calibratedRed: 0.09, green: 0.13, blue: 0.12, alpha: 1)
    static let warning = NSColor(calibratedRed: 0.96, green: 0.62, blue: 0.22, alpha: 1)
}

final class RingView: NSView {
    var progress: CGFloat = 0 {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { false }
    override var intrinsicContentSize: NSSize { NSSize(width: 132, height: 132) }

    override func draw(_ dirtyRect: NSRect) {
        let inset: CGFloat = 10
        let rect = bounds.insetBy(dx: inset, dy: inset)
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let line: CGFloat = 10

        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        track.lineWidth = line
        track.lineCapStyle = .round
        NSColor.white.withAlphaComponent(0.12).setStroke()
        track.stroke()

        let value = max(0, min(1, progress))
        guard value > 0 else { return }
        let arc = NSBezierPath()
        arc.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 90 - 360 * value, clockwise: true)
        arc.lineWidth = line
        arc.lineCapStyle = .round
        Theme.accent.setStroke()
        arc.stroke()
    }
}

final class BarView: NSView {
    var progress: CGFloat = 0 {
        didSet { needsDisplay = true }
    }
    var color: NSColor = Theme.accent

    override func draw(_ dirtyRect: NSRect) {
        let radius = bounds.height / 2
        let track = NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius)
        NSColor.labelColor.withAlphaComponent(0.12).setFill()
        track.fill()
        let width = max(4, bounds.width * max(0, min(1, progress)))
        let fillRect = NSRect(x: 0, y: 0, width: width, height: bounds.height)
        let fill = NSBezierPath(roundedRect: fillRect, xRadius: radius, yRadius: radius)
        color.setFill()
        fill.fill()
    }
}

func makeLabel(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, align: NSTextAlignment = .left) -> NSTextField {
    let field = NSTextField(labelWithString: text)
    field.font = .systemFont(ofSize: size, weight: weight)
    field.textColor = color
    field.alignment = align
    field.lineBreakMode = .byTruncatingMiddle
    field.drawsBackground = false
    field.isBezeled = false
    field.translatesAutoresizingMaskIntoConstraints = false
    return field
}

func makePillButton(_ title: String, accent: Bool) -> NSButton {
    let button = NSButton(title: title, target: nil, action: nil)
    button.bezelStyle = .rounded
    button.isBordered = true
    if accent {
        button.bezelColor = Theme.accent
        button.contentTintColor = .white
    }
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
}

import AppKit

/// Large hero "liquid glass bead" orb matching the prototype SVG `#bead`
/// (radial fill #E3F2FC → #82BCE7 → #3B7CB0, glass rim, white check, specular).
final class LiquidGlassBeadView: NSView {
    var diameter: CGFloat = 140 {
        didSet { invalidateIntrinsicContentSize(); needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false
        translatesAutoresizingMaskIntoConstraints = false
        shadow = NSShadow()
        shadow?.shadowColor = NSColor.black.withAlphaComponent(0.35)
        shadow?.shadowBlurRadius = 22
        shadow?.shadowOffset = NSSize(width: 0, height: -10)
    }

    required init?(coder: NSCoder) { nil }

    override var intrinsicContentSize: NSSize {
        NSSize(width: diameter, height: diameter)
    }

    override func draw(_ dirtyRect: NSRect) {
        let side = min(bounds.width, bounds.height)
        let origin = NSPoint(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2)
        let scale = side / 224
        let cx = origin.x + side / 2
        let cy = origin.y + side / 2
        let r = 108 * scale

        // Radial fill matching #gd (cx=.4 cy=.35 r=.75) in viewBox coords
        let colors: [CGColor] = [
            NSColor(hex: 0xE3F2FC).cgColor,
            NSColor(hex: 0x82BCE7).cgColor,
            NSColor(hex: 0x3B7CB0).cgColor
        ]
        let locations: [CGFloat] = [0, 0.55, 1]
        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors as CFArray,
            locations: locations
        ), let ctx = NSGraphicsContext.current?.cgContext {
            let center = CGPoint(
                x: origin.x + 0.4 * side,
                y: origin.y + (1 - 0.35) * side
            )
            ctx.saveGState()
            ctx.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
            ctx.clip()
            ctx.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: 0.75 * side,
                options: [.drawsAfterEndLocation]
            )
            ctx.restoreGState()
        }

        // Glass rim (#gr)
        let rim = NSBezierPath(ovalIn: NSRect(x: cx - 105 * scale, y: cy - 105 * scale, width: 210 * scale, height: 210 * scale))
        NSColor.white.withAlphaComponent(0.55).setStroke()
        rim.lineWidth = 5 * scale
        rim.stroke()
        let rimInner = NSBezierPath(ovalIn: NSRect(x: cx - 103 * scale, y: cy - 103 * scale, width: 206 * scale, height: 206 * scale))
        NSColor.white.withAlphaComponent(0.18).setStroke()
        rimInner.lineWidth = 1.5 * scale
        rimInner.stroke()

        // Checkmark path M70 118 l30 30 56-64 — flip Y for AppKit coords
        func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
            NSPoint(x: origin.x + x * scale, y: origin.y + (224 - y) * scale)
        }
        let shadowCheck = NSBezierPath()
        shadowCheck.move(to: p(70, 118 + 5))
        shadowCheck.line(to: p(100, 148 + 5))
        shadowCheck.line(to: p(156, 84 + 5))
        NSColor(hex: 0x06223A, alpha: 0.28).setStroke()
        shadowCheck.lineWidth = 13 * scale
        shadowCheck.lineCapStyle = .round
        shadowCheck.lineJoinStyle = .round
        shadowCheck.stroke()

        let check = NSBezierPath()
        check.move(to: p(70, 118))
        check.line(to: p(100, 148))
        check.line(to: p(156, 84))
        NSColor.white.setStroke()
        check.lineWidth = 13 * scale
        check.lineCapStyle = .round
        check.lineJoinStyle = .round
        check.stroke()

        // Specular highlight ellipse top-left
        let hx = origin.x + 74 * scale
        let hy = origin.y + (224 - 56) * scale
        let highlight = NSBezierPath(ovalIn: NSRect(
            x: hx - 38 * scale,
            y: hy - 19 * scale,
            width: 76 * scale,
            height: 38 * scale
        ))
        var transform = AffineTransform()
        transform.translate(x: hx, y: hy)
        transform.rotate(byDegrees: -35)
        transform.translate(x: -hx, y: -hy)
        highlight.transform(using: transform)
        NSColor.white.withAlphaComponent(0.6).setFill()
        highlight.fill()
    }
}

/// Circular liquid-glass badge with a solid white `lock.fill` padlock.
final class LiquidLockBadgeView: NSView {
    var size: CGFloat = 28 {
        didSet { invalidateIntrinsicContentSize(); needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
    }

    required init?(coder: NSCoder) { nil }

    override var intrinsicContentSize: NSSize { NSSize(width: size, height: size) }

    override func draw(_ dirtyRect: NSRect) {
        let colors: [CGColor] = [
            NSColor(hex: 0xE3F2FC).cgColor,
            NSColor(hex: 0x82BCE7).cgColor,
            NSColor(hex: 0x3B7CB0).cgColor
        ]
        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors as CFArray,
            locations: [0, 0.55, 1]
        ), let ctx = NSGraphicsContext.current?.cgContext {
            let center = CGPoint(x: bounds.width * 0.38, y: bounds.height * 0.68)
            ctx.saveGState()
            ctx.addEllipse(in: bounds)
            ctx.clip()
            ctx.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: CGPoint(x: bounds.midX, y: bounds.midY),
                endRadius: bounds.width * 0.75,
                options: [.drawsAfterEndLocation]
            )
            ctx.restoreGState()
        }

        // Chunky solid padlock — SF Symbol lock.fill (matches Free-plan sample).
        let point = max(11, min(bounds.width, bounds.height) * 0.45)
        let config = NSImage.SymbolConfiguration(pointSize: point, weight: .bold)
        guard let symbol = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "Locked")?
            .withSymbolConfiguration(config) else { return }
        let tinted = NSImage(size: symbol.size, flipped: false) { rect in
            NSColor.white.set()
            rect.fill()
            symbol.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1)
            return true
        }
        let sz = tinted.size
        tinted.draw(in: NSRect(
            x: bounds.midX - sz.width / 2,
            y: bounds.midY - sz.height / 2,
            width: sz.width,
            height: sz.height
        ))
    }
}

/// History locked-state hero — blue radial orb + white clock hands (prototype `hsl` / handoff icon).
final class HistoryClockIconView: NSView {
    var diameter: CGFloat = 110 {
        didSet { invalidateIntrinsicContentSize(); needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) { nil }

    override var intrinsicContentSize: NSSize {
        NSSize(width: diameter, height: diameter)
    }

    override func draw(_ dirtyRect: NSRect) {
        let side = min(bounds.width, bounds.height)
        let origin = NSPoint(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2)
        let scale = side / 224
        let cx = origin.x + side / 2
        let cy = origin.y + side / 2
        let r = 108 * scale

        let colors: [CGColor] = [
            NSColor(hex: 0xE3F2FC).cgColor,
            NSColor(hex: 0x82BCE7).cgColor,
            NSColor(hex: 0x3B7CB0).cgColor
        ]
        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors as CFArray,
            locations: [0, 0.55, 1]
        ), let ctx = NSGraphicsContext.current?.cgContext {
            let center = CGPoint(
                x: origin.x + 0.4 * side,
                y: origin.y + (1 - 0.35) * side
            )
            ctx.saveGState()
            ctx.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
            ctx.clip()
            ctx.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: 0.75 * side,
                options: [.drawsAfterEndLocation]
            )
            ctx.restoreGState()
        }

        // Glass rim
        let rim = NSBezierPath(ovalIn: NSRect(
            x: cx - 105 * scale, y: cy - 105 * scale,
            width: 210 * scale, height: 210 * scale
        ))
        NSColor.white.withAlphaComponent(0.7).setStroke()
        rim.lineWidth = 5 * scale
        rim.stroke()

        // White clock hands — 12 o’clock + 3 o’clock (matches handoff History icon).
        let hand = NSBezierPath()
        hand.move(to: NSPoint(x: cx, y: cy + 46 * scale))
        hand.line(to: NSPoint(x: cx, y: cy))
        hand.line(to: NSPoint(x: cx + 40 * scale, y: cy))
        NSColor.white.setStroke()
        hand.lineWidth = 13 * scale
        hand.lineCapStyle = .round
        hand.lineJoinStyle = .round
        hand.stroke()
    }
}

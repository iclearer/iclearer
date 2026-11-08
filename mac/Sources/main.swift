import AppKit

final class AppBootstrap {
    static let shared = AppBootstrap()
    let delegate = AppDelegate()
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
app.appearance = NSAppearance(named: .darkAqua)
app.delegate = AppBootstrap.shared.delegate
app.run()

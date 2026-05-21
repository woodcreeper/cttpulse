import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    func show(store: TelemetryStore) {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 760, height: 620),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Telemetry Settings"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
            window.isOpaque = false
            window.contentView = NSHostingView(rootView: SettingsView(store: store))
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

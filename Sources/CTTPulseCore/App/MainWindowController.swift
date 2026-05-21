import AppKit
import SwiftUI

@MainActor
final class MainWindowController {
    private var window: NSWindow?

    func show(store: TelemetryStore, coordinator: AppCoordinator) {
        if window == nil {
            let contentView = ContentView(store: store)
                .environmentObject(coordinator)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1040, height: 680),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "CTT Pulse"
            window.titlebarAppearsTransparent = true
            window.toolbarStyle = .unifiedCompact
            window.backgroundColor = .clear
            window.isOpaque = false
            window.contentView = NSHostingView(rootView: contentView)
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

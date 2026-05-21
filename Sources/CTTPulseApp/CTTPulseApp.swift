import AppKit
import SwiftUI
import CTTPulseCore

@main
struct CTTPulseApplication: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var coordinator = AppCoordinator.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(store: coordinator.store)
                .environmentObject(coordinator)
        } label: {
            Label("CTT Pulse", systemImage: "antenna.radiowaves.left.and.right")
        }
        .menuBarExtraStyle(.menu)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppCoordinator.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppCoordinator.shared.stop()
    }
}

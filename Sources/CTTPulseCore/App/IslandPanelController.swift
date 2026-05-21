import AppKit
import Combine
import SwiftUI

@MainActor
final class IslandPanelController {
    private var panel: NSPanel?
    private weak var state: IslandPanelState?
    private var cancellables: Set<AnyCancellable> = []
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var screen: NSScreen?

    private let panelSize = NSSize(width: 430, height: 330)
    private let hoverSize = NSSize(width: 220, height: 70)
    private let collapsedSize = NSSize(width: 310, height: 86)
    private let expandedSize = NSSize(width: 430, height: 330)

    func show(store: TelemetryStore, state: IslandPanelState, actions: IslandActions) {
        self.state = state
        self.screen = NotchGeometry.islandScreen()

        if panel == nil {
            let rootView = CTTPulseView(store: store, state: state, actions: actions)
            let hostingView = NSHostingView(rootView: rootView)

            let panel = NSPanel(
                contentRect: frame(for: panelSize),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.contentView = hostingView
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            panel.animationBehavior = .utilityWindow

            self.panel = panel
            installOutsideClickMonitors()

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(repositionPanel),
                name: NSApplication.didChangeScreenParametersNotification,
                object: nil
            )

            NSWorkspace.shared.notificationCenter.addObserver(
                self,
                selector: #selector(repositionPanel),
                name: NSWorkspace.activeSpaceDidChangeNotification,
                object: nil
            )
        }

        state.$isExpanded
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.resize()
            }
            .store(in: &cancellables)

        state.$isVisible
            .removeDuplicates()
            .sink { [weak self] isVisible in
                self?.setVisible(isVisible)
            }
            .store(in: &cancellables)

        state.$isHoverPreview
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.resize()
            }
            .store(in: &cancellables)

        resize()
        setVisible(state.isVisible)
    }

    @objc private func repositionPanel() {
        screen = NotchGeometry.islandScreen()
        resize()
    }

    private func resize() {
        guard let panel else { return }
        panel.setFrame(frame(for: panelSize), display: true, animate: false)
    }

    private func setVisible(_ isVisible: Bool) {
        guard let panel else { return }

        if isVisible {
            resize()
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
    }

    private func size(for state: IslandPanelState) -> NSSize {
        if state.isExpanded {
            return expandedSize
        }

        if state.isHoverPreview {
            return hoverSize
        }

        return collapsedSize
    }

    private func frame(for size: NSSize) -> NSRect {
        let screen = self.screen ?? NotchGeometry.islandScreen()
        let anchor = NotchGeometry.anchor(in: screen)
        let y = NotchGeometry.islandTopY(in: screen) - size.height
        let x = anchor.x - (size.width / 2)
        return NSRect(origin: NSPoint(x: x, y: y), size: size)
    }

    private func installOutsideClickMonitors() {
        guard globalMouseMonitor == nil, localMouseMonitor == nil else { return }

        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            Task { @MainActor in
                self?.hideIfClickIsOutsidePanel()
            }
        }

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in
                self?.hideIfClickIsOutsidePanel()
            }

            return event
        }
    }

    private func hideIfClickIsOutsidePanel() {
        guard
            let panel,
            let state,
            state.isVisible,
            !visibleContentFrame(for: state, in: panel.frame).contains(NSEvent.mouseLocation)
        else {
            return
        }

        state.hide()
    }

    private func visibleContentFrame(for state: IslandPanelState, in panelFrame: NSRect) -> NSRect {
        let size = size(for: state)
        let origin = NSPoint(
            x: panelFrame.midX - size.width / 2,
            y: panelFrame.maxY - size.height
        )

        return NSRect(origin: origin, size: size)
    }
}

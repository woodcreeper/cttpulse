import AppKit

@MainActor
final class NotchHoverMonitor {
    private var timer: Timer?
    private var screen: NSScreen?
    private var isInsideHotspot = false
    private var onEnter: (@MainActor () -> Void)?
    private var onExit: (@MainActor () -> Void)?

    func start(
        onEnter: @escaping @MainActor () -> Void,
        onExit: @escaping @MainActor () -> Void
    ) {
        self.onEnter = onEnter
        self.onExit = onExit
        screen = NotchGeometry.islandScreen()

        stopTimer()

        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    func stop() {
        stopTimer()
        onEnter = nil
        onExit = nil
        screen = nil
        isInsideHotspot = false
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let mouse = NSEvent.mouseLocation
        let screen = self.screen ?? NotchGeometry.islandScreen()
        let isInside = NotchGeometry.hotspot(in: screen).contains(mouse)

        guard isInside != isInsideHotspot else { return }

        isInsideHotspot = isInside

        if isInside {
            onEnter?()
        } else {
            onExit?()
        }
    }
}

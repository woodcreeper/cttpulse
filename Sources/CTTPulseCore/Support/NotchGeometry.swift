import AppKit

enum NotchGeometry {
    static func islandScreen() -> NSScreen {
        if let notchedScreen = NSScreen.screens.first(where: hasNotch) {
            return notchedScreen
        }

        return NSScreen.main ?? NSScreen.screens[0]
    }

    static func anchor(in screen: NSScreen) -> NSPoint {
        guard
            let leftArea = screen.auxiliaryTopLeftArea,
            let rightArea = screen.auxiliaryTopRightArea,
            leftArea.maxX < rightArea.minX
        else {
            return NSPoint(x: screen.frame.midX, y: screen.visibleFrame.maxY)
        }

        let notchCenterX = (leftArea.maxX + rightArea.minX) / 2
        let topSafeY = min(leftArea.minY, rightArea.minY)
        return NSPoint(x: notchCenterX, y: topSafeY)
    }

    static func islandTopY(in screen: NSScreen) -> CGFloat {
        hasNotch(screen) ? screen.frame.maxY : screen.visibleFrame.maxY
    }

    static func hotspot(in screen: NSScreen) -> NSRect {
        let anchor = anchor(in: screen)
        let topY = islandTopY(in: screen)
        let bottomY = topY - 86
        let width: CGFloat = 260

        return NSRect(
            x: anchor.x - width / 2,
            y: bottomY,
            width: width,
            height: max(62, topY - bottomY)
        )
    }

    private static func hasNotch(_ screen: NSScreen) -> Bool {
        guard
            let leftArea = screen.auxiliaryTopLeftArea,
            let rightArea = screen.auxiliaryTopRightArea
        else {
            return false
        }

        return leftArea.maxX < rightArea.minX
    }
}

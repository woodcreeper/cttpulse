import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
public final class AppCoordinator: ObservableObject {
    public static let shared = AppCoordinator()

    public let store: TelemetryStore
    public let islandState = IslandPanelState()

    private let islandPanelController = IslandPanelController()
    private let notchHoverMonitor = NotchHoverMonitor()
    private let mainWindowController = MainWindowController()
    private let settingsWindowController = SettingsWindowController()
    private var cancellables: Set<AnyCancellable> = []
    private var islandAutoHideTask: Task<Void, Never>?
    private var hoverHideTask: Task<Void, Never>?
    private var didStart = false

    private init() {
        let tokenStore = KeychainTokenStore()
        let apiClient = CTTAPIClient(tokenStore: tokenStore)
        self.store = TelemetryStore(apiClient: apiClient, tokenStore: tokenStore)
    }

    public func start() {
        guard !didStart else { return }
        didStart = true

        islandPanelController.show(
            store: store,
            state: islandState,
            actions: IslandActions(
                openMain: { [weak self] in self?.showMainWindow() },
                openSettings: { [weak self] in self?.showSettingsWindow() },
                refresh: { [weak self] in self?.refreshNow() },
                quit: { NSApp.terminate(nil) }
            )
        )

        store.$pulseID
            .dropFirst()
            .sink { [weak self] _ in
                self?.showIslandForNewCheckIn()
            }
            .store(in: &cancellables)

        notchHoverMonitor.start(
            onEnter: { [weak self] in
                self?.showIslandForHover()
            },
            onExit: { [weak self] in
                self?.scheduleHoverHide()
            }
        )

        store.startPolling()
    }

    public func stop() {
        islandAutoHideTask?.cancel()
        hoverHideTask?.cancel()
        notchHoverMonitor.stop()
        store.stopPolling()
    }

    public func showMainWindow() {
        hoverHideTask?.cancel()
        islandState.hide()
        mainWindowController.show(store: store, coordinator: self)
    }

    public func showSettingsWindow() {
        hoverHideTask?.cancel()
        islandState.hide()
        settingsWindowController.show(store: store)
    }

    public func refreshNow() {
        Task { await store.refresh(reason: .manual) }
    }

    public func toggleIsland() {
        hoverHideTask?.cancel()

        if islandState.isVisible {
            islandState.hide()
        } else {
            islandState.show(expanded: true)
        }
    }

    private func showIslandForNewCheckIn() {
        guard store.latestNewCount > 0 else { return }

        islandAutoHideTask?.cancel()
        hoverHideTask?.cancel()
        islandState.show(expanded: false)

        islandAutoHideTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(12))
            } catch {
                return
            }

            await MainActor.run {
                self?.islandState.hide()
            }
        }
    }

    private func showIslandForHover() {
        guard !islandState.isVisible else { return }

        hoverHideTask?.cancel()
        islandState.showHoverPreview()
    }

    private func scheduleHoverHide() {
        guard islandState.isHoverPreview && !islandState.isExpanded else { return }

        hoverHideTask?.cancel()
        hoverHideTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(550))
            } catch {
                return
            }

            await MainActor.run {
                guard self?.islandState.isHoverPreview == true else { return }
                self?.islandState.hide()
            }
        }
    }
}

@MainActor
public final class IslandPanelState: ObservableObject {
    @Published public var isVisible = false
    @Published public var isExpanded = false
    @Published public var isHoverPreview = false

    public init() {}

    public func show(expanded: Bool) {
        isHoverPreview = false
        isExpanded = expanded
        isVisible = true
    }

    public func showHoverPreview() {
        isHoverPreview = true
        isExpanded = false
        isVisible = true
    }

    public func hide() {
        isVisible = false
        isExpanded = false
        isHoverPreview = false
    }
}

public struct IslandActions {
    public let openMain: @MainActor () -> Void
    public let openSettings: @MainActor () -> Void
    public let refresh: @MainActor () -> Void
    public let quit: @MainActor () -> Void

    public init(
        openMain: @escaping @MainActor () -> Void,
        openSettings: @escaping @MainActor () -> Void,
        refresh: @escaping @MainActor () -> Void,
        quit: @escaping @MainActor () -> Void
    ) {
        self.openMain = openMain
        self.openSettings = openSettings
        self.refresh = refresh
        self.quit = quit
    }
}

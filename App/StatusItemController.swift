import AppKit
import FlightKit
import Observation
import SwiftUI

/// Owns the menu-bar item and its popover. Uses AppKit rather than MenuBarExtra because the
/// auto-open style must open and close the card programmatically.
@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    static let autoCloseDelay: Duration = .seconds(10)

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let tracker: FlightTracker
    private let settings: AppSettings
    private var openedAutomatically = false
    private var autoClose: Task<Void, Never>?

    var isPopoverShown: Bool { popover.isShown }

    init(tracker: FlightTracker, settings: AppSettings, openSettings: @escaping () -> Void) {
        self.tracker = tracker
        self.settings = settings
        super.init()

        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: FlightCardView(tracker: tracker, openSettings: { [weak self] in
                self?.popover.performClose(nil)
                openSettings()
            })
        )

        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.imagePosition = .imageLeading
        render()
    }

    func planeAppeared(_ sighting: FlightTracker.Sighting) {
        guard settings.style == .autoOpenCard, !popover.isShown else { return }
        openedAutomatically = true
        show()
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            openedAutomatically = false
            show()
        }
    }

    private func show() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func popoverDidClose(_ notification: Notification) {
        openedAutomatically = false
        autoClose?.cancel()
    }

    /// Redraws on every relevant change; withObservationTracking fires once, so it re-registers itself.
    private func render() {
        withObservationTracking {
            draw()
        } onChange: { [weak self] in
            Task { @MainActor in self?.render() }
        }
    }

    private func draw() {
        guard let button = statusItem.button else { return }
        let current = tracker.current
        let symbol = tracker.status == .quiet ? "moon.zzz" : "airplane"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Flight Overhead")
        image?.isTemplate = true
        button.image = image
        button.alphaValue = tracker.status == .offline ? 0.4 : 1
        button.contentTintColor = nil
        button.title = ""

        if let current {
            switch settings.style {
            case .liveText:
                button.title = String(Formatting.menuBarText(current.plane, route: current.route).dropFirst(2))
            case .quietIcon:
                button.contentTintColor = .controlAccentColor
            case .autoOpenCard:
                break
            }
            autoClose?.cancel()
        } else if openedAutomatically, popover.isShown {
            scheduleAutoClose()
        }
    }

    private func scheduleAutoClose() {
        autoClose?.cancel()
        autoClose = Task { [weak self] in
            try? await Task.sleep(for: Self.autoCloseDelay)
            guard !Task.isCancelled, let self, self.openedAutomatically, self.tracker.current == nil else { return }
            self.popover.performClose(nil)
        }
    }
}

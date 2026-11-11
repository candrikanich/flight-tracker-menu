import AppKit
import FlightKit
import Observation
import SwiftUI

@main
struct OverflightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings()
    private let tracker = FlightTracker(feed: FeedClient(fetch: HTTP.urlSession), routes: RouteClient(fetch: HTTP.urlSession))
    private let notifier = Notifier()
    private var statusItem: StatusItemController?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = StatusItemController(tracker: tracker, settings: settings) { [weak self] in
            self?.showSettings()
        }
        tracker.onNewPlane = { [weak self] sighting in
            guard let self else { return }
            statusItem?.planeAppeared(sighting)
            let cardVisible = statusItem?.isPopoverShown ?? false
            if settings.notificationsEnabled, !cardVisible { notifier.post(sighting) }
        }
        applySettings()
        tracker.start()
        if settings.home == nil { showSettings() }
    }

    /// Pushes settings into the tracker now and again whenever any of them change.
    private func applySettings() {
        withObservationTracking {
            tracker.configure(home: settings.home, criteria: settings.criteria, quietHours: settings.quietHours)
        } onChange: { [weak self] in
            Task { @MainActor in self?.applySettings() }
        }
    }

    private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(settings: settings, notifier: notifier)))
            window.title = "Overflight Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        NSApp.activate()
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

import AppKit
import FlightKit
import Observation
import OSLog
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
    private var skyLogWindow: NSWindow?
    private let skyLogStore = SkyLogStore.standard
    private var savedLastPassID: UUID?
    private var skyLogSavedAt = Date.distantPast
    private var pendingSkyLogSave: Task<Void, Never>?
    /// While a plane is in view the log changes every poll; this caps disk writes for those updates.
    private static let skyLogSaveInterval: TimeInterval = 60

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = StatusItemController(
            tracker: tracker,
            settings: settings,
            openSettings: { [weak self] in self?.showSettings() },
            openSkyLog: { [weak self] in self?.showSkyLog() }
        )
        tracker.restore(skyLogStore.load())
        savedLastPassID = tracker.skyLog.passes.last?.id
        saveSkyLogWhenItChanges()
        tracker.onNewPlane = { [weak self] sighting in
            guard let self else { return }
            statusItem?.planeAppeared(sighting)
            let cardVisible = statusItem?.isPopoverShown ?? false
            let rarity = Rarity.of(sighting.plane.aircraft)
            if settings.notificationScope.includes(rarity: rarity), !cardVisible {
                notifier.post(sighting, rarity: rarity)
            }
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

    func applicationWillTerminate(_ notification: Notification) {
        saveSkyLog()
    }

    /// Saves right away when a new pass starts, and at most once a minute while one is being updated.
    private func saveSkyLogWhenItChanges() {
        withObservationTracking {
            _ = tracker.skyLog
        } onChange: { [weak self] in
            Task { @MainActor in self?.skyLogChanged() }
        }
    }

    /// Changes held back by the once-a-minute cap get a trailing save, so a pass's closest approach is on
    /// disk soon after the plane leaves view instead of waiting for the next plane or a clean quit.
    private func skyLogChanged() {
        let newPass = tracker.skyLog.passes.last?.id != savedLastPassID
        let sinceSave = Date.now.timeIntervalSince(skyLogSavedAt)
        if newPass || sinceSave >= Self.skyLogSaveInterval {
            saveSkyLog()
        } else if pendingSkyLogSave == nil {
            pendingSkyLogSave = Task { [weak self] in
                try? await Task.sleep(for: .seconds(Self.skyLogSaveInterval - sinceSave))
                guard !Task.isCancelled else { return }
                self?.saveSkyLog()
            }
        }
        saveSkyLogWhenItChanges()
    }

    private func saveSkyLog() {
        pendingSkyLogSave?.cancel()
        pendingSkyLogSave = nil
        do {
            try skyLogStore.save(tracker.skyLog)
            savedLastPassID = tracker.skyLog.passes.last?.id
            skyLogSavedAt = .now
        } catch {
            Logger(subsystem: "com.andrikanich.Overflight", category: "SkyLog")
                .error("Couldn't save the sky log: \(error.localizedDescription)")
        }
    }

    private func showSettings() {
        if settingsWindow == nil {
            settingsWindow = Self.window("Overflight Settings", SettingsView(settings: settings, notifier: notifier))
        }
        bringForward(settingsWindow)
    }

    private func showSkyLog() {
        if skyLogWindow == nil {
            skyLogWindow = Self.window("Sky Log", SkyLogView(tracker: tracker))
        }
        bringForward(skyLogWindow)
    }

    private static func window(_ title: String, _ content: some View) -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: content))
        window.title = title
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        return window
    }

    private func bringForward(_ window: NSWindow?) {
        NSApp.activate()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}

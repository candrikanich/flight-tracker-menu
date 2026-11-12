import FlightKit
import MapKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let notifier: Notifier

    var body: some View {
        Form {
            LocationSection(settings: settings)
            MenuBarSection(settings: settings)
            TrafficSection(settings: settings)
            NotificationsSection(settings: settings, notifier: notifier)
            QuietHoursSection(settings: settings)
            LaunchAtLoginSection()
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 720)
    }
}

private struct LocationSection: View {
    @Bindable var settings: AppSettings
    @State private var address = ""
    @State private var pin: CLLocationCoordinate2D?
    @State private var elevationFeet: Double?
    @State private var camera: MapCameraPosition = .automatic
    @State private var message: String?
    /// One lookup at a time: a second click can't race the first and leave the wrong elevation behind.
    @State private var lookingUpElevation = false

    private static let cleveland = CLLocationCoordinate2D(latitude: 41.4117, longitude: -81.8498)

    var body: some View {
        Section("Home location") {
            HStack {
                TextField("Address", text: $address).onSubmit(findAddress)
                Button("Find", action: findAddress).disabled(address.isEmpty || lookingUpElevation)
            }
            MapReader { proxy in
                Map(position: $camera) {
                    if let pin { Marker("Home", systemImage: "house.fill", coordinate: pin) }
                }
                .onTapGesture { point in
                    if let coordinate = proxy.convert(point, from: .local) { setPin(coordinate) }
                }
            }
            .frame(height: 200)
            .allowsHitTesting(!lookingUpElevation)
            .opacity(lookingUpElevation ? 0.6 : 1)
            Text("Click the map to place or move your house.").font(.caption).foregroundStyle(.secondary)
            TextField("Ground elevation (ft)", value: $elevationFeet, format: .number.precision(.fractionLength(0)))
            if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
            if isSaved {
                Label("Home saved. Overflight uses it every time it starts.", systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button("Save location", action: save)
                .disabled(draft == nil || isSaved || lookingUpElevation)
        }
        .onAppear(perform: loadSaved)
    }

    private var draft: Home? {
        guard let pin, let elevationFeet else { return nil }
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        return Home(
            coordinate: Coordinate(latitude: pin.latitude, longitude: pin.longitude),
            groundElevationFeet: elevationFeet,
            address: trimmed.isEmpty ? nil : trimmed
        )
    }

    private var isSaved: Bool { draft != nil && draft == settings.home }

    private func loadSaved() {
        guard let home = settings.home else {
            camera = .region(MKCoordinateRegion(center: Self.cleveland, latitudinalMeters: 20_000, longitudinalMeters: 20_000))
            return
        }
        let coordinate = CLLocationCoordinate2D(latitude: home.coordinate.latitude, longitude: home.coordinate.longitude)
        pin = coordinate
        elevationFeet = home.groundElevationFeet
        address = home.address ?? ""
        camera = .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 3_000, longitudinalMeters: 3_000))
    }

    private func findAddress() {
        Task {
            guard let request = MKGeocodingRequest(addressString: address),
                  let location = try? await request.mapItems.first?.location else {
                message = "Couldn't find that address. Try clicking the map instead."
                return
            }
            setPin(location.coordinate)
            camera = .region(MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 3_000, longitudinalMeters: 3_000))
        }
    }

    private func setPin(_ coordinate: CLLocationCoordinate2D) {
        guard !lookingUpElevation else { return }
        pin = coordinate
        lookingUpElevation = true
        message = "Looking up ground elevation…"
        Task {
            defer { lookingUpElevation = false }
            let client = ElevationClient(fetch: HTTP.urlSession)
            let target = Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
            if let feet = try? await client.groundElevationFeet(at: target) {
                elevationFeet = feet.rounded()
                message = nil
            } else {
                message = "Couldn't look up elevation. Enter it yourself (Cleveland area is about 750 ft)."
            }
        }
    }

    private func save() {
        guard let draft else { return }
        settings.home = draft
        message = nil
    }
}

private struct MenuBarSection: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Section("Menu bar") {
            Picker("Style", selection: $settings.style) {
                ForEach(MenuBarStyle.allCases) { style in
                    VStack(alignment: .leading) {
                        Text(style.title)
                        Text(style.detail).font(.caption).foregroundStyle(.secondary)
                    }
                    .tag(style)
                }
            }
            .pickerStyle(.radioGroup)
        }
    }
}

private struct TrafficSection: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Section("Traffic") {
            Picker("Show", selection: $settings.criteria.filter) {
                Text("Airport traffic (below 10,000 ft)").tag(TrafficFilter.airport)
                Text("Passing over (above 10,000 ft)").tag(TrafficFilter.passingOver)
                Text("All traffic").tag(TrafficFilter.all)
            }
            Stepper(value: $settings.criteria.radiusMiles, in: 0.5...5, step: 0.5) {
                Text("Low-traffic range: \(settings.criteria.radiusMiles.formatted()) mi")
            }
        }
    }
}

private struct NotificationsSection: View {
    @Bindable var settings: AppSettings
    let notifier: Notifier
    @State private var denied = false

    private var cardIsTheAlert: Bool { settings.style == .autoOpenCard }

    var body: some View {
        Section("Notifications") {
            Toggle("Silent banner when a plane comes overhead", isOn: Binding(
                get: { settings.notificationsEnabled },
                set: { enable in
                    guard enable else {
                        settings.notificationsEnabled = false
                        return
                    }
                    Task {
                        let granted = await notifier.requestAuthorization()
                        settings.notificationsEnabled = granted
                        denied = !granted
                    }
                }
            ))
            .disabled(cardIsTheAlert)
            if cardIsTheAlert {
                let style = MenuBarStyle.autoOpenCard.title
                Text("With \"\(style)\" the card opening is the alert, so no banners are sent.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if denied {
                Text("Notifications are turned off for Overflight in System Settings.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct QuietHoursSection: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Section("Quiet hours") {
            Toggle("Stay idle during quiet hours", isOn: $settings.quietHours.isEnabled)
            DatePicker("From", selection: minutes(\.startMinutes), displayedComponents: .hourAndMinute)
                .disabled(!settings.quietHours.isEnabled)
            DatePicker("Until", selection: minutes(\.endMinutes), displayedComponents: .hourAndMinute)
                .disabled(!settings.quietHours.isEnabled)
        }
    }

    private func minutes(_ keyPath: WritableKeyPath<QuietHours, Int>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: settings.quietHours[keyPath: keyPath] / 60,
                                      minute: settings.quietHours[keyPath: keyPath] % 60, second: 0, of: .now) ?? .now
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                settings.quietHours[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }
}

private struct LaunchAtLoginSection: View {
    @State private var enabled = SMAppService.mainApp.status == .enabled
    @State private var error: String?

    var body: some View {
        Section {
            Toggle("Launch at login", isOn: Binding(
                get: { enabled },
                set: { enable in
                    do {
                        try enable ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                        error = nil
                    } catch {
                        self.error = error.localizedDescription
                    }
                    enabled = SMAppService.mainApp.status == .enabled
                }
            ))
            if let error { Text(error).font(.caption).foregroundStyle(.secondary) }
        }
        .onAppear { enabled = SMAppService.mainApp.status == .enabled }
    }
}

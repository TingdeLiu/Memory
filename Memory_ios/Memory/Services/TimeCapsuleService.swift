import Foundation
import SwiftData
import CoreLocation
import UserNotifications

@Observable
final class TimeCapsuleService: NSObject {
    static let shared = TimeCapsuleService()

    private let locationManager = CLLocationManager()
    private(set) var monitoredCapsuleIds: Set<UUID> = []
    private(set) var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined

    private override init() {
        super.init()
        locationManager.delegate = self
        locationAuthorizationStatus = locationManager.authorizationStatus
    }

    // MARK: - Notification Permission

    func requestNotificationPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // MARK: - Date Unlock (P0)

    func scheduleNotification(for capsule: TimeCapsule) {
        guard capsule.unlockType == .date, let unlockDate = capsule.unlockDate else { return }
        guard unlockDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "capsule.notification.title")
        content.body = String(localized: "capsule.notification.body")
        content.sound = .default
        content.userInfo = ["capsuleId": capsule.id.uuidString]

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: unlockDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "capsule-\(capsule.id.uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func cancelNotification(for capsuleId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["capsule-\(capsuleId.uuidString)"]
        )
    }

    func checkDateUnlocks(modelContext: ModelContext) {
        let now = Date()
        let descriptor = FetchDescriptor<TimeCapsule>(
            predicate: #Predicate<TimeCapsule> { capsule in
                capsule.isUnlocked == false && capsule.unlockDate != nil
            }
        )

        guard let capsules = try? modelContext.fetch(descriptor) else { return }

        for capsule in capsules where capsule.unlockType == .date {
            if let unlockDate = capsule.unlockDate, now >= unlockDate {
                capsule.unlock()
            }
        }
    }

    // MARK: - Location Unlock (P1)

    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestAlwaysLocationPermission() {
        locationManager.requestAlwaysAuthorization()
    }

    func startMonitoring(capsule: TimeCapsule) {
        guard capsule.unlockType == .location,
              let lat = capsule.unlockLatitude,
              let lng = capsule.unlockLongitude,
              let radius = capsule.unlockRadius,
              CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self)
        else { return }

        // iOS limits to 20 regions
        if locationManager.monitoredRegions.count >= 20 {
            // Remove oldest monitored region
            if let oldest = locationManager.monitoredRegions.first {
                locationManager.stopMonitoring(for: oldest)
            }
        }

        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
            radius: min(radius, locationManager.maximumRegionMonitoringDistance),
            identifier: capsule.id.uuidString
        )
        region.notifyOnEntry = true
        region.notifyOnExit = false

        locationManager.startMonitoring(for: region)
        monitoredCapsuleIds.insert(capsule.id)
    }

    func stopMonitoring(capsule: TimeCapsule) {
        let identifier = capsule.id.uuidString
        for region in locationManager.monitoredRegions where region.identifier == identifier {
            locationManager.stopMonitoring(for: region)
        }
        monitoredCapsuleIds.remove(capsule.id)
    }

    func handleRegionEntry(identifier: String, modelContext: ModelContext) {
        guard let capsuleId = UUID(uuidString: identifier) else { return }
        let descriptor = FetchDescriptor<TimeCapsule>(
            predicate: #Predicate<TimeCapsule> { capsule in
                capsule.isUnlocked == false
            }
        )

        guard let capsules = try? modelContext.fetch(descriptor) else { return }
        if let capsule = capsules.first(where: { $0.id == capsuleId }) {
            capsule.unlock()
            stopMonitoring(capsule: capsule)

            // Send notification
            let content = UNMutableNotificationContent()
            content.title = String(localized: "capsule.notification.title")
            content.body = String(localized: "capsule.notification.locationBody")
            content.sound = .default
            content.userInfo = ["capsuleId": capsuleId.uuidString]

            let request = UNNotificationRequest(
                identifier: "capsule-arrived-\(capsuleId.uuidString)",
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    // MARK: - Event Unlock (P2)

    func unlockManually(capsule: TimeCapsule, modelContext: ModelContext) {
        guard !capsule.isUnlocked else { return }
        capsule.unlock()
        cancelNotification(for: capsule.id)
        stopMonitoring(capsule: capsule)
    }

    // MARK: - Countdown Helpers

    func timeRemaining(for capsule: TimeCapsule) -> TimeInterval? {
        guard let target = capsule.countdownTarget else { return nil }
        let remaining = target.timeIntervalSince(Date())
        return remaining > 0 ? remaining : nil
    }

    func formattedCountdown(for capsule: TimeCapsule) -> String {
        guard let remaining = timeRemaining(for: capsule) else {
            return String(localized: "capsule.countdown.ready")
        }

        let days = Int(remaining) / 86400
        let hours = (Int(remaining) % 86400) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        if days > 0 {
            return String(localized: "capsule.countdown.daysHours \(days) \(hours)")
        } else if hours > 0 {
            return String(localized: "capsule.countdown.hoursMinutes \(hours) \(minutes)")
        } else {
            return String(localized: "capsule.countdown.minutes \(minutes)")
        }
    }

    // MARK: - Startup

    func setupMonitoring(modelContext: ModelContext) {
        // Check date unlocks
        checkDateUnlocks(modelContext: modelContext)

        // Re-register geofences for location capsules
        let descriptor = FetchDescriptor<TimeCapsule>(
            predicate: #Predicate<TimeCapsule> { capsule in
                capsule.isUnlocked == false
            }
        )

        guard let capsules = try? modelContext.fetch(descriptor) else { return }
        for capsule in capsules where capsule.unlockType == .location {
            startMonitoring(capsule: capsule)
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension TimeCapsuleService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationAuthorizationStatus = manager.authorizationStatus
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        // Note: modelContext must be provided by the caller in the view layer
        // This is handled via a notification pattern
        NotificationCenter.default.post(
            name: .capsuleRegionEntered,
            object: nil,
            userInfo: ["regionIdentifier": region.identifier]
        )
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        if let region {
            monitoredCapsuleIds.remove(UUID(uuidString: region.identifier) ?? UUID())
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let capsuleRegionEntered = Notification.Name("capsuleRegionEntered")
}

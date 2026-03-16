import Foundation
import UIKit

@Observable
final class FeedbackService {
    static let shared = FeedbackService()

    let feedbackEmail = "feedback@tyndall.com"  // Replace with actual email

    private init() {}

    // MARK: - Device Info

    var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }

    var iOSVersion: String {
        UIDevice.current.systemVersion
    }

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var locale: String {
        Locale.current.identifier
    }

    // MARK: - Submit Feedback

    func submitFeedback(
        type: FeedbackType,
        content: String,
        email: String?,
        includeDeviceInfo: Bool
    ) async throws {
        // Build feedback payload
        var payload: [String: Any] = [
            "type": type.rawValue,
            "content": content,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "locale": locale
        ]

        if let email = email, !email.isEmpty {
            payload["email"] = email
        }

        if includeDeviceInfo {
            payload["device"] = [
                "model": deviceModel,
                "ios_version": iOSVersion,
                "app_version": appVersion
            ]
        }

        // Option 1: Send to your backend API
        // try await sendToAPI(payload)

        // Option 2: Store locally for now (can be synced later)
        try await storeLocally(payload)

        // Option 3: Send via Firebase/Analytics (if integrated)
        // Analytics.logEvent("feedback_submitted", parameters: payload)
    }

    // MARK: - Email Helpers

    func emailSubject(for type: FeedbackType) -> String {
        "[Memory Feedback] \(type.label)"
    }

    func emailBody(
        content: String,
        type: FeedbackType,
        email: String,
        includeDeviceInfo: Bool
    ) -> String {
        var body = """
        Feedback Type: \(type.label)

        \(content)

        """

        if !email.isEmpty {
            body += "\nContact Email: \(email)"
        }

        if includeDeviceInfo {
            body += """

            ---
            Device Info:
            - Device: \(deviceModel)
            - iOS: \(iOSVersion)
            - App Version: \(appVersion)
            - Locale: \(locale)
            """
        }

        return body
    }

    // MARK: - Local Storage

    private func storeLocally(_ payload: [String: Any]) async throws {
        let feedbackDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Feedback", isDirectory: true)

        // Create directory if needed
        try FileManager.default.createDirectory(at: feedbackDir, withIntermediateDirectories: true)

        // Save feedback as JSON file
        let filename = "feedback_\(UUID().uuidString).json"
        let fileURL = feedbackDir.appendingPathComponent(filename)

        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: fileURL)
    }

    // MARK: - API Integration (Template)

    private func sendToAPI(_ payload: [String: Any]) async throws {
        // Implement your API endpoint here
        // Example:
        /*
        guard let url = URL(string: "https://api.yourapp.com/feedback") else {
            throw FeedbackError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw FeedbackError.serverError
        }
        */
    }

    // MARK: - Get Pending Feedback

    func getPendingFeedback() -> [URL] {
        let feedbackDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Feedback", isDirectory: true)

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: feedbackDir,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        return files.filter { $0.pathExtension == "json" }
    }

    // MARK: - Sync Pending Feedback

    func syncPendingFeedback() async {
        let pendingFiles = getPendingFeedback()

        for fileURL in pendingFiles {
            do {
                let data = try Data(contentsOf: fileURL)
                guard let _ = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    continue
                }

                // Try to send to API
                // try await sendToAPI(payload)

                // Delete local file after successful sync
                try FileManager.default.removeItem(at: fileURL)
            } catch {
                // Keep file for next sync attempt
                continue
            }
        }
    }
}

// MARK: - Errors

enum FeedbackError: LocalizedError {
    case invalidURL
    case serverError
    case encodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(localized: "feedback.error.invalid_url")
        case .serverError:
            return String(localized: "feedback.error.server")
        case .encodingError:
            return String(localized: "feedback.error.encoding")
        }
    }
}

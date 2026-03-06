import Foundation
import Contacts

/// Represents a contact fetched from the system address book.
struct SystemContact: Identifiable {
    let id: String
    let name: String
    let thumbnailData: Data?
    let phoneNumber: String?
    let emailAddress: String?
}

/// Handles importing contacts from the system address book.
final class ContactImportService: ObservableObject {
    @Published var systemContacts: [SystemContact] = []
    @Published var isLoading = false
    @Published var permissionStatus: PermissionStatus = .unknown

    enum PermissionStatus {
        case unknown
        case authorized
        case denied
        case restricted
    }

    enum ContactImportError: LocalizedError {
        case accessDenied
        case fetchFailed(Error)

        var errorDescription: String? {
            switch self {
            case .accessDenied:
                return "Access to contacts was denied. Please enable it in Settings > Privacy > Contacts."
            case .fetchFailed(let error):
                return "Failed to fetch contacts: \(error.localizedDescription)"
            }
        }
    }

    /// Check the current permission status without prompting.
    func checkPermission() {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .authorized:
            permissionStatus = .authorized
        case .denied:
            permissionStatus = .denied
        case .restricted:
            permissionStatus = .restricted
        case .notDetermined:
            permissionStatus = .unknown
        @unknown default:
            permissionStatus = .unknown
        }
    }

    /// Request access to the user's contacts.
    func requestAccess() async throws -> Bool {
        let store = CNContactStore()
        let granted = try await store.requestAccess(for: .contacts)
        await MainActor.run {
            permissionStatus = granted ? .authorized : .denied
        }
        return granted
    }

    /// Fetch all contacts from the system address book.
    func fetchSystemContacts() async throws {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }

        let store = CNContactStore()
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
        ]

        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        request.sortOrder = .givenName
        var results: [SystemContact] = []

        try store.enumerateContacts(with: request) { cnContact, _ in
            let fullName = [cnContact.givenName, cnContact.familyName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            guard !fullName.isEmpty else { return }

            let phone = cnContact.phoneNumbers.first?.value.stringValue
            let email = cnContact.emailAddresses.first?.value as String?

            results.append(SystemContact(
                id: cnContact.identifier,
                name: fullName,
                thumbnailData: cnContact.thumbnailImageData,
                phoneNumber: phone,
                emailAddress: email
            ))
        }

        await MainActor.run {
            systemContacts = results
        }
    }

    /// Filter out contacts that already exist in the app (by systemContactId).
    func filterNew(systemContacts: [SystemContact], existingIds: Set<String>) -> [SystemContact] {
        systemContacts.filter { !existingIds.contains($0.id) }
    }
}

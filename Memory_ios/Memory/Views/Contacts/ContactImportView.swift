import SwiftUI
import SwiftData

struct ContactImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var existingContacts: [Contact]

    @StateObject private var importService = ContactImportService()
    @State private var selectedIds: Set<String> = []
    @State private var searchText = ""
    @State private var defaultRelationship: Relationship = .friend
    @State private var showingRelationshipPicker = false
    @State private var importError: String?

    private var existingSystemIds: Set<String> {
        Set(existingContacts.compactMap(\.systemContactId))
    }

    private var availableContacts: [SystemContact] {
        let filtered = importService.filterNew(
            systemContacts: importService.systemContacts,
            existingIds: existingSystemIds
        )
        if searchText.isEmpty { return filtered }
        return filtered.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var alreadyImportedCount: Int {
        importService.systemContacts.count - importService.filterNew(
            systemContacts: importService.systemContacts,
            existingIds: existingSystemIds
        ).count
    }

    var body: some View {
        NavigationStack {
            Group {
                switch importService.permissionStatus {
                case .unknown:
                    permissionRequest
                case .denied, .restricted:
                    permissionDenied
                case .authorized:
                    if importService.isLoading {
                        ProgressView(String(localized: "contactImport.loading"))
                    } else {
                        contactSelectionList
                    }
                }
            }
            .navigationTitle(String(localized: "contactImport.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if importService.permissionStatus == .authorized {
                        Button(L10n.contactImportButton(selectedIds.count)) {
                            importSelected()
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .disabled(selectedIds.isEmpty)
                    }
                }
            }
            .task {
                importService.checkPermission()
                if importService.permissionStatus == .authorized {
                    try? await importService.fetchSystemContacts()
                }
            }
        }
    }

    // MARK: - Permission Request

    private var permissionRequest: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(.accent)

            Text(String(localized: "contactImport.permission.title"))
                .font(.title2)
                .fontWeight(.bold)

            Text(String(localized: "contactImport.permission.description"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                Task {
                    do {
                        let granted = try await importService.requestAccess()
                        if granted {
                            try? await importService.fetchSystemContacts()
                        }
                    } catch {
                        importError = error.localizedDescription
                    }
                }
            } label: {
                Text(String(localized: "contactImport.allowAccess"))
                    .font(.headline)
                    .frame(maxWidth: 240)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
    }

    // MARK: - Permission Denied

    private var permissionDenied: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "lock.shield")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text(String(localized: "contactImport.denied.title"))
                .font(.title2)
                .fontWeight(.bold)

            Text(String(localized: "contactImport.denied.description"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text(String(localized: "contactImport.openSettings"))
                    .font(.headline)
                    .frame(maxWidth: 240)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .padding()
    }

    // MARK: - Selection List

    private var contactSelectionList: some View {
        List {
            // Default relationship
            Section {
                Picker(String(localized: "contactImport.importAs"), selection: $defaultRelationship) {
                    ForEach(Relationship.allCases, id: \.self) { rel in
                        Label(rel.label, systemImage: rel.icon).tag(rel)
                    }
                }
            } footer: {
                Text(String(localized: "contactImport.importAsFooter"))
            }

            // Selection controls
            Section {
                HStack {
                    Text(L10n.contactsAvailable(availableContacts.count))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !availableContacts.isEmpty {
                        Button(selectedIds.count == availableContacts.count ? String(localized: "contactImport.deselectAll") : String(localized: "contactImport.selectAll")) {
                            if selectedIds.count == availableContacts.count {
                                selectedIds.removeAll()
                            } else {
                                selectedIds = Set(availableContacts.map(\.id))
                            }
                        }
                        .font(.subheadline)
                    }
                }

                if alreadyImportedCount > 0 {
                    Label(L10n.alreadyImported(alreadyImportedCount), systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            // Contacts
            Section {
                if availableContacts.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else if availableContacts.isEmpty {
                    Text(String(localized: "contactImport.allImported"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                } else {
                    ForEach(availableContacts) { sysContact in
                        SystemContactRow(
                            contact: sysContact,
                            isSelected: selectedIds.contains(sysContact.id),
                            onToggle: {
                                if selectedIds.contains(sysContact.id) {
                                    selectedIds.remove(sysContact.id)
                                } else {
                                    selectedIds.insert(sysContact.id)
                                }
                            }
                        )
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: String(localized: "contactImport.search.prompt"))
    }

    // MARK: - Import

    private func importSelected() {
        let toImport = importService.systemContacts.filter { selectedIds.contains($0.id) }
        for sysContact in toImport {
            let contact = Contact(
                name: sysContact.name,
                relationship: defaultRelationship,
                importSource: .systemContacts,
                systemContactId: sysContact.id
            )
            contact.avatarData = sysContact.thumbnailData
            modelContext.insert(contact)
        }
    }
}

// MARK: - System Contact Row

struct SystemContactRow: View {
    let contact: SystemContact
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                if let data = contact.thumbnailData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Text(contact.name.prefix(1).uppercased())
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    if let phone = contact.phoneNumber {
                        Text(phone)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .accent : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContactImportView()
        .modelContainer(for: [MemoryEntry.self, Contact.self, Message.self], inMemory: true)
}

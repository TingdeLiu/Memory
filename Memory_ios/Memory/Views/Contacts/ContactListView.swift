import SwiftUI
import SwiftData

struct ContactListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Contact._plainName) private var contacts: [Contact]
    @State private var searchText = ""
    @State private var selectedRelationship: Relationship?
    @State private var showingAddContact = false
    @State private var showingImportSheet = false
    @State private var showFavoritesOnly = false

    private var filteredContacts: [Contact] {
        var result = contacts
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.notes.localizedCaseInsensitiveContains(searchText)
            }
        }
        if let rel = selectedRelationship {
            result = result.filter { $0.relationship == rel }
        }
        if showFavoritesOnly {
            result = result.filter { $0.isFavorite }
        }
        return result
    }

    private var favoriteContacts: [Contact] {
        filteredContacts.filter { $0.isFavorite }
    }

    private var nonFavoriteGrouped: [(Relationship, [Contact])] {
        let nonFavorites = filteredContacts.filter { !$0.isFavorite }
        let grouped = Dictionary(grouping: nonFavorites, by: \.relationship)
        return Relationship.allCases.compactMap { rel in
            guard let list = grouped[rel], !list.isEmpty else { return nil }
            return (rel, list)
        }
    }

    private var activeFilterCount: Int {
        (selectedRelationship != nil ? 1 : 0) + (showFavoritesOnly ? 1 : 0)
    }

    var body: some View {
        NavigationStack {
            Group {
                if contacts.isEmpty {
                    emptyState
                } else {
                    contactList
                }
            }
            .navigationTitle(String(localized: "contactList.title"))
            .searchable(text: $searchText, prompt: String(localized: "contactList.search.prompt"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingAddContact = true
                        } label: {
                            Label(String(localized: "contactList.addManually"), systemImage: "person.badge.plus")
                        }
                        Button {
                            showingImportSheet = true
                        } label: {
                            Label(String(localized: "contactList.importContacts"), systemImage: "person.crop.circle.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAddContact) {
                ContactEditorView()
            }
            .sheet(isPresented: $showingImportSheet) {
                ContactImportView()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "person.2.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor.opacity(0.6))

            VStack(spacing: 8) {
                Text(String(localized: "contactList.empty.title"))
                    .font(.title2)
                    .fontWeight(.bold)

                Text(String(localized: "contactList.empty.subtitle"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                Button {
                    showingImportSheet = true
                } label: {
                    Label(String(localized: "contactList.importContacts"), systemImage: "person.crop.circle.badge.plus")
                        .font(.headline)
                        .frame(maxWidth: 260)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    showingAddContact = true
                } label: {
                    Label(String(localized: "contactList.addManually"), systemImage: "person.badge.plus")
                        .font(.subheadline)
                }
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding()
    }

    // MARK: - Contact List

    private var contactList: some View {
        List {
            // Filter bar
            filterBar
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

            // Stats
            if searchText.isEmpty && !showFavoritesOnly && selectedRelationship == nil {
                contactStats
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            // Favorites
            if !favoriteContacts.isEmpty && !showFavoritesOnly {
                Section {
                    ForEach(favoriteContacts) { contact in
                        NavigationLink(destination: ContactDetailView(contact: contact)) {
                            ContactRowView(contact: contact)
                        }
                    }
                    .onDelete { offsets in
                        deleteContacts(from: favoriteContacts, at: offsets)
                    }
                } header: {
                    Label(String(localized: "contactList.favorites"), systemImage: "star.fill")
                }
            }

            // Grouped by relationship
            if filteredContacts.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ForEach(showFavoritesOnly ? [] : nonFavoriteGrouped, id: \.0) { relationship, list in
                    Section {
                        ForEach(list) { contact in
                            NavigationLink(destination: ContactDetailView(contact: contact)) {
                                ContactRowView(contact: contact)
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    contact.isFavorite.toggle()
                                } label: {
                                    Label(
                                        contact.isFavorite ? String(localized: "contactList.unfavorite") : String(localized: "contactList.favorite"),
                                        systemImage: contact.isFavorite ? "star.slash" : "star.fill"
                                    )
                                }
                                .tint(.yellow)
                            }
                            .sensoryFeedback(.selection, trigger: contact.isFavorite)
                        }
                        .onDelete { offsets in
                            deleteContacts(from: list, at: offsets)
                        }
                    } header: {
                        HStack {
                            Label(relationship.label, systemImage: relationship.icon)
                            Spacer()
                            Text("\(list.count)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        label: String(localized: "common.all"),
                        isSelected: selectedRelationship == nil && !showFavoritesOnly
                    ) {
                        selectedRelationship = nil
                        showFavoritesOnly = false
                    }

                    FilterChip(
                        label: String(localized: "contactList.favorites"),
                        isSelected: showFavoritesOnly
                    ) {
                        showFavoritesOnly.toggle()
                        if showFavoritesOnly { selectedRelationship = nil }
                    }

                    ForEach(Relationship.allCases, id: \.self) { rel in
                        let count = contacts.filter { $0.relationship == rel }.count
                        if count > 0 {
                            FilterChip(
                                label: "\(rel.label) (\(count))",
                                isSelected: selectedRelationship == rel
                            ) {
                                showFavoritesOnly = false
                                selectedRelationship = selectedRelationship == rel ? nil : rel
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Stats

    private var contactStats: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                StatCard(
                    title: String(localized: "contactList.stats.people"),
                    value: "\(contacts.count)",
                    icon: "person.2",
                    color: Color.accentColor
                )

                let totalMessages = contacts.reduce(0) { $0 + $1.messages.count }
                StatCard(
                    title: String(localized: "contactList.stats.messages"),
                    value: "\(totalMessages)",
                    icon: "envelope",
                    color: .blue
                )

                let sealedCount = contacts.reduce(0) { $0 + $1.afterDeathMessageCount }
                if sealedCount > 0 {
                    StatCard(
                        title: String(localized: "contactList.stats.sealed"),
                        value: "\(sealedCount)",
                        icon: "infinity",
                        color: .purple
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
    }

    private func deleteContacts(from list: [Contact], at offsets: IndexSet) {
        for index in offsets {
            let contact = list[index]
            // Clean up audio files from messages
            for message in contact.messages {
                if let path = message.audioFilePath {
                    AudioRecordingService().deleteRecording(
                        at: AudioRecordingService.recordingURL(for: path)
                    )
                }
            }
            modelContext.delete(contact)
        }
    }
}

// MARK: - Contact Row View

struct ContactRowView: View {
    let contact: Contact

    var body: some View {
        HStack(spacing: 12) {
            ContactAvatarView(contact: contact, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(contact.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    if contact.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }

                HStack(spacing: 8) {
                    if !contact.messages.isEmpty {
                        Label(
                            "\(contact.messages.count)",
                            systemImage: "envelope"
                        )
                    }

                    if contact.afterDeathMessageCount > 0 {
                        Label(
                            L10n.sealedCount(contact.afterDeathMessageCount),
                            systemImage: "infinity"
                        )
                        .foregroundStyle(.purple)
                    }

                    if let latest = contact.latestMessage {
                        Text(latest.createdAt, style: .relative)
                            .foregroundStyle(.tertiary)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if contact.importSource == .systemContacts {
                Image(systemName: "person.crop.circle")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Contact Avatar View

struct ContactAvatarView: View {
    let contact: Contact
    let size: CGFloat

    private var relationshipColor: Color {
        switch contact.relationship {
        case .family: return .orange
        case .partner: return .pink
        case .friend: return .blue
        case .colleague: return .purple
        case .mentor: return .green
        case .other: return .gray
        }
    }

    var body: some View {
        Group {
            if let data = contact.avatarData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(relationshipColor.opacity(0.15))
                    .frame(width: size, height: size)
                    .overlay {
                        Text(contact.name.prefix(1).uppercased())
                            .font(.system(size: size * 0.4, weight: .semibold))
                            .foregroundStyle(relationshipColor)
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(contact.name), \(contact.relationship.label)")
    }
}

#Preview {
    ContactListView()
        .modelContainer(for: [MemoryEntry.self, Contact.self, Message.self], inMemory: true)
}

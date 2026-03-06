import SwiftUI
import SwiftData
import PhotosUI

struct ContactEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var existingContact: Contact?

    @State private var name = ""
    @State private var relationship: Relationship = .friend
    @State private var notes = ""
    @State private var isFavorite = false
    @State private var avatarData: Data?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingDeleteAlert = false

    private var isEditing: Bool { existingContact != nil }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // Avatar section
                Section {
                    VStack(spacing: 12) {
                        avatarPicker
                            .frame(maxWidth: .infinity)

                        TextField(String(localized: "contactEditor.name"), text: $name)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                    }
                    .listRowBackground(Color.clear)
                }

                // Relationship & Favorite
                Section {
                    Picker(String(localized: "contactEditor.relationship"), selection: $relationship) {
                        ForEach(Relationship.allCases, id: \.self) { rel in
                            Label(rel.label, systemImage: rel.icon).tag(rel)
                        }
                    }

                    Toggle(isOn: $isFavorite) {
                        Label(String(localized: "contactEditor.favorite"), systemImage: "star.fill")
                    }
                }

                // Notes
                Section(String(localized: "contactEditor.aboutSection")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                        .overlay(alignment: .topLeading) {
                            if notes.isEmpty {
                                Text(String(localized: "contactEditor.notesPlaceholder"))
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                // Delete
                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            Label(String(localized: "contactDetail.deleteContact"), systemImage: "trash")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    } footer: {
                        Text(String(localized: "contactEditor.deleteFooter"))
                    }
                }
            }
            .navigationTitle(isEditing ? String(localized: "contactEditor.editTitle") : String(localized: "contactEditor.newTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save")) {
                        save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        avatarData = data
                    }
                }
            }
            .alert(String(localized: "contactDetail.deleteTitle"), isPresented: $showingDeleteAlert) {
                Button(String(localized: "common.delete"), role: .destructive) {
                    if let contact = existingContact {
                        modelContext.delete(contact)
                    }
                    dismiss()
                }
                Button(String(localized: "common.cancel"), role: .cancel) {}
            } message: {
                Text(L10n.contactEditorDeleteMessage(existingContact?.name ?? ""))
            }
            .onAppear {
                if let contact = existingContact {
                    name = contact.name
                    relationship = contact.relationship
                    notes = contact.notes
                    isFavorite = contact.isFavorite
                    avatarData = contact.avatarData
                }
            }
        }
    }

    // MARK: - Avatar Picker

    private var avatarPicker: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                if let data = avatarData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 90, height: 90)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 90, height: 90)
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.secondary)
                        }
                }

                Circle()
                    .fill(.accent)
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "camera.fill")
                            .font(.caption2)
                            .foregroundStyle(.white)
                    }
                    .offset(x: 2, y: 2)
            }
        }
    }

    // MARK: - Save

    private func save() {
        if let contact = existingContact {
            contact.name = name
            contact.relationship = relationship
            contact.notes = notes
            contact.isFavorite = isFavorite
            contact.avatarData = avatarData
            contact.updatedAt = Date()
        } else {
            let contact = Contact(
                name: name,
                relationship: relationship,
                isFavorite: isFavorite,
                notes: notes
            )
            contact.avatarData = avatarData
            modelContext.insert(contact)
        }
    }
}

#Preview {
    ContactEditorView()
        .modelContainer(for: [MemoryEntry.self, Contact.self, Message.self], inMemory: true)
}

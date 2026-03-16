import SwiftUI
import SwiftData

struct ContactDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ContactDetailViewModel?
    private let contact: Contact

    init(contact: Contact) {
        self.contact = contact
    }

    var body: some View {
        ScrollView {
            if let vm = viewModel {
                VStack(spacing: 24) {
                    // Profile Header
                    profileHeader

                    // Condition Filter
                    conditionFilter

                    // Messages List
                    if vm.filteredMessages.isEmpty {
                        emptyMessagesState
                    } else {
                        messagesList
                    }
                }
                .padding()
            } else {
                ProgressView()
                    .padding()
            }
        }
        .navigationTitle(viewModel?.contact.name ?? contact.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    Button {
                        viewModel?.toggleFavorite()
                    } label: {
                        Image(systemName: viewModel?.contact.isFavorite == true ? "star.fill" : "star")
                            .foregroundStyle(viewModel?.contact.isFavorite == true ? .yellow : .accentColor)
                    }

                    Button {
                        viewModel?.toggleEditing()
                    } label: {
                        Text(viewModel?.isEditing == true ? String(localized: "common.save") : String(localized: "common.edit"))
                    }
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = ContactDetailViewModel(contact: contact, modelContext: modelContext)
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel?.showingMessageEditor ?? false },
            set: { viewModel?.showingMessageEditor = $0 }
        )) {
            if let vm = viewModel {
                MessageEditorView(contact: vm.contact)
            }
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 16) {
            ContactAvatarView(contact: viewModel?.contact ?? contact, size: 100)
                .shadow(radius: 5)

            VStack(spacing: 4) {
                if viewModel?.isEditing == true {
                    TextField(String(localized: "contact.name"), text: Binding(
                        get: { viewModel?.contact.name ?? "" },
                        set: { viewModel?.contact.name = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 200)
                } else {
                    Text(viewModel?.contact.name ?? contact.name)
                        .font(.title2)
                        .fontWeight(.bold)
                }

                RelationshipBadge(relationship: viewModel?.contact.relationship ?? contact.relationship)
            }

            if !(viewModel?.contact.notes.isEmpty ?? true) || viewModel?.isEditing == true {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "contact.notes"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    if viewModel?.isEditing == true {
                        TextEditor(text: Binding(
                            get: { viewModel?.contact.notes ?? "" },
                            set: { viewModel?.contact.notes = $0 }
                        ))
                        .frame(height: 80)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Text(viewModel?.contact.notes ?? "")
                            .font(.subheadline)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                viewModel?.showingMessageEditor = true
            } label: {
                Label(String(localized: "contact.writeMessage"), systemImage: "square.and.pencil")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var conditionFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                FilterChip(
                    label: String(localized: "filter.all"),
                    isSelected: viewModel?.selectedCondition == nil,
                    action: { viewModel?.selectedCondition = nil }
                )

                ForEach(DeliveryCondition.allCases, id: \.self) { condition in
                    FilterChip(
                        label: condition.label,
                        isSelected: viewModel?.selectedCondition == condition,
                        action: { viewModel?.selectedCondition = condition }
                    )
                }
            }
        }
    }

    private var emptyMessagesState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(String(localized: "contact.noMessages"))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var messagesList: some View {
        LazyVStack(spacing: 16) {
            ForEach(viewModel?.filteredMessages ?? []) { message in
                NavigationLink(destination: MessageDetailView(message: message)) {
                    MessageRowView(message: message)
                }
                .buttonStyle(PlainButtonStyle())
                .contextMenu {
                    Button(role: .destructive) {
                        viewModel?.deleteMessage(message)
                    } label: {
                        Label(String(localized: "common.delete"), systemImage: "trash")
                    }
                }
            }
        }
    }
}

struct RelationshipBadge: View {
    let relationship: Relationship
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: relationship.icon)
            Text(relationship.label)
        }
        .font(.caption)
        .fontWeight(.bold)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(relationship.color.opacity(0.1))
        .foregroundStyle(relationship.color)
        .clipShape(Capsule())
    }
}

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

struct MessageRowView: View {
    let message: Message
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: message.deliveryCondition.icon)
                        .font(.caption)
                    Text(message.deliveryCondition.label)
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .foregroundStyle(statusColor)
                
                if message.type == .audio {
                    Label(String(localized: "message.type.audio"), systemImage: "waveform")
                        .font(.subheadline)
                } else {
                    Text(message.content)
                        .font(.subheadline)
                        .lineLimit(2)
                }
                
                Text(message.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var statusColor: Color {
        switch message.deliveryCondition {
        case .immediate: return .green
        case .specificDate: return .orange
        case .afterDeath: return .purple
        }
    }
}


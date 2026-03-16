import SwiftUI
import SwiftData
import Observation

@Observable
final class ContactDetailViewModel {
    var contact: Contact
    var selectedCondition: DeliveryCondition?
    var showingMessageEditor = false
    var isEditing = false
    
    private var modelContext: ModelContext
    
    init(contact: Contact, modelContext: ModelContext) {
        self.contact = contact
        self.modelContext = modelContext
    }
    
    var filteredMessages: [Message] {
        if let condition = selectedCondition {
            return contact.messages.filter { $0.deliveryCondition == condition }
                .sorted { $0.createdAt > $1.createdAt }
        }
        return contact.sortedMessages
    }
    
    func deleteMessage(_ message: Message) {
        modelContext.delete(message)
        try? modelContext.save()
    }
    
    func toggleFavorite() {
        contact.isFavorite.toggle()
        try? modelContext.save()
    }
    
    func toggleEditing() {
        if isEditing {
            try? modelContext.save()
        }
        isEditing.toggle()
    }
}

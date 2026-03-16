import SwiftUI
import SwiftData
import Observation

@Observable
final class MemoryListViewModel {
    var searchText = ""
    var selectedType: MemoryType?
    var selectedMood: Mood?
    var sortOrder: SortOrder = .reverse
    var showingEditor = false
    
    private var modelContext: ModelContext
    
    enum SortOrder: String, CaseIterable {
        case forward = "oldest"
        case reverse = "newest"
        case alphabetical = "alphabetical"
        
        var label: String {
            switch self {
            case .forward: return String(localized: "sort.oldest")
            case .reverse: return String(localized: "sort.newest")
            case .alphabetical: return String(localized: "sort.alphabetical")
            }
        }
    }
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func filterAndSort(_ memories: [MemoryEntry]) -> [MemoryEntry] {
        var result = memories.filter { !$0.title.hasPrefix("[Draft] ") }
        
        // Type filter
        if let type = selectedType {
            result = result.filter { $0.type == type }
        }
        
        // Mood filter
        if let mood = selectedMood {
            result = result.filter { $0.mood == mood }
        }
        
        // Search filter
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.content.localizedCaseInsensitiveContains(searchText) ||
                $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // Sorting
        switch sortOrder {
        case .forward:
            result.sort { $0.createdAt < $1.createdAt }
        case .reverse:
            result.sort { $0.createdAt > $1.createdAt }
        case .alphabetical:
            result.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        
        return result
    }
    
    func deleteMemories(_ memoriesToDelete: [MemoryEntry]) {
        for memory in memoriesToDelete {
            modelContext.delete(memory)
        }
        try? modelContext.save()
    }
}

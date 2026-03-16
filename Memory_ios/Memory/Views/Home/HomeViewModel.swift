import SwiftUI
import SwiftData
import Observation

@Observable
final class HomeViewModel {
    var searchText = ""
    var showingDateFilter = false
    var dateFilterStart: Date?
    var dateFilterEnd: Date?
    var showingEditor = false
    var showingAIChat = false
    
    private var modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func filterMemories(_ memories: [MemoryEntry]) -> [MemoryEntry] {
        var result = memories.filter { !$0.title.hasPrefix("[Draft] ") }
        
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.content.localizedCaseInsensitiveContains(searchText) ||
                $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        if let start = dateFilterStart {
            result = result.filter { $0.createdAt >= start }
        }
        
        if let end = dateFilterEnd {
            let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: end) ?? end
            result = result.filter { $0.createdAt < nextDay }
        }
        
        return result
    }
    
    func groupMemories(_ filteredMemories: [MemoryEntry]) -> [(String, [MemoryEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredMemories) { entry -> String in
            if calendar.isDateInToday(entry.createdAt) {
                return String(localized: "home.date.today")
            } else if calendar.isDateInYesterday(entry.createdAt) {
                return String(localized: "home.date.yesterday")
            } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()),
                      entry.createdAt > weekAgo {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE"
                return formatter.string(from: entry.createdAt)
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM d, yyyy"
                return formatter.string(from: entry.createdAt)
            }
        }
        return grouped.sorted { $0.value[0].createdAt > $1.value[0].createdAt }
    }
    
    var hasDateFilter: Bool {
        dateFilterStart != nil || dateFilterEnd != nil
    }
    
    func clearDateFilter() {
        dateFilterStart = nil
        dateFilterEnd = nil
    }
}

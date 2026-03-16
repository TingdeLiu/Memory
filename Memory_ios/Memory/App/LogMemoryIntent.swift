import Foundation
import AppIntents
import SwiftData

struct LogMemoryIntent: AppIntent {
    static var title: LocalizedStringResource = "Record a Memory"
    static var description = IntentDescription("Saves a quick thought or memory directly into the app.")

    @Parameter(title: "Content", description: "What do you want to remember?")
    var content: String
    
    @Parameter(title: "Mood", description: "How are you feeling?", default: "calm")
    var moodString: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let modelContainer = try ModelContainer(for: MemoryEntry.self, SoulProfile.self)
        let context = ModelContext(modelContainer)
        
        let mood: Mood = Mood(rawValue: moodString.lowercased()) ?? .calm
        
        // Create new memory
        let entry = MemoryEntry(
            title: "Quick Note",
            content: content,
            type: .text,
            tags: ["siri", "quick_capture"],
            mood: mood
        )
        
        context.insert(entry)
        try context.save()
        
        return .result(value: "Memory saved successfully.")
    }
}

// MARK: - App Shortcuts Provider
// This registers the intent with Siri automatically

struct MemoryAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogMemoryIntent(),
            phrases: [
                "Log a memory in \(.applicationName)",
                "Record a thought in \(.applicationName)",
                "Save to \(.applicationName)"
            ],
            shortTitle: "Log Memory",
            systemImageName: "brain.head.profile"
        )
    }
}

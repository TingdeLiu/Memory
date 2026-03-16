import SwiftUI
import SwiftData
import Observation

@Observable
final class SoulProfileViewModel {
    var profile: SoulProfile
    var isEditing: Bool = false
    var isAnalyzing: Bool = false
    var showingEditSheet: Bool = false
    
    private var modelContext: ModelContext
    private var aiService: AIService
    
    init(profile: SoulProfile, modelContext: ModelContext, aiService: AIService = AIService()) {
        self.profile = profile
        self.modelContext = modelContext
        self.aiService = aiService
    }
    
    var hasBasicInfo: Bool {
        profile.nickname != nil || profile.birthday != nil ||
        profile.birthplace != nil || profile.currentCity != nil
    }
    
    var hasAIInsights: Bool {
        profile.personalityInsights != nil || profile.lifeStory != nil ||
        profile.emotionalPatterns != nil || profile.coreMemories != nil
    }
    
    func toggleEditing() {
        if isEditing {
            do {
                try modelContext.save()
            } catch {
                print("Failed to save profile: \(error)")
            }
        }
        isEditing.toggle()
    }
    
    func analyzeMemories(memories: [MemoryEntry]) async {
        guard !memories.isEmpty else { return }
        
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        await SoulService.shared.analyzeMemories(
            profile: profile,
            memories: memories,
            aiService: aiService,
            context: modelContext
        )
    }
}

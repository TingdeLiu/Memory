import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .home

    enum Tab: String {
        case home, memories, contacts, universe, soul, settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label(String(localized: "tab.home"), systemImage: "house.fill")
                }
                .tag(Tab.home)

            MemoryListView()
                .tabItem {
                    Label(String(localized: "tab.memories"), systemImage: "brain.head.profile")
                }
                .tag(Tab.memories)

            ContactListView()
                .tabItem {
                    Label(String(localized: "tab.contacts"), systemImage: "person.2.fill")
                }
                .tag(Tab.contacts)

            LightOrbUniverseView(showCloseButton: false)
                .tabItem {
                    Label(String(localized: "tab.universe"), systemImage: "globe.asia.australia.fill")
                }
                .tag(Tab.universe)

            SoulTabView()
                .tabItem {
                    Label(String(localized: "tab.soul"), systemImage: "person.crop.circle.badge.moon")
                }
                .tag(Tab.soul)

            SettingsView()
                .tabItem {
                    Label(String(localized: "tab.settings"), systemImage: "gearshape.fill")
                }
                .tag(Tab.settings)
        }
        .tint(.accentColor)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [MemoryEntry.self, Contact.self, Message.self, SoulProfile.self, InterviewSession.self, AssessmentResult.self, RelationshipProfile.self, VoiceProfile.self, VoiceSample.self, WritingStyleProfile.self, AvatarProfile.self, DigitalSelfConfig.self], inMemory: true)
}

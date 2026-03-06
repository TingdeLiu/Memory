import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .home

    enum Tab: String {
        case home, memories, contacts, ai, settings
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

            AIChatView()
                .tabItem {
                    Label(String(localized: "tab.ai"), systemImage: "sparkles")
                }
                .tag(Tab.ai)

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
        .modelContainer(for: [MemoryEntry.self, Contact.self, Message.self], inMemory: true)
}

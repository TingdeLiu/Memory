import SwiftUI
import WidgetKit

@main
struct MemoryWidgetBundle: WidgetBundle {
    var body: some Widget {
        RecentMemoryWidget()
        StatsWidget()
        CapsuleCountdownWidget()
    }
}

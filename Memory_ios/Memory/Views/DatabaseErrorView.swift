import SwiftUI

struct DatabaseErrorView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.yellow)

            Text(L10n.tr("database.error.title"))
                .font(.title2.bold())

            Text(L10n.tr("database.error.message"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                // Force quit and relaunch to retry
                exit(0)
            } label: {
                Label(L10n.tr("database.error.restart"), systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
        }
        .padding()
    }
}

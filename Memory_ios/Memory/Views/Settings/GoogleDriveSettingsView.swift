import SwiftUI

struct GoogleDriveSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var gdriveService = GoogleDriveSyncService.shared
    @AppStorage("googleDriveEnabled") private var googleDriveEnabled = false

    var body: some View {
        List {
            // Account
            Section {
                if gdriveService.isSignedIn {
                    HStack {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "gdrive.connected"))
                                    .font(.subheadline)
                                if let email = gdriveService.userEmail {
                                    Text(email)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }

                    Button(role: .destructive) {
                        gdriveService.signOut()
                        googleDriveEnabled = false
                    } label: {
                        Label(String(localized: "gdrive.signOut"), systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } else {
                    Button {
                        Task {
                            try? await gdriveService.signIn()
                            if gdriveService.isSignedIn {
                                googleDriveEnabled = true
                            }
                        }
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "gdrive.signIn"))
                                Text(String(localized: "gdrive.signInSubtitle"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "person.badge.key")
                        }
                    }
                }
            } header: {
                Text(String(localized: "gdrive.account"))
            } footer: {
                Text(String(localized: "gdrive.accountFooter"))
            }

            // Sync
            if gdriveService.isSignedIn {
                Section {
                    Toggle(isOn: $googleDriveEnabled) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "gdrive.enableSync"))
                                Text(String(localized: "gdrive.enableSyncSubtitle"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                    }

                    Button {
                        Task {
                            await gdriveService.sync(modelContainer: modelContext.container)
                        }
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "gdrive.syncNow"))
                                if gdriveService.isSyncing {
                                    Text(String(localized: "gdrive.syncing"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } icon: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(gdriveService.isSyncing)

                    if gdriveService.isSyncing {
                        ProgressView(value: gdriveService.syncProgress)
                            .padding(.vertical, 4)
                    }
                } header: {
                    Text(String(localized: "gdrive.sync"))
                }

                // Status
                Section {
                    if let lastSync = gdriveService.lastSyncDate {
                        HStack {
                            Text(String(localized: "gdrive.lastSynced"))
                            Spacer()
                            Text(lastSync, style: .relative)
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    } else {
                        HStack {
                            Text(String(localized: "gdrive.lastSynced"))
                            Spacer()
                            Text(String(localized: "gdrive.never"))
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }

                    if let error = gdriveService.syncError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                } header: {
                    Text(String(localized: "gdrive.status"))
                }

                // Security
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.green)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "gdrive.e2e"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(String(localized: "gdrive.e2eDescription"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text(String(localized: "gdrive.security"))
                }
            }
        }
        .navigationTitle(String(localized: "gdrive.title"))
    }
}

#Preview {
    NavigationStack {
        GoogleDriveSettingsView()
    }
}

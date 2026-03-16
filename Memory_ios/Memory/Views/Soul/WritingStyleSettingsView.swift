import SwiftUI
import SwiftData

struct WritingStyleSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var profile: WritingStyleProfile

    @State private var showingResetConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                // Status Section
                Section {
                    HStack {
                        Text(String(localized: "writing.settings.status"))
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: profile.status.icon)
                                .foregroundStyle(statusColor)
                            Text(profile.statusDescription)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let date = profile.lastAnalyzedAt {
                        HStack {
                            Text(String(localized: "writing.settings.last_analyzed"))
                            Spacer()
                            Text(date, style: .date)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if profile.isReady {
                        HStack {
                            Text(String(localized: "writing.settings.memories_analyzed"))
                            Spacer()
                            Text("\(profile.memoriesAnalyzed)")
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text(String(localized: "writing.settings.words_analyzed"))
                            Spacer()
                            Text("\(profile.totalWordsAnalyzed)")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text(String(localized: "writing.settings.status_section"))
                }

                // Features Section
                Section {
                    Toggle(String(localized: "writing.settings.enable"), isOn: $profile.isEnabled)

                    Text(String(localized: "writing.settings.enable_desc"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text(String(localized: "writing.settings.features_section"))
                } footer: {
                    Text(String(localized: "writing.settings.features_footer"))
                }

                // Statistics Section (when ready)
                if profile.isReady {
                    Section {
                        if let avgSentence = profile.avgSentenceLength {
                            HStack {
                                Text(String(localized: "writing.settings.avg_sentence"))
                                Spacer()
                                Text(String(localized: "writing.settings.words_count \(Int(avgSentence))"))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let avgParagraph = profile.avgParagraphLength {
                            HStack {
                                Text(String(localized: "writing.settings.avg_paragraph"))
                                Spacer()
                                Text(String(localized: "writing.settings.words_count \(Int(avgParagraph))"))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack {
                            Text(String(localized: "writing.settings.unique_words"))
                            Spacer()
                            Text("\(profile.topWords.count)")
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text(String(localized: "writing.settings.unique_phrases"))
                            Spacer()
                            Text("\(profile.topPhrases.count)")
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text(String(localized: "writing.settings.statistics_section"))
                    }
                }

                // Sample Texts Section (when ready)
                if profile.isReady && !profile.sampleTexts.isEmpty {
                    Section {
                        ForEach(Array(profile.sampleTexts.prefix(3).enumerated()), id: \.offset) { index, sample in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(String(localized: "writing.settings.sample \(index + 1)"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(sample)
                                    .font(.subheadline)
                                    .lineLimit(3)
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text(String(localized: "writing.settings.samples_section"))
                    } footer: {
                        Text(String(localized: "writing.settings.samples_footer"))
                    }
                }

                // Data Management Section
                Section {
                    Button(role: .destructive) {
                        showingResetConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text(String(localized: "writing.settings.reset"))
                        }
                    }
                } header: {
                    Text(String(localized: "writing.settings.data_section"))
                } footer: {
                    Text(String(localized: "writing.settings.reset_footer"))
                }

                // Privacy Section
                Section {
                    HStack(alignment: .top) {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(.green)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "writing.settings.privacy_title"))
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text(String(localized: "writing.settings.privacy_desc"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text(String(localized: "writing.settings.privacy_section"))
                }
            }
            .navigationTitle(String(localized: "writing.settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.done")) {
                        dismiss()
                    }
                }
            }
            .alert(String(localized: "writing.settings.reset_confirm"), isPresented: $showingResetConfirm) {
                Button(String(localized: "common.cancel"), role: .cancel) {}
                Button(String(localized: "writing.settings.reset"), role: .destructive) {
                    profile.reset()
                    try? modelContext.save()
                }
            } message: {
                Text(String(localized: "writing.settings.reset_message"))
            }
            .onChange(of: profile.isEnabled) { _, _ in
                try? modelContext.save()
            }
        }
    }

    private var statusColor: Color {
        switch profile.status {
        case .notAnalyzed: return .secondary
        case .analyzing: return .orange
        case .ready: return .green
        case .failed: return .red
        }
    }
}

#Preview {
    WritingStyleSettingsView(profile: WritingStyleProfile())
        .modelContainer(for: [WritingStyleProfile.self], inMemory: true)
}

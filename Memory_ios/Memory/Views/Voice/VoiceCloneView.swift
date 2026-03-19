import SwiftUI
import SwiftData
import AVFoundation

struct VoiceCloneView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [VoiceProfile]
    @Query private var samples: [VoiceSample]

    @Query private var allMemories: [MemoryEntry]

    @State private var showingRecording = false
    @State private var showingSettings = false
    @State private var showingTraining = false
    @State private var showingImportPicker = false
    @State private var isPlayingPreview = false
    @State private var previewPlayer: AVAudioPlayer?

    private var audioMemories: [MemoryEntry] {
        allMemories.filter { $0.type == .audio && $0.audioFilePath != nil }
    }

    private var profile: VoiceProfile? {
        profiles.first
    }

    private var usableSamples: [VoiceSample] {
        samples.filter { $0.isGoodEnough }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Status Card
                    statusCard

                    // Progress Section
                    if let profile = profile, profile.status == .collecting || profile.status == .notStarted {
                        progressSection
                    }

                    // Actions
                    actionsSection

                    // Samples List
                    if !samples.isEmpty {
                        samplesSection
                    }
                }
                .padding()
            }
            .navigationTitle(String(localized: "voice.title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingRecording) {
                VoiceSampleRecordView()
            }
            .sheet(isPresented: $showingSettings) {
                VoiceSettingsView()
            }
            .sheet(isPresented: $showingTraining) {
                if let profile = profile {
                    VoiceTrainingView(profile: profile, samples: usableSamples)
                }
            }
            .onAppear {
                ensureProfileExists()
            }
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: profile?.status.icon ?? "waveform.badge.plus")
                    .font(.system(size: 32))
                    .foregroundStyle(statusColor)
            }

            // Status Text
            VStack(spacing: 4) {
                Text(profile?.statusDescription ?? String(localized: "voice.status.not_started"))
                    .font(.title3)
                    .fontWeight(.semibold)

                if let profile = profile {
                    switch profile.status {
                    case .notStarted:
                        Text(String(localized: "voice.status.not_started.desc"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                    case .collecting:
                        Text(String(localized: "voice.status.collecting.desc"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                    case .training:
                        Text(String(localized: "voice.status.training.desc"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                    case .ready:
                        Text(String(localized: "voice.status.ready.desc"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                    case .failed:
                        if let error = profile.trainingError {
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
            }

            // Preview Button (when ready)
            if profile?.isReady == true {
                Button {
                    Task { await playPreview() }
                } label: {
                    HStack {
                        Image(systemName: isPlayingPreview ? "stop.fill" : "play.fill")
                        Text(String(localized: "voice.preview"))
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .clipShape(Capsule())
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }

    private var statusColor: Color {
        guard let profile = profile else { return .secondary }
        switch profile.status {
        case .notStarted: return .secondary
        case .collecting: return .blue
        case .training: return .orange
        case .ready: return .green
        case .failed: return .red
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "voice.progress"))
                    .font(.headline)

                Spacer()

                Text(profile?.durationProgressText ?? "0s / 600s")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.2))

                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: progressColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * (profile?.durationProgress ?? 0))
                }
            }
            .frame(height: 12)

            // Milestones
            HStack {
                VStack(alignment: .leading) {
                    Text(String(localized: "voice.minimum"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("3 min")
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                Spacer()

                VStack {
                    Text(String(localized: "voice.recommended"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("10 min")
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text(String(localized: "voice.optimal"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("30 min")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var progressColors: [Color] {
        guard let profile = profile else { return [.gray] }
        let progress = profile.durationProgress

        if progress < 0.3 {  // < 3 min
            return [.red, .orange]
        } else if progress < 1.0 {  // < 10 min
            return [.orange, .yellow]
        } else {
            return [.green, .mint]
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Record Button
            Button {
                showingRecording = true
            } label: {
                HStack {
                    Image(systemName: "mic.fill")
                    Text(profile?.status == .notStarted
                         ? String(localized: "voice.start_recording")
                         : String(localized: "voice.continue_recording"))
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(profile?.status == .training)

            // Train Button
            if profile?.canStartTraining == true {
                Button {
                    showingTraining = true
                } label: {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text(String(localized: "voice.start_training"))
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            // Import from Memories Button
            Button {
                showingImportPicker = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text(String(localized: "voice.import_from_memories"))
                }
                .font(.subheadline)
                .foregroundStyle(.blue)
            }
            .disabled(audioMemories.isEmpty)
            .sheet(isPresented: $showingImportPicker) {
                VoiceImportPickerView(
                    audioMemories: audioMemories,
                    onImport: { selectedMemories in
                        Task { await importSamplesFromMemories(selectedMemories) }
                    }
                )
            }
        }
    }

    // MARK: - Samples Section

    private var samplesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "voice.samples"))
                    .font(.headline)

                Spacer()

                Text(String(localized: "voice.sample_count \(samples.count)"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(samples.sorted { $0.createdAt > $1.createdAt }.prefix(5)) { sample in
                SampleRow(sample: sample)
            }

            if samples.count > 5 {
                NavigationLink {
                    VoiceSampleListView()
                } label: {
                    Text(String(localized: "voice.view_all"))
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func ensureProfileExists() {
        if profiles.isEmpty {
            let profile = VoiceProfile()
            modelContext.insert(profile)
            try? modelContext.save()
        }
    }

    private func playPreview() async {
        guard let profile = profile else { return }

        do {
            let url = try await VoiceCloneService.shared.previewVoice(profile: profile)
            previewPlayer = try AVAudioPlayer(contentsOf: url)
            previewPlayer?.delegate = nil
            isPlayingPreview = true
            previewPlayer?.play()

            // Stop after playback
            DispatchQueue.main.asyncAfter(deadline: .now() + (previewPlayer?.duration ?? 3)) {
                isPlayingPreview = false
            }
        } catch {
            // Handle error
        }
    }

    private func importSamplesFromMemories(_ memories: [MemoryEntry]) async {
        let samplesDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VoiceSamples")
        try? FileManager.default.createDirectory(at: samplesDir, withIntermediateDirectories: true)

        for memory in memories {
            guard let audioPath = memory.audioFilePath else { continue }
            let sourceURL = AudioRecordingService.recordingURL(for: audioPath)
            guard FileManager.default.fileExists(atPath: sourceURL.path) else { continue }

            let destFilename = "imported_\(UUID().uuidString).m4a"
            let destURL = samplesDir.appendingPathComponent(destFilename)

            do {
                try FileManager.default.copyItem(at: sourceURL, to: destURL)

                let asset = AVURLAsset(url: destURL)
                let cmDuration = try await asset.load(.duration)
                let duration = CMTimeGetSeconds(cmDuration)

                let sample = VoiceSample(
                    audioFilePath: destFilename,
                    duration: duration > 0 ? duration : 0,
                    transcription: memory.content,
                    sourceType: .memory,
                    sourceId: memory.id
                )
                modelContext.insert(sample)
            } catch {
                continue
            }
        }
        try? modelContext.save()
    }
}

// MARK: - Voice Import Picker

struct VoiceImportPickerView: View {
    let audioMemories: [MemoryEntry]
    let onImport: ([MemoryEntry]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List(audioMemories) { memory in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(memory.title)
                            .font(.body)
                        Text(memory.createdAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if selected.contains(memory.id) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                    } else {
                        Image(systemName: "circle")
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selected.contains(memory.id) {
                        selected.remove(memory.id)
                    } else {
                        selected.insert(memory.id)
                    }
                }
            }
            .navigationTitle(String(localized: "voice.import_from_memories"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "voice.import_button")) {
                        let selectedMemories = audioMemories.filter { selected.contains($0.id) }
                        onImport(selectedMemories)
                        dismiss()
                    }
                    .disabled(selected.isEmpty)
                }
            }
        }
    }
}

// MARK: - Sample Row

private struct SampleRow: View {
    let sample: VoiceSample

    @State private var isPlaying = false
    @State private var player: AVAudioPlayer?

    var body: some View {
        HStack {
            // Quality indicator
            Image(systemName: sample.qualityIcon)
                .foregroundStyle(qualityColor)
                .frame(width: 24)

            VStack(alignment: .leading) {
                Text(sample.durationText)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(sample.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Source badge
            Text(sample.sourceType.label)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.2))
                .clipShape(Capsule())

            // Play button
            Button {
                togglePlayback()
            } label: {
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 4)
    }

    private var qualityColor: Color {
        switch sample.quality {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        case .pending: return .secondary
        }
    }

    private func togglePlayback() {
        if isPlaying {
            player?.stop()
            isPlaying = false
        } else {
            guard let url = sample.audioURL else { return }
            do {
                player = try AVAudioPlayer(contentsOf: url)
                player?.play()
                isPlaying = true

                DispatchQueue.main.asyncAfter(deadline: .now() + sample.duration) {
                    isPlaying = false
                }
            } catch {
                // Handle error
            }
        }
    }
}

// MARK: - Sample List View

struct VoiceSampleListView: View {
    @Query private var samples: [VoiceSample]

    var body: some View {
        List {
            ForEach(samples.sorted { $0.createdAt > $1.createdAt }) { sample in
                SampleRow(sample: sample)
            }
        }
        .navigationTitle(String(localized: "voice.all_samples"))
    }
}

#Preview {
    VoiceCloneView()
        .modelContainer(for: [VoiceProfile.self, VoiceSample.self], inMemory: true)
}

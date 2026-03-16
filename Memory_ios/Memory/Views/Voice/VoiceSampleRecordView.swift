import SwiftUI
import SwiftData

struct VoiceSampleRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [VoiceProfile]

    private var voiceService: VoiceCloneService { VoiceCloneService.shared }
    @State private var currentPromptIndex = 0
    @State private var recordingURL: URL?
    @State private var recordingDuration: TimeInterval = 0
    @State private var meterLevel: Float = -60
    @State private var timer: Timer?
    @State private var showingSaveConfirm = false
    @State private var lastQuality: VoiceSampleQuality?
    @State private var samplesRecorded = 0

    private var profile: VoiceProfile? {
        profiles.first
    }

    private var currentPrompt: String {
        VoiceTrainingPrompts.prompt(at: currentPromptIndex)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Instructions
                instructionsSection

                Spacer()

                // Prompt Card
                promptCard

                Spacer()

                // Recording Controls
                recordingControls

                // Progress indicator
                sessionProgress
            }
            .padding()
            .navigationTitle(String(localized: "voice.record.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "common.done")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        currentPromptIndex = Int.random(in: 0..<20)
                    } label: {
                        Image(systemName: "shuffle")
                    }
                }
            }
            .alert(String(localized: "voice.record.saved"), isPresented: $showingSaveConfirm) {
                Button(String(localized: "voice.record.another")) {
                    currentPromptIndex += 1
                }
                Button(String(localized: "common.done")) {
                    dismiss()
                }
            } message: {
                if let quality = lastQuality {
                    Text(String(localized: "voice.record.quality \(quality.label)"))
                }
            }
        }
    }

    // MARK: - Instructions Section

    private var instructionsSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(.blue)
                Text(String(localized: "voice.record.instructions"))
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Text(String(localized: "voice.record.tips"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Prompt Card

    private var promptCard: some View {
        VStack(spacing: 16) {
            Text(String(localized: "voice.record.read_aloud"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(currentPrompt)
                .font(.title3)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                currentPromptIndex += 1
            } label: {
                HStack {
                    Text(String(localized: "voice.record.next_prompt"))
                    Image(systemName: "arrow.right")
                }
                .font(.subheadline)
            }
        }
    }

    // MARK: - Recording Controls

    private var recordingControls: some View {
        VStack(spacing: 24) {
            // Waveform / Meter
            waveformView

            // Duration
            Text(formatDuration(recordingDuration))
                .font(.system(size: 48, weight: .light, design: .monospaced))
                .foregroundStyle(voiceService.isRecording ? .red : .primary)

            // Record Button
            HStack(spacing: 40) {
                // Cancel (when recording)
                if voiceService.isRecording {
                    Button {
                        cancelRecording()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundStyle(.red)
                            .frame(width: 60, height: 60)
                            .background(Color.red.opacity(0.15))
                            .clipShape(Circle())
                    }
                }

                // Main Record/Stop Button
                Button {
                    if voiceService.isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(voiceService.isRecording ? Color.red : Color.blue)
                            .frame(width: 80, height: 80)

                        if voiceService.isRecording {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white)
                                .frame(width: 24, height: 24)
                        } else {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 24, height: 24)
                        }
                    }
                }

                // Placeholder for symmetry
                if voiceService.isRecording {
                    Color.clear
                        .frame(width: 60, height: 60)
                }
            }

            // Hint
            Text(voiceService.isRecording
                 ? String(localized: "voice.record.tap_to_stop")
                 : String(localized: "voice.record.tap_to_start"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Waveform View

    private var waveformView: some View {
        HStack(spacing: 3) {
            ForEach(0..<20, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(for: index))
                    .frame(width: 8, height: barHeight(for: index))
            }
        }
        .frame(height: 60)
        .animation(.easeInOut(duration: 0.1), value: meterLevel)
    }

    private func barHeight(for index: Int) -> CGFloat {
        guard voiceService.isRecording else {
            return 10
        }

        // Convert dB to linear scale
        let normalizedLevel = (meterLevel + 60) / 60  // -60dB to 0dB -> 0 to 1
        let baseHeight: CGFloat = 10
        let maxHeight: CGFloat = 60

        // Add some variation based on index
        let variation = sin(Double(index) * 0.5 + Date().timeIntervalSince1970 * 10) * 0.3
        let height = baseHeight + (maxHeight - baseHeight) * CGFloat(normalizedLevel) * (1 + CGFloat(variation))

        return max(baseHeight, min(height, maxHeight))
    }

    private func barColor(for index: Int) -> Color {
        guard voiceService.isRecording else {
            return .secondary.opacity(0.3)
        }

        let normalizedLevel = (meterLevel + 60) / 60
        if normalizedLevel > 0.8 {
            return .red  // Too loud
        } else if normalizedLevel > 0.3 {
            return .green  // Good
        } else {
            return .orange  // Too quiet
        }
    }

    // MARK: - Session Progress

    private var sessionProgress: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

            Text(String(localized: "voice.record.session_count \(samplesRecorded)"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if let profile = profile {
                Text(profile.durationProgressText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Actions

    private func startRecording() {
        do {
            recordingURL = try voiceService.startRecording()
            recordingDuration = 0

            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                recordingDuration = voiceService.recordingDuration
                meterLevel = voiceService.currentMeterLevel
            }
        } catch {
            // Handle error
        }
    }

    private func stopRecording() {
        timer?.invalidate()
        timer = nil

        guard let (url, duration) = voiceService.stopRecording() else { return }

        // Check minimum duration
        guard duration >= 5 else {
            // Too short, delete and notify
            try? FileManager.default.removeItem(at: url)
            return
        }

        // Create sample
        let fileName = url.lastPathComponent
        let sample = VoiceSample(
            audioFilePath: fileName,
            duration: duration,
            promptText: currentPrompt,
            sourceType: .recorded
        )

        // Evaluate quality
        Task {
            let (volume, noise, clarity) = await voiceService.evaluateQuality(sampleURL: url)
            sample.updateQuality(volume: volume, noise: noise, clarity: clarity)

            if sample.isGoodEnough {
                sample.markForTraining()
            }

            modelContext.insert(sample)
            profile?.addSample(duration: duration)
            try? modelContext.save()

            samplesRecorded += 1
            lastQuality = sample.quality
            showingSaveConfirm = true
        }
    }

    private func cancelRecording() {
        timer?.invalidate()
        timer = nil
        voiceService.cancelRecording()
        recordingDuration = 0
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
}

#Preview {
    VoiceSampleRecordView()
        .modelContainer(for: [VoiceProfile.self, VoiceSample.self], inMemory: true)
}

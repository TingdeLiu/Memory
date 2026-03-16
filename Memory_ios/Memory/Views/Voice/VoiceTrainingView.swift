import SwiftUI
import SwiftData
import AVFoundation

struct VoiceTrainingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var profile: VoiceProfile
    let samples: [VoiceSample]

    @State private var voiceName = ""
    @State private var isTraining = false
    @State private var trainingProgress: Double = 0
    @State private var trainingError: String?
    @State private var trainingComplete = false
    @State private var isPlayingPreview = false
    @State private var previewPlayer: AVAudioPlayer?

    private var voiceService = VoiceCloneService.shared

    init(profile: VoiceProfile, samples: [VoiceSample]) {
        self.profile = profile
        self.samples = samples
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if trainingComplete {
                    completionView
                } else if isTraining {
                    trainingView
                } else {
                    setupView
                }
            }
            .padding()
            .navigationTitle(String(localized: "voice.training.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !isTraining {
                        Button(String(localized: "common.cancel")) {
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Setup View

    private var setupView: some View {
        VStack(spacing: 24) {
            // Voice Icon
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "wand.and.stars")
                    .font(.system(size: 40))
                    .foregroundStyle(.purple)
            }

            // Info
            VStack(spacing: 8) {
                Text(String(localized: "voice.training.ready"))
                    .font(.title2)
                    .fontWeight(.bold)

                Text(String(localized: "voice.training.description"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Sample Summary
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(String(localized: "voice.training.samples \(samples.count)"))
                }

                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(.blue)
                    Text(String(localized: "voice.training.duration \(Int(profile.totalDuration))"))
                }

                HStack {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.orange)
                    Text(String(localized: "voice.training.quality_good"))
                }
            }
            .font(.subheadline)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Voice Name Input
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "voice.training.name_label"))
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextField(String(localized: "voice.training.name_placeholder"), text: $voiceName)
                    .textFieldStyle(.roundedBorder)
            }

            Spacer()

            // Provider Info
            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)

                Text(String(localized: "voice.training.provider \(profile.provider.label)"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Start Button
            Button {
                startTraining()
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text(String(localized: "voice.training.start"))
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
            .disabled(voiceName.isEmpty || !voiceService.hasAPIKey(for: profile.provider))

            if !voiceService.hasAPIKey(for: profile.provider) {
                Text(String(localized: "voice.training.need_api_key"))
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Training View

    private var trainingView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated Icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "gearshape.2")
                    .font(.system(size: 50))
                    .foregroundStyle(.orange)
                    .rotationEffect(.degrees(trainingProgress * 360))
                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: trainingProgress)
            }

            // Status
            VStack(spacing: 8) {
                Text(String(localized: "voice.training.in_progress"))
                    .font(.title2)
                    .fontWeight(.bold)

                Text(String(localized: "voice.training.please_wait"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Progress Bar
            VStack(spacing: 8) {
                ProgressView(value: trainingProgress)
                    .progressViewStyle(.linear)
                    .tint(.orange)

                Text(String(localized: "voice.training.progress \(Int(trainingProgress * 100))"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 40)

            Spacer()

            // Warning
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)

                Text(String(localized: "voice.training.do_not_close"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .onAppear {
            // Start progress animation
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                trainingProgress = 1.0
            }
        }
    }

    // MARK: - Completion View

    private var completionView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Success Icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.green)
            }

            // Success Message
            VStack(spacing: 8) {
                Text(String(localized: "voice.training.complete"))
                    .font(.title2)
                    .fontWeight(.bold)

                Text(String(localized: "voice.training.complete_desc"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Voice Name
            Text(voiceName)
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.15))
                .clipShape(Capsule())

            Spacer()

            // Preview Button
            Button {
                Task { await playPreview() }
            } label: {
                HStack {
                    Image(systemName: isPlayingPreview ? "stop.fill" : "play.fill")
                    Text(String(localized: "voice.preview"))
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Done Button
            Button {
                dismiss()
            } label: {
                Text(String(localized: "common.done"))
                    .font(.headline)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Actions

    private func startTraining() {
        isTraining = true
        trainingProgress = 0
        profile.startTraining()

        Task {
            do {
                // Update progress based on service
                let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                    trainingProgress = voiceService.trainingProgress
                }

                try await voiceService.trainWithElevenLabs(
                    profile: profile,
                    samples: samples,
                    name: voiceName
                )

                progressTimer.invalidate()
                trainingProgress = 1.0

                try? modelContext.save()
                trainingComplete = true

            } catch {
                trainingError = error.localizedDescription
                profile.failTraining(error: error.localizedDescription)
                isTraining = false
            }
        }
    }

    private func playPreview() async {
        do {
            let url = try await voiceService.previewVoice(profile: profile)
            previewPlayer = try AVAudioPlayer(contentsOf: url)
            isPlayingPreview = true
            previewPlayer?.play()

            DispatchQueue.main.asyncAfter(deadline: .now() + (previewPlayer?.duration ?? 3)) {
                isPlayingPreview = false
            }
        } catch {
            // Handle error
        }
    }
}

#Preview {
    VoiceTrainingView(profile: VoiceProfile(), samples: [])
        .modelContainer(for: [VoiceProfile.self, VoiceSample.self], inMemory: true)
}

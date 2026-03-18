import SwiftUI

struct VoiceRecordingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var recorder: AudioRecordingService
    @State private var transcriptionService = SpeechTranscriptionService()
    @State private var hasPermission = false
    @State private var permissionChecked = false
    @State private var showTranscription = false
    @State private var transcribedText = ""
    @State private var recordingResult: (url: URL, duration: TimeInterval)?

    var onSave: (URL, TimeInterval) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Waveform visualization
                WaveformView(level: recorder.audioLevel, isActive: recorder.isRecording)
                    .frame(height: 80)

                // Duration
                Text(formatDuration(recorder.isRecording ? recorder.recordingDuration : (recordingResult?.duration ?? 0)))
                    .font(.system(.largeTitle, design: .monospaced))
                    .fontWeight(.light)
                    .foregroundStyle(recorder.isRecording ? .primary : .secondary)

                // Record button
                Button {
                    if recorder.isRecording {
                        recordingResult = recorder.stopRecording()
                    } else {
                        recordingResult = nil
                        transcribedText = ""
                        try? recorder.startRecording()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(recorder.isRecording ? Color.red : Color.accentColor)
                            .frame(width: 72, height: 72)
                        if recorder.isRecording {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.white)
                                .frame(width: 24, height: 24)
                        } else {
                            Circle()
                                .fill(.white)
                                .frame(width: 28, height: 28)
                        }
                    }
                }
                .disabled(!permissionChecked || !hasPermission)
                .accessibilityLabel(recorder.isRecording ? String(localized: "voiceRecording.stop") : String(localized: "voiceRecording.start"))
                .sensoryFeedback(.impact(weight: .medium), trigger: recorder.isRecording)

                // Transcription
                if let result = recordingResult {
                    VStack(spacing: 12) {
                        if transcriptionService.isTranscribing {
                            ProgressView(String(localized: "voiceRecording.transcribing"))
                                .font(.caption)
                        } else if !transcribedText.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(String(localized: "voiceRecording.transcription"))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                Text(transcribedText)
                                    .font(.body)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .padding(.horizontal)
                        } else {
                            Button {
                                Task {
                                    if await transcriptionService.requestPermission() {
                                        transcribedText = (try? await transcriptionService.transcribe(audioURL: result.url)) ?? ""
                                    }
                                }
                            } label: {
                                Label(String(localized: "voiceRecording.transcribeButton"), systemImage: "text.bubble")
                                    .font(.subheadline)
                            }
                        }
                    }
                }

                if !hasPermission && permissionChecked {
                    Text(String(localized: "voiceRecording.noPermission"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle(String(localized: "voiceRecording.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        if recorder.isRecording {
                            _ = recorder.stopRecording()
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "voiceRecording.useRecording")) {
                        if let result = recordingResult {
                            onSave(result.url, result.duration)
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(recordingResult == nil)
                }
            }
            .task {
                hasPermission = await recorder.requestPermission()
                permissionChecked = true
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let fraction = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, fraction)
    }
}

import SwiftUI
import SwiftData
import AVKit

struct MemoryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let memory: MemoryEntry

    @State private var showingEditor = false
    @State private var showingDeleteAlert = false
    @State private var player = AudioPlaybackService()
    @State private var showingFullScreenVideo = false
    @State private var videoPlayerURL: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                headerSection

                Divider()

                // Photo
                if let data = memory.photoData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // Video player
                if memory.type == .video, let path = memory.videoFilePath {
                    videoSection(path: path)
                }

                // Audio player
                if memory.type == .audio, let path = memory.audioFilePath {
                    audioPlayerSection(path: path)
                }

                // Content
                if !memory.content.isEmpty {
                    Text(memory.content)
                        .font(.body)
                        .lineSpacing(6)
                }

                // Transcription
                if let transcription = memory.transcription, !transcription.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(String(localized: "voiceRecording.transcription"), systemImage: "text.bubble")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        Text(transcription)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                // Tags
                if !memory.tags.isEmpty {
                    tagsSection
                }

                // Metadata
                if memory.updatedAt.timeIntervalSince(memory.createdAt) > 1 {
                    Text(String(localized: "memoryDetail.lastEdited") + " " + memory.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingEditor = true
                    } label: {
                        Label(String(localized: "common.edit"), systemImage: "pencil")
                    }

                    if memory.type == .audio, let path = memory.audioFilePath {
                        Button {
                            shareAudio(path: path)
                        } label: {
                            Label(String(localized: "memoryDetail.shareAudio"), systemImage: "square.and.arrow.up")
                        }
                    }

                    if memory.type == .video, let path = memory.videoFilePath {
                        Button {
                            shareVideo(path: path)
                        } label: {
                            Label(String(localized: "memoryDetail.shareVideo"), systemImage: "square.and.arrow.up")
                        }
                    }

                    Divider()

                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label(String(localized: "common.delete"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            MemoryEditorView(existingMemory: memory)
        }
        .fullScreenCover(isPresented: $showingFullScreenVideo) {
            if let url = videoPlayerURL {
                VideoPlayerFullScreen(url: url)
            }
        }
        .alert(String(localized: "memoryDetail.deleteTitle"), isPresented: $showingDeleteAlert) {
            Button(String(localized: "common.delete"), role: .destructive) {
                deleteMemory()
            }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "memoryDetail.deleteMessage"))
        }
        .onDisappear {
            player.stop()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let mood = memory.mood {
                HStack(spacing: 6) {
                    Text(mood.emoji)
                        .font(.title3)
                    Text(mood.label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text(memory.title.isEmpty ? String(localized: "common.untitled") : memory.title)
                .font(.largeTitle)
                .fontWeight(.bold)

            HStack(spacing: 12) {
                Label(memory.createdAt.formatted(date: .long, time: .shortened), systemImage: "calendar")

                if memory.isPrivate {
                    Label(String(localized: "common.private"), systemImage: "lock.fill")
                }

                switch memory.type {
                case .audio:
                    Label(String(localized: "memoryType.voice"), systemImage: "waveform")
                case .photo:
                    Label(String(localized: "memoryType.photo"), systemImage: "photo")
                case .video:
                    Label(String(localized: "memoryType.video"), systemImage: "video")
                case .text:
                    EmptyView()
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Video Section

    private func videoSection(path: String) -> some View {
        let url = AudioRecordingService.recordingURL(for: path)
        return VStack(spacing: 12) {
            // Thumbnail with play button
            Button {
                prepareVideoPlayback(url: url)
            } label: {
                ZStack {
                    if let data = memory.videoThumbnailData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray5))
                            .frame(maxWidth: .infinity, maxHeight: 220)
                    }

                    VStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.white.opacity(0.9))
                            .shadow(radius: 4)

                        if let dur = memory.videoDuration {
                            Text(formatTime(dur))
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.black.opacity(0.6))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func prepareVideoPlayback(url: URL) {
        if EncryptionLevel.current == .full {
            if let key = try? EncryptionHelper.masterKey(),
               let tempURL = try? EncryptionHelper.decryptFileToTemp(at: url, using: key) {
                videoPlayerURL = tempURL
            }
        } else {
            videoPlayerURL = url
        }
        showingFullScreenVideo = true
    }

    // MARK: - Audio Player

    private func audioPlayerSection(path: String) -> some View {
        let url = AudioRecordingService.recordingURL(for: path)
        return VStack(spacing: 12) {
            // Playback controls
            HStack(spacing: 16) {
                // Play/Pause
                Button {
                    try? player.togglePlayback(url: url)
                } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.accentColor)
                }
                .accessibilityLabel(player.isPlaying ? String(localized: "common.pause") : String(localized: "common.play"))

                VStack(spacing: 6) {
                    // Seek bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(.systemGray5))
                                .frame(height: 6)
                            Capsule()
                                .fill(Color.accentColor)
                                .frame(width: geo.size.width * player.progress, height: 6)
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let fraction = max(0, min(1, value.location.x / geo.size.width))
                                    player.seek(to: fraction)
                                }
                        )
                    }
                    .frame(height: 6)
                    .accessibilityLabel(String(localized: "memoryDetail.playbackProgress"))
                    .accessibilityValue("\(Int(player.progress * 100)) percent")

                    // Time labels
                    HStack {
                        Text(formatTime(player.currentTime))
                        Spacer()
                        Text(formatTime(memory.audioDuration ?? player.duration))
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Tags

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "memoryEditor.tags"))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            FlowLayout(spacing: 8) {
                ForEach(memory.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Actions

    private func deleteMemory() {
        if let path = memory.audioFilePath {
            let url = AudioRecordingService.recordingURL(for: path)
            AudioRecordingService().deleteRecording(at: url)
        }
        if let path = memory.videoFilePath {
            let url = AudioRecordingService.recordingURL(for: path)
            try? FileManager.default.removeItem(at: url)
        }
        modelContext.delete(memory)
        dismiss()
    }

    private func shareAudio(path: String) {
        // Placeholder for share functionality
    }

    private func shareVideo(path: String) {
        // Placeholder for share functionality
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Full Screen Video Player

struct VideoPlayerFullScreen: View {
    @Environment(\.dismiss) private var dismiss
    let url: URL

    var body: some View {
        ZStack(alignment: .topLeading) {
            VideoPlayer(player: AVPlayer(url: url))
                .ignoresSafeArea()

            Button {
                // Clean up temp file if in full encryption mode
                if EncryptionLevel.current == .full {
                    try? EncryptionHelper.secureDelete(at: url)
                }
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .padding()
        }
    }
}

#Preview {
    NavigationStack {
        MemoryDetailView(memory: MemoryEntry(
            title: "A beautiful sunset",
            content: "Today I watched the most incredible sunset from the rooftop. The sky turned shades of orange, pink, and purple. It reminded me of that summer we spent at grandma's house.",
            tags: ["nature", "reflection", "sunset"],
            mood: .nostalgic
        ))
    }
}

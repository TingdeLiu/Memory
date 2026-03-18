import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation

struct MemoryEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var existingMemory: MemoryEntry?

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var selectedMood: Mood?
    @State private var tags: [String] = []
    @State private var newTag: String = ""
    @State private var isPrivate: Bool = false
    @State private var showingDiscardAlert = false
    @State private var didSave = false

    // Audio recording
    @State private var recorder = AudioRecordingService()
    @State private var audioURL: URL?
    @State private var audioDuration: TimeInterval = 0
    @State private var showingRecordingSheet = false

    // Photo
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var photoData: Data?

    // Video
    @State private var videoRecorder = VideoRecordingService()
    @State private var videoURL: URL?
    @State private var videoDuration: TimeInterval = 0
    @State private var videoThumbnailData: Data?
    @State private var showingVideoRecordingSheet = false
    @State private var selectedVideoItem: PhotosPickerItem?

    // Auto-save
    @State private var autoSaveTimer: Timer?
    @State private var lastAutoSave: Date?
    @State private var draftMemory: MemoryEntry?

    private var isEditing: Bool { existingMemory != nil }
    private var hasContent: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        audioURL != nil || photoData != nil || videoURL != nil
    }
    private var hasChanges: Bool {
        if let memory = existingMemory {
            return title != memory.title || content != memory.content ||
                   selectedMood != memory.mood || tags != memory.tags ||
                   isPrivate != memory.isPrivate || photoData != memory.photoData
        }
        return hasContent
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Title
                    TextField(String(localized: "memoryEditor.title"), text: $title, axis: .vertical)
                        .font(.title2.bold())
                        .padding(.horizontal)
                        .padding(.top, 16)

                    // Content
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $content)
                            .frame(minHeight: 180)
                            .scrollContentBackground(.hidden)
                        if content.isEmpty {
                            Text(String(localized: "memoryEditor.placeholder"))
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(.horizontal)

                    // Attachments row
                    attachmentsSection

                    Divider().padding(.vertical, 8)

                    // Mood picker
                    moodSection

                    Divider().padding(.vertical, 8)

                    // Tags
                    tagsSection

                    Divider().padding(.vertical, 8)

                    // Options
                    optionsSection

                    // Auto-save indicator
                    if lastAutoSave != nil {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                            Text(String(localized: "memoryEditor.draftSaved"))
                                .font(.caption2)
                        }
                        .foregroundStyle(.tertiary)
                        .padding(.top, 12)
                    }
                }
                .padding(.bottom, 40)
            }
            .navigationTitle(isEditing ? String(localized: "memoryEditor.editTitle") : String(localized: "memoryEditor.newTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        if hasChanges {
                            showingDiscardAlert = true
                        } else {
                            cleanupDraft()
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save")) {
                        save()
                        cleanupDraft()
                        didSave = true
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!hasContent)
                    .sensoryFeedback(.success, trigger: didSave)
                }
            }
            .alert(String(localized: "memoryEditor.discardTitle"), isPresented: $showingDiscardAlert) {
                Button(String(localized: "memoryEditor.discardButton"), role: .destructive) {
                    cleanupDraft()
                    dismiss()
                }
                Button(String(localized: "memoryEditor.keepEditing"), role: .cancel) {}
            } message: {
                Text(String(localized: "memoryEditor.discardMessage"))
            }
            .sheet(isPresented: $showingRecordingSheet) {
                VoiceRecordingSheet(
                    recorder: recorder,
                    onSave: { url, duration in
                        audioURL = url
                        audioDuration = duration
                    }
                )
                .presentationDetents([.medium])
            }
            .fullScreenCover(isPresented: $showingVideoRecordingSheet) {
                VideoRecordingSheet(
                    recorder: videoRecorder,
                    onSave: { url, duration in
                        videoURL = url
                        videoDuration = duration
                        videoThumbnailData = VideoRecordingService.generateThumbnail(for: url)
                    }
                )
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        photoData = data
                    }
                }
            }
            .onChange(of: selectedVideoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        let fileName = "memory_\(UUID().uuidString).mov"
                        let url = AudioRecordingService.recordingsDirectory.appendingPathComponent(fileName)
                        try? data.write(to: url)
                        videoURL = url
                        videoDuration = await VideoRecordingService.videoDuration(for: url) ?? 0
                        videoThumbnailData = VideoRecordingService.generateThumbnail(for: url)
                    }
                }
            }
            .onAppear {
                loadExisting()
                startAutoSave()
            }
            .onDisappear {
                stopAutoSave()
            }
        }
    }

    // MARK: - Sections

    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Audio attachment
            if let url = audioURL {
                AudioAttachmentView(
                    url: url,
                    duration: audioDuration,
                    onDelete: {
                        recorder.deleteRecording(at: url)
                        audioURL = nil
                        audioDuration = 0
                    }
                )
                .padding(.horizontal)
            }

            // Photo attachment
            if let data = photoData, let uiImage = UIImage(data: data) {
                PhotoAttachmentView(
                    image: uiImage,
                    onDelete: {
                        photoData = nil
                        selectedPhotoItem = nil
                    }
                )
                .padding(.horizontal)
            }

            // Video attachment
            if videoURL != nil {
                VideoAttachmentView(
                    thumbnailData: videoThumbnailData,
                    duration: videoDuration,
                    onDelete: {
                        if let videoURL {
                            try? FileManager.default.removeItem(at: videoURL)
                        }
                        videoURL = nil
                        videoDuration = 0
                        videoThumbnailData = nil
                        selectedVideoItem = nil
                    }
                )
                .padding(.horizontal)
            }

            // Attachment buttons
            HStack(spacing: 16) {
                Button {
                    showingRecordingSheet = true
                } label: {
                    Label(
                        audioURL == nil ? String(localized: "memoryEditor.recordVoice") : String(localized: "memoryEditor.reRecord"),
                        systemImage: "mic.fill"
                    )
                    .font(.subheadline)
                }

                PhotosPicker(
                    selection: $selectedPhotoItem,
                    matching: .images
                ) {
                    Label(
                        photoData == nil ? String(localized: "memoryEditor.addPhoto") : String(localized: "memoryEditor.changePhoto"),
                        systemImage: "photo"
                    )
                    .font(.subheadline)
                }

                Button {
                    showingVideoRecordingSheet = true
                } label: {
                    Label(
                        videoURL == nil ? String(localized: "memoryEditor.recordVideo") : String(localized: "memoryEditor.reRecordVideo"),
                        systemImage: "video.fill"
                    )
                    .font(.subheadline)
                }

                PhotosPicker(
                    selection: $selectedVideoItem,
                    matching: .videos
                ) {
                    Label(
                        videoURL == nil ? String(localized: "memoryEditor.importVideo") : String(localized: "memoryEditor.changeVideo"),
                        systemImage: "film"
                    )
                    .font(.subheadline)
                }
            }
            .padding(.horizontal)
            .padding(.top, 4)
        }
    }

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "memoryEditor.mood"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Mood.allCases, id: \.self) { mood in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedMood = selectedMood == mood ? nil : mood
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Text(mood.emoji)
                                    .font(.title2)
                                Text(mood.label)
                                    .font(.caption2)
                                    .foregroundStyle(selectedMood == mood ? Color.accentColor : .secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(selectedMood == mood ? Color.accentColor.opacity(0.12) : Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(mood.label)
                        .accessibilityAddTraits(selectedMood == mood ? .isSelected : [])
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "memoryEditor.tags"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text(tag)
                                Button {
                                    withAnimation { tags.removeAll { $0 == tag } }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                }
                            }
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                            .accessibilityLabel(L10n.tagAccessibilityLabel(tag))
                            .accessibilityHint(String(localized: "memoryEditor.removeTagHint"))
                        }
                    }
                    .padding(.horizontal)
                }
            }

            HStack {
                TextField(String(localized: "memoryEditor.addTag"), text: $newTag)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addTag() }
                Button {
                    addTag()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal)
        }
    }

    @State private var showingTimeCapsuleEditor = false

    private var optionsSection: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $isPrivate) {
                Label(String(localized: "memoryEditor.private"), systemImage: "lock.fill")
                    .font(.subheadline)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            if isPrivate {
                Text(String(localized: "memoryEditor.privateHint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            Divider().padding(.horizontal)

            if !isEditing {
                Button {
                    showingTimeCapsuleEditor = true
                } label: {
                    Label(String(localized: "memoryEditor.sealAsCapsule"), systemImage: "hourglass")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .sheet(isPresented: $showingTimeCapsuleEditor) {
                    TimeCapsuleEditorView()
                }
            }
        }
    }

    // MARK: - Actions

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        withAnimation { tags.append(trimmed) }
        newTag = ""
    }

    private func loadExisting() {
        if let memory = existingMemory {
            title = memory.title
            content = memory.content
            selectedMood = memory.mood
            tags = memory.tags
            isPrivate = memory.isPrivate
            photoData = memory.photoData
            if let path = memory.audioFilePath {
                audioURL = AudioRecordingService.recordingURL(for: path)
                audioDuration = memory.audioDuration ?? 0
            }
            if let path = memory.videoFilePath {
                videoURL = AudioRecordingService.recordingURL(for: path)
                videoDuration = memory.videoDuration ?? 0
                videoThumbnailData = memory.videoThumbnailData
            }
        }
    }

    private func save() {
        let memoryType: MemoryType = videoURL != nil ? .video : (audioURL != nil ? .audio : (photoData != nil ? .photo : .text))

        if let memory = existingMemory {
            memory.title = title
            memory.content = content
            memory.mood = selectedMood
            memory.tags = tags
            memory.isPrivate = isPrivate
            memory.type = memoryType
            memory.photoData = photoData
            if let url = audioURL {
                memory.audioFilePath = url.lastPathComponent
                memory.audioDuration = audioDuration
            }
            if let url = videoURL {
                memory.videoFilePath = url.lastPathComponent
                memory.videoDuration = videoDuration
                memory.videoThumbnailData = videoThumbnailData
            }
            memory.updatedAt = Date()
        } else {
            let memory = MemoryEntry(
                title: title,
                content: content,
                type: memoryType,
                tags: tags,
                mood: selectedMood,
                isPrivate: isPrivate,
                audioFilePath: audioURL?.lastPathComponent,
                audioDuration: audioURL != nil ? audioDuration : nil,
                photoData: photoData,
                videoFilePath: videoURL?.lastPathComponent,
                videoDuration: videoURL != nil ? videoDuration : nil,
                videoThumbnailData: videoThumbnailData
            )
            modelContext.insert(memory)
        }

        // Remove draft if we had one
        if let draft = draftMemory {
            modelContext.delete(draft)
        }
    }

    // MARK: - Auto-save

    private func startAutoSave() {
        guard !isEditing else { return }
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            performAutoSave()
        }
    }

    private func stopAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
    }

    private func performAutoSave() {
        guard hasContent, !isEditing else { return }

        if let draft = draftMemory {
            draft.title = title
            draft.content = content
            draft.mood = selectedMood
            draft.tags = tags
            draft.updatedAt = Date()
        } else {
            let draft = MemoryEntry(title: title, content: content, tags: tags, mood: selectedMood)
            draft.title = "[Draft] " + draft.title
            modelContext.insert(draft)
            draftMemory = draft
        }
        lastAutoSave = Date()
    }

    private func cleanupDraft() {
        stopAutoSave()
        if let draft = draftMemory {
            modelContext.delete(draft)
            draftMemory = nil
        }
    }
}

// MARK: - Audio Attachment View

struct AudioAttachmentView: View {
    let url: URL
    let duration: TimeInterval
    let onDelete: () -> Void

    @State private var player = AudioPlaybackService()

    var body: some View {
        HStack(spacing: 12) {
            Button {
                try? player.togglePlayback(url: url)
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title)
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(.systemGray5))
                            .frame(height: 4)
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: geo.size.width * player.progress, height: 4)
                    }
                }
                .frame(height: 4)

                HStack {
                    Text(formatTime(player.isPlaying ? player.currentTime : 0))
                    Spacer()
                    Text(formatTime(duration))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Photo Attachment View

struct PhotoAttachmentView: View {
    let image: UIImage
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.5))
            }
            .padding(8)
        }
    }
}

// MARK: - Video Recording Sheet

struct VideoRecordingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var recorder: VideoRecordingService
    @State private var hasPermission = false
    @State private var permissionChecked = false
    @State private var recordingResult: (url: URL, duration: TimeInterval)?

    var onSave: (URL, TimeInterval) -> Void

    var body: some View {
        ZStack {
            // Camera preview
            if recorder.isSessionReady, let session = recorder.captureSession {
                CameraPreviewView(session: session)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
                ProgressView()
                    .tint(.white)
            }

            // Controls overlay
            VStack {
                // Top bar
                HStack {
                    Button {
                        if recorder.isRecording {
                            recordingResult = recorder.stopRecording()
                        }
                        recorder.stopSession()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                    }

                    Spacer()

                    if recordingResult != nil {
                        Button(String(localized: "videoRecording.useVideo")) {
                            if let result = recordingResult {
                                onSave(result.url, result.duration)
                            }
                            recorder.stopSession()
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                    }
                }
                .padding()

                Spacer()

                // Duration
                if recorder.isRecording || recordingResult != nil {
                    Text(formatDuration(recorder.isRecording ? recorder.recordingDuration : (recordingResult?.duration ?? 0)))
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.5))
                        .clipShape(Capsule())
                }

                // Bottom controls
                HStack(spacing: 40) {
                    // Switch camera
                    Button {
                        recorder.switchCamera()
                    } label: {
                        Image(systemName: "camera.rotate")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .disabled(recorder.isRecording)

                    // Record button
                    Button {
                        if recorder.isRecording {
                            recordingResult = recorder.stopRecording()
                        } else {
                            recordingResult = nil
                            recorder.startRecording()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .strokeBorder(.white, lineWidth: 4)
                                .frame(width: 72, height: 72)
                            if recorder.isRecording {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.red)
                                    .frame(width: 28, height: 28)
                            } else {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 58, height: 58)
                            }
                        }
                    }
                    .disabled(!permissionChecked || !hasPermission)

                    // Spacer for symmetry
                    Color.clear
                        .frame(width: 48, height: 48)
                }
                .padding(.bottom, 40)

                if !hasPermission && permissionChecked {
                    Text(String(localized: "videoRecording.noPermission"))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
        }
        .task {
            hasPermission = await recorder.requestPermission()
            permissionChecked = true
            if hasPermission {
                recorder.setupSession()
            }
        }
        .onDisappear {
            recorder.stopSession()
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Video Attachment View

struct VideoAttachmentView: View {
    let thumbnailData: Data?
    let duration: TimeInterval
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                if let data = thumbnailData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .frame(maxWidth: .infinity, maxHeight: 160)
                }

                // Play icon + duration overlay
                VStack {
                    Image(systemName: "play.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(radius: 3)

                    HStack(spacing: 4) {
                        Image(systemName: "video")
                        Text(formatTime(duration))
                    }
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.6))
                    .clipShape(Capsule())
                }
            }

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.5))
            }
            .padding(8)
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    MemoryEditorView()
        .modelContainer(for: [MemoryEntry.self, Contact.self, Message.self], inMemory: true)
}

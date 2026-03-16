import SwiftUI
import SwiftData

struct MemoryReelView: View {
    let memories: [MemoryEntry]
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentIndex: Int = 0
    @State private var progress: CGFloat = 0.0
    
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    private let durationPerSlide: TimeInterval = 5.0
    @State private var isPaused = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Background
                Color.black.ignoresSafeArea()
                
                if memories.isEmpty {
                    Text(String(localized: "reel.empty"))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Content
                    ReelContentView(memory: memories[currentIndex])
                        .id(currentIndex) // Force recreation on index change
                        .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                        
                    // Tap controls
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.white.opacity(0.001))
                            .frame(width: geometry.size.width * 0.3)
                            .onTapGesture {
                                previousSlide()
                            }
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.001))
                            .frame(width: geometry.size.width * 0.7)
                            .onTapGesture {
                                nextSlide()
                            }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in isPaused = true }
                            .onEnded { _ in isPaused = false }
                    )
                    
                    // Top UI
                    VStack(spacing: 12) {
                        // Progress bars
                        HStack(spacing: 4) {
                            ForEach(0..<memories.count, id: \.self) { index in
                                ReelProgressBar(
                                    isActive: index == currentIndex,
                                    isCompleted: index < currentIndex,
                                    progress: progress
                                )
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                        
                        // Header
                        HStack {
                            if let mood = memories[currentIndex].mood {
                                Text(mood.emoji)
                                    .font(.title2)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(memories[currentIndex].createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                            }
                            
                            Spacer()
                            
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.title3)
                                    .foregroundStyle(.white)
                                    .padding(8)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                }
            }
        }
        .onReceive(timer) { _ in
            guard !isPaused, !memories.isEmpty else { return }
            
            let increment = CGFloat(0.05 / durationPerSlide)
            progress += increment
            
            if progress >= 1.0 {
                nextSlide()
            }
        }
    }
    
    private func nextSlide() {
        if currentIndex < memories.count - 1 {
            currentIndex += 1
            progress = 0.0
        } else {
            dismiss() // Reached the end
        }
    }
    
    private func previousSlide() {
        if currentIndex > 0 {
            currentIndex -= 1
            progress = 0.0
        } else {
            progress = 0.0 // Restart first slide
        }
    }
}

// MARK: - Subviews

private struct ReelProgressBar: View {
    let isActive: Bool
    let isCompleted: Bool
    let progress: CGFloat
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.3))
                
                if isCompleted {
                    Capsule()
                        .fill(Color.white)
                } else if isActive {
                    Capsule()
                        .fill(Color.white)
                        .frame(width: geo.size.width * min(max(progress, 0), 1))
                }
            }
        }
        .frame(height: 3)
    }
}

private struct ReelContentView: View {
    let memory: MemoryEntry
    @State private var photoData: Data?
    
    var body: some View {
        ZStack {
            if memory.isLocked {
                VStack(spacing: 20) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.white.opacity(0.8))
                    Text(String(localized: "capsule.locked"))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.blue.opacity(0.2))
            } else {
                // Background Layer
                if let photoData = photoData, let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .overlay(Color.black.opacity(0.3))
                } else {
                    LinearGradient(
                        colors: [Color(red: 0.1, green: 0.1, blue: 0.2), Color(red: 0.05, green: 0.05, blue: 0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                
                // Content Layer
                VStack(alignment: .leading, spacing: 20) {
                    Spacer()
                    
                    if !memory.title.isEmpty {
                        Text(memory.title)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                    
                    if !memory.content.isEmpty {
                        Text(memory.content)
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(nil)
                    }
                    
                    if !memory.tags.isEmpty {
                        HStack {
                            ForEach(memory.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    
                    // Bottom padding to avoid home indicator
                    Spacer().frame(height: 40)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .task {
            if memory.type == .photo {
                photoData = await memory.loadPhotoDataAsync()
            }
        }
    }
}

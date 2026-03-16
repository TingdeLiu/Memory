import SwiftUI

struct MemoryCardView: View {
    let memory: MemoryEntry
    @State private var photoData: Data?
    @State private var thumbnailData: Data?
    @AppStorage("encryptionLevel") private var encryptionLevelRaw = "cloudOnly"

    private var isFullEncryption: Bool {
        EncryptionLevel(rawValue: encryptionLevelRaw) == .full
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if memory.isLocked {
                lockedContent
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    // Media Content (Full-width card top)
                    if memory.type == .photo || memory.type == .video {
                        mediaContent
                    } else if memory.type == .audio {
                        audioContent
                    }

                    // Text Content
                    textContent
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.accentColor.opacity(isFullEncryption ? 0.3 : 0), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
        .sensoryFeedback(.impact(weight: .light), trigger: memory.id)
        .task {
            guard !memory.isLocked else { return }
            // Asynchronously load encrypted media if necessary
            if memory.type == .photo {
                photoData = await memory.loadPhotoDataAsync()
            } else if memory.type == .video {
                thumbnailData = await memory.loadVideoThumbnailAsync()
            }
        }
    }

    private var lockedContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            
            Text(String(localized: "capsule.locked"))
                .font(.headline)
            
            if let unlockDate = memory.unlockDate {
                Text(String(localized: "capsule.unlocks_on \(unlockDate.formatted(date: .abbreviated, time: .omitted))"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.secondarySystemBackground))
    }

    private var textContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                if let mood = memory.mood {
                    Text(mood.emoji)
                        .font(.title3)
                }
                
                Text(memory.title.isEmpty ? String(localized: "timeline.untitled") : memory.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                
                Spacer()
                
                if memory.isPrivate {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }

            if !memory.content.isEmpty {
                Text(memory.content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .padding(.top, 2)
            }

            // Metadata Footer
            HStack(spacing: 8) {
                Label(memory.createdAt.formatted(date: .omitted, time: .shortened), systemImage: "clock")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                if !memory.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(memory.tags.prefix(2), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2)
                                .foregroundStyle(Color.accentColor)
                        }
                        if memory.tags.count > 2 {
                            Text("+\(memory.tags.count - 2)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
    }

    private var mediaContent: some View {
        ZStack {
            if let data = (memory.type == .photo ? photoData : thumbnailData), let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(height: 200)
                    .overlay {
                        Image(systemName: memory.type == .photo ? "photo" : "video")
                            .font(.largeTitle)
                            .foregroundStyle(Color.accentColor.opacity(0.3))
                    }
            }

            if memory.type == .video {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(radius: 5)
            }
            
            // Type badge
            VStack {
                HStack {
                    Spacer()
                    Text(memory.type == .photo ? String(localized: "timeline.type.photo") : String(localized: "timeline.type.video"))
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(12)
                }
                Spacer()
            }
        }
        .frame(height: 200)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
    }

    private var audioContent: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: "waveform")
                    .foregroundStyle(.orange)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "timeline.type.voice"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
                
                if let duration = memory.audioDuration {
                    Text(formatDuration(duration))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Mini waveform visualization placeholder
            HStack(spacing: 2) {
                ForEach(0..<8) { _ in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.orange.opacity(0.3))
                        .frame(width: 3, height: CGFloat.random(in: 10...25))
                }
            }
        }
        .padding(16)
        .background(Color.orange.opacity(0.05))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

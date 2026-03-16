import SwiftUI
import SwiftData
import PhotosUI

struct AvatarView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [AvatarProfile]

    private var avatarService: AvatarService { AvatarService.shared }
    @State private var aiService = AIService()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingStylePicker = false
    @State private var showingSettings = false
    @State private var showingExport = false
    @State private var isProcessing = false
    @State private var errorMessage: String?

    private var profile: AvatarProfile? {
        profiles.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Avatar Preview
                    avatarPreview

                    // Action Buttons
                    if profile?.hasPhoto == true {
                        actionButtons
                    }

                    // Photo Picker
                    photoPicker

                    // Style Selection (when has photo)
                    if profile?.hasPhoto == true {
                        styleSelection
                    }

                    // Frame Selection (when has photo)
                    if profile?.hasPhoto == true {
                        frameSelection
                    }

                    // Stylization Section
                    if profile?.hasPhoto == true {
                        stylizationSection
                    }
                }
                .padding()
            }
            .navigationTitle(String(localized: "avatar.title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                AvatarSettingsView(profile: ensureProfile())
            }
            .sheet(isPresented: $showingExport) {
                if let image = avatarService.exportAvatar(profile: ensureProfile()) {
                    ShareSheet(activityItems: [image])
                }
            }
            .alert(String(localized: "avatar.error.title"), isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button(String(localized: "common.done")) {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
            .onAppear {
                ensureProfileExists()
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                if let newItem {
                    loadPhoto(from: newItem)
                }
            }
        }
    }

    // MARK: - Avatar Preview

    private var avatarPreview: some View {
        VStack(spacing: 16) {
            // Avatar Display
            ZStack {
                // Background
                avatarBackground
                    .frame(width: 200, height: 200)

                // Image or Placeholder
                if let displayImage = profile?.displayImage {
                    displayImage
                        .resizable()
                        .scaledToFill()
                        .frame(width: 200, height: 200)
                        .modifier(AvatarClipModifier(frameStyle: profile?.frameStyle ?? .circle))
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.secondary)
                }

                // Processing Overlay
                if isProcessing || avatarService.isStylizing {
                    Color.black.opacity(0.5)
                        .modifier(AvatarClipModifier(frameStyle: profile?.frameStyle ?? .circle))

                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                }
            }
            .modifier(AvatarClipModifier(frameStyle: profile?.frameStyle ?? .circle))
            .overlay(avatarStroke)
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)

            // Status
            if let profile = profile {
                if profile.hasStylizedVersion && profile.useStylizedVersion {
                    Label(String(localized: "avatar.using_stylized"), systemImage: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.purple)
                } else if profile.stylizationStatus == .processing {
                    Label(String(localized: "avatar.stylizing"), systemImage: "wand.and.stars")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private var avatarBackground: some View {
        let color = profile?.backgroundColorValue ?? .gray.opacity(0.2)
        switch profile?.frameStyle ?? .circle {
        case .circle:
            Circle().fill(color)
        case .roundedSquare:
            RoundedRectangle(cornerRadius: 40).fill(color)
        case .square:
            Rectangle().fill(color)
        case .hexagon:
            HexagonShape().fill(color)
        }
    }

    private func clipAvatar<V: View>(_ view: V) -> some View {
        switch profile?.frameStyle ?? .circle {
        case .circle:
            AnyView(view.clipShape(Circle()))
        case .roundedSquare:
            AnyView(view.clipShape(RoundedRectangle(cornerRadius: 40)))
        case .square:
            AnyView(view.clipShape(Rectangle()))
        case .hexagon:
            AnyView(view.clipShape(HexagonShape()))
        }
    }

    @ViewBuilder
    private var avatarStroke: some View {
        switch profile?.frameStyle ?? .circle {
        case .circle:
            Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 2)
        case .roundedSquare:
            RoundedRectangle(cornerRadius: 40).stroke(Color.secondary.opacity(0.3), lineWidth: 2)
        case .square:
            Rectangle().stroke(Color.secondary.opacity(0.3), lineWidth: 2)
        case .hexagon:
            HexagonShape().stroke(Color.secondary.opacity(0.3), lineWidth: 2)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Toggle Stylized
            if profile?.hasStylizedVersion == true {
                Button {
                    profile?.useStylizedVersion.toggle()
                    try? modelContext.save()
                } label: {
                    HStack {
                        Image(systemName: profile?.useStylizedVersion == true ? "photo" : "sparkles")
                        Text(profile?.useStylizedVersion == true
                             ? String(localized: "avatar.show_original")
                             : String(localized: "avatar.show_stylized"))
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.purple.opacity(0.15))
                    .foregroundStyle(.purple)
                    .clipShape(Capsule())
                }
            }

            // Export
            Button {
                showingExport = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text(String(localized: "avatar.export"))
                }
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.15))
                .foregroundStyle(.blue)
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Photo Picker

    private var photoPicker: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack {
                    Image(systemName: profile?.hasPhoto == true ? "arrow.triangle.2.circlepath.camera" : "camera.fill")
                    Text(profile?.hasPhoto == true
                         ? String(localized: "avatar.change_photo")
                         : String(localized: "avatar.upload_photo"))
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Text(String(localized: "avatar.photo_hint"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Style Selection

    private var styleSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "avatar.style"))
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(AvatarStyle.allCases, id: \.rawValue) { style in
                        StyleCard(
                            style: style,
                            isSelected: profile?.style == style
                        ) {
                            profile?.style = style
                            try? modelContext.save()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Frame Selection

    private var frameSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "avatar.frame"))
                .font(.headline)

            HStack(spacing: 16) {
                ForEach(AvatarFrameStyle.allCases, id: \.rawValue) { frame in
                    Button {
                        profile?.frameStyle = frame
                        try? modelContext.save()
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: frame.icon)
                                .font(.title2)
                                .frame(width: 50, height: 50)
                                .background(profile?.frameStyle == frame ? Color.blue.opacity(0.2) : Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            Text(frame.label)
                                .font(.caption2)
                        }
                        .foregroundStyle(profile?.frameStyle == frame ? .blue : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Stylization Section

    private var stylizationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "avatar.ai_stylize"))
                    .font(.headline)

                Spacer()

                if profile?.stylizationStatus == .ready {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            Text(String(localized: "avatar.ai_stylize.desc"))
                .font(.caption)
                .foregroundStyle(.secondary)

            if avatarService.isStylizing {
                VStack(spacing: 8) {
                    ProgressView(value: avatarService.stylizationProgress)
                        .tint(.purple)

                    Text(String(localized: "avatar.stylizing"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    stylizeAvatar()
                } label: {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text(profile?.hasStylizedVersion == true
                             ? String(localized: "avatar.restylize")
                             : String(localized: "avatar.generate_style"))
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            Text(String(localized: "avatar.stylize_note"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions

    private func loadPhoto(from item: PhotosPickerItem) {
        isProcessing = true

        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    throw AvatarError.invalidImage
                }

                let currentProfile = ensureProfile()
                avatarService.processImage(image, profile: currentProfile)
                try? modelContext.save()

            } catch {
                errorMessage = error.localizedDescription
            }

            isProcessing = false
            selectedPhotoItem = nil
        }
    }

    private func stylizeAvatar() {
        guard let currentProfile = profile else { return }

        Task {
            do {
                try await avatarService.stylizeAvatar(
                    profile: currentProfile,
                    aiService: aiService
                )
                currentProfile.useStylizedVersion = true
                try? modelContext.save()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func ensureProfileExists() {
        if profiles.isEmpty {
            let newProfile = AvatarProfile()
            modelContext.insert(newProfile)
            try? modelContext.save()
        }
    }

    private func ensureProfile() -> AvatarProfile {
        if let existing = profiles.first {
            return existing
        }
        let newProfile = AvatarProfile()
        modelContext.insert(newProfile)
        try? modelContext.save()
        return newProfile
    }
}

// MARK: - Style Card

private struct StyleCard: View {
    let style: AvatarStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(style.defaultBackgroundColor)
                        .frame(width: 60, height: 60)

                    Image(systemName: style.icon)
                        .font(.title2)
                        .foregroundStyle(isSelected ? .white : .primary)
                }
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                )

                Text(style.label)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .blue : .primary)
            }
            .padding(8)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Hexagon Shape

struct HexagonShape: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - insetAmount

        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 2
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> HexagonShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}

// MARK: - Avatar Clip Modifier

private struct AvatarClipModifier: ViewModifier {
    let frameStyle: AvatarFrameStyle

    func body(content: Content) -> some View {
        switch frameStyle {
        case .circle:
            content.clipShape(Circle())
        case .roundedSquare:
            content.clipShape(RoundedRectangle(cornerRadius: 40))
        case .square:
            content.clipShape(Rectangle())
        case .hexagon:
            content.clipShape(HexagonShape())
        }
    }
}

#Preview {
    AvatarView()
        .modelContainer(for: [AvatarProfile.self], inMemory: true)
}

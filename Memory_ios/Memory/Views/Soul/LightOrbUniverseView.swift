import SwiftUI
import SwiftData
import CoreMotion

// MARK: - Orb Order Storage

private enum OrbOrderStorage {
    private static let key = "com.tyndall.memory.orbOrder"

    static func load() -> [UUID] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let uuids = try? JSONDecoder().decode([UUID].self, from: data) else {
            return []
        }
        return uuids
    }

    static func save(_ order: [UUID]) {
        if let data = try? JSONEncoder().encode(order) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - Motion Manager

@Observable
class MotionManager {
    var pitch: Double = 0
    var roll: Double = 0

    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()

    func start() {
        guard motionManager.isDeviceMotionAvailable else { return }

        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let motion = motion else { return }
            DispatchQueue.main.async {
                self?.pitch = motion.attitude.pitch
                self?.roll = motion.attitude.roll
            }
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }
}

// MARK: - Light Orb Universe View

struct LightOrbUniverseView: View {
    var showCloseButton: Bool = true

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query(sort: \Contact._plainName) private var contacts: [Contact]
    @Query private var soulProfiles: [SoulProfile]
    @Query private var avatarProfiles: [AvatarProfile]

    @State private var isRotating = true
    @State private var rotationAngle: Double = 0
    @State private var selectedContact: Contact?
    @State private var showingChat = false
    @State private var centralOrbScale: CGFloat = 1.0
    @State private var centralOrbGlow: CGFloat = 0.5

    // Interaction states
    @State private var editingContact: Contact?
    @State private var showingContactEditor = false
    @State private var showingAddContact = false
    @State private var showingReflectionEditor = false
    @State private var draggedContact: Contact?
    @State private var dragOffset: CGSize = .zero
    @State private var orbOrder: [UUID] = []

    // Motion for parallax
    @State private var motionManager = MotionManager()

    // Timer control
    @State private var isTimerActive = true
    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect() 

    private let maxOrbSlots = 8

    private var soulProfile: SoulProfile? { soulProfiles.first }
    private var avatarProfile: AvatarProfile? { avatarProfiles.first }

    // Constants for Solar System style
    private let orbitFlattening: CGFloat = 0.35 // Perspective compression

    private var orderedContacts: [Contact] {
        if orbOrder.isEmpty {
            return Array(contacts.prefix(maxOrbSlots))
        }
        var ordered: [Contact] = []
        for id in orbOrder {
            if let contact = contacts.first(where: { $0.id == id }) {
                ordered.append(contact)
            }
        }
        for contact in contacts where !orbOrder.contains(contact.id) && ordered.count < maxOrbSlots {
            ordered.append(contact)
        }
        return Array(ordered.prefix(maxOrbSlots))
    }

    init(showCloseButton: Bool = true) {
        self.showCloseButton = showCloseButton
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                let orbitRadiusX = geometry.size.width * 0.42
                let orbitRadiusY = orbitRadiusX * orbitFlattening

                ZStack {
                    backgroundGradient

                    // Orbit path (Ellipse for perspective)
                    Ellipse()
                        .stroke(
                            LinearGradient(
                                colors: [.clear, .blue.opacity(0.3), .purple.opacity(0.3), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 1, dash: [2, 4])
                        )
                        .frame(width: orbitRadiusX * 2, height: orbitRadiusY * 2)
                        .position(center)

                    // Satellite Orbs
                    ForEach(Array(orderedContacts.enumerated()), id: \.element.id) { index, contact in
                        let angle = angleForOrb(index: index, total: maxOrbSlots)
                        let basePosition = positionOnEllipticalOrbit(center: center, radiusX: orbitRadiusX, radiusY: orbitRadiusY, angle: angle)

                        let depth = depthInfo(for: angle)
                        let isDragging = draggedContact?.id == contact.id

                        ContactOrbView(
                            contact: contact,
                            isRotating: isRotating && !isDragging && !reduceMotion,
                            depthScale: depth.scale,
                            reduceMotion: reduceMotion
                        )
                        .position(isDragging ? CGPoint(
                            x: basePosition.x + dragOffset.width,
                            y: basePosition.y + dragOffset.height
                        ) : basePosition)
                        .zIndex(isDragging ? 1000 : depth.zIndex)
                        .scaleEffect(isDragging ? 1.2 : depth.scale)
                        .blur(radius: isDragging ? 0 : (1.0 - depth.scale) * 2)
                        .opacity(0.5 + depth.scale * 0.5) 
                        .onTapGesture {
                            guard !isDragging else { return }
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                            selectedContact = contact
                            showingChat = true
                        }
                        .gesture(orbDragGesture(contact: contact))
                        .onChange(of: rotationAngle) { _, _ in
                            // Haptic feedback when planet passes the "closest" point (90 degrees)
                            if Int(angle) == 90 {
                                let impact = UIImpactFeedbackGenerator(style: .soft)
                                impact.impactOccurred(intensity: 0.4)
                            }
                        }
                    }

                    // Empty slots
                    if orderedContacts.count < maxOrbSlots {
                        ForEach(orderedContacts.count..<maxOrbSlots, id: \.self) { index in
                            let angle = angleForOrb(index: index, total: maxOrbSlots)
                            let position = positionOnEllipticalOrbit(center: center, radiusX: orbitRadiusX, radiusY: orbitRadiusY, angle: angle)
                            let depth = depthInfo(for: angle)

                            AddOrbButton(reduceMotion: reduceMotion)
                                .position(position)
                                .zIndex(depth.zIndex)
                                .scaleEffect(depth.scale * 0.8)
                                .opacity(0.3 + depth.scale * 0.3)
                                .onTapGesture {
                                    showingAddContact = true
                                }
                        }
                    }

                    // Central orb (user) - The Sun
                    CentralOrbView(
                        soulProfile: soulProfile,
                        avatarProfile: avatarProfile,
                        scale: reduceMotion ? 1.0 : centralOrbScale,
                        glowIntensity: centralOrbGlow
                    )
                    .position(center)
                    .zIndex(500) // Middle layer
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            isRotating.toggle()
                        }
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                    }

                    // Status indicator & UI...
                    statusOverlay
                    
                    // Proactive Soul Prompt
                    if let prompt = soulProfile?.suggestedReflection, !contacts.isEmpty {
                        proactivePromptView(prompt: prompt)
                    }
                }
            }
            .navigationTitle(String(localized: "orb.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { universeToolbar }
            .sheet(isPresented: $showingChat) { if let c = selectedContact { OrbChatView(contact: c) } }
            .sheet(isPresented: $showingAddContact) { ContactEditorView() }
            .sheet(isPresented: $showingReflectionEditor) { MemoryEditorView() }
            .onReceive(timer) { _ in
                if isRotating && !reduceMotion {
                    rotationAngle += 0.2
                    if rotationAngle >= 360 { rotationAngle = 0 }
                }
            }
            .onAppear {
                orbOrder = OrbOrderStorage.load()
                if !reduceMotion {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        centralOrbScale = 1.05
                    }
                    withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                        centralOrbGlow = 0.8
                    }
                    motionManager.start()
                }
            }
            .onDisappear {
                motionManager.stop()
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Components

    private var statusOverlay: some View {
        VStack {
            if contacts.isEmpty {
                emptyStateView
            } else {
                VStack(spacing: 4) {
                    Text(String(localized: "orb.hint"))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.top, 100)
            }
            Spacer()
            HStack(spacing: 8) {
                Circle().fill(isRotating ? Color.green : Color.orange).frame(width: 6, height: 6)
                Text(isRotating ? String(localized: "orb.rotating") : String(localized: "orb.paused"))
                    .font(.caption2).foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 12).padding(.vertical, 6).background(.ultraThinMaterial).clipShape(Capsule())
            .padding(.bottom, 30)
        }
    }

    private func proactivePromptView(prompt: String) -> some View {
        VStack {
            Spacer()
            Button {
                showingReflectionEditor = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.yellow)
                        .symbolEffect(.variableColor.iterative, options: .repeating)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "soul.proactive.title"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.yellow.opacity(0.8))
                            .textCase(.uppercase)
                        
                        Text(prompt)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 100)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Text(String(localized: "orb.empty.title")).font(.headline)
            Text(String(localized: "orb.empty.subtitle")).font(.subheadline).multilineTextAlignment(.center)
            Button { showingAddContact = true } label: {
                Text(String(localized: "orb.empty.addButton")).padding().background(Color.blue).clipShape(Capsule())
            }
        }
        .padding(40).padding(.top, 100).foregroundStyle(.white)
    }

    private var universeToolbar: some ToolbarContent {
        Group {
            if showCloseButton {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.6)) }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAddContact = true } label: { Image(systemName: "person.badge.plus").foregroundStyle(.white.opacity(0.6)) }
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        let theme = soulProfile?.getUniverseTheme() ?? 
            SoulProfile.UniverseTheme(colors: [Color(red: 0.05, green: 0.05, blue: 0.15), Color(red: 0.1, green: 0.05, blue: 0.2), Color(red: 0.05, green: 0.02, blue: 0.1)], starColor: .white)
        
        return ZStack {
            LinearGradient(
                colors: theme.colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Nebula Layer (Parallax based on motion)
            Circle()
                .fill(theme.colors[1].opacity(0.4))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(x: -150 + motionManager.roll * 20, y: -250 + motionManager.pitch * 20)
            
            StarsView(starColor: theme.starColor)
                .offset(x: motionManager.roll * 10, y: motionManager.pitch * 10)
        }
    }

    // MARK: - Helpers

    private func angleForOrb(index: Int, total: Int) -> Double {
        let baseAngle = (360.0 / Double(total)) * Double(index)
        return (baseAngle + rotationAngle).truncatingRemainder(dividingBy: 360)
    }

    private func positionOnEllipticalOrbit(center: CGPoint, radiusX: CGFloat, radiusY: CGFloat, angle: Double) -> CGPoint {
        let radians = angle * .pi / 180
        return CGPoint(
            x: center.x + radiusX * CGFloat(cos(radians)),
            y: center.y + radiusY * CGFloat(sin(radians))
        )
    }

    private func depthInfo(for angle: Double) -> (scale: CGFloat, zIndex: Double) {
        let radians = angle * .pi / 180
        let sinVal = sin(radians) // 1 at bottom (close), -1 at top (far)
        let scale = 0.75 + (sinVal + 1.0) / 2.0 * 0.35 // [0.75, 1.1]
        let zIndex = 500 + sinVal * 400 // [100, 900]
        return (scale, zIndex)
    }

    private func orbDragGesture(contact: Contact) -> some Gesture {
        DragGesture()
            .onChanged { value in
                draggedContact = contact
                dragOffset = value.translation
                isRotating = false
            }
            .onEnded { _ in
                draggedContact = nil
                dragOffset = .zero
                isRotating = true
            }
    }
}

// MARK: - Add Orb Button

private struct AddOrbButton: View {
    let reduceMotion: Bool
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.2), .white.opacity(0.05), .clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 35
                    )
                )
                .frame(width: 70, height: 70)

            Circle()
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                .foregroundStyle(.white.opacity(0.3))
                .frame(width: 50, height: 50)

            Image(systemName: "plus")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .scaleEffect(pulseScale)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseScale = 1.1
            }
        }
    }
}

// MARK: - Central Orb View

private struct CentralOrbView: View {
    let soulProfile: SoulProfile?
    let avatarProfile: AvatarProfile?
    let scale: CGFloat
    let glowIntensity: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .purple.opacity(glowIntensity * 0.6),
                            .blue.opacity(glowIntensity * 0.3),
                            .clear
                        ],
                        center: .center,
                        startRadius: 40,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.9), .purple.opacity(0.8), .blue.opacity(0.6)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 50
                    )
                )
                .frame(width: 100, height: 100)
                .shadow(color: .purple.opacity(0.8), radius: 20)
                .shadow(color: .blue.opacity(0.5), radius: 40)

            if let avatarProfile = avatarProfile,
               let photoData = avatarProfile.originalPhotoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 70, height: 70)
                    .clipShape(Circle())
            } else if let name = soulProfile?.nickname, let first = name.first {
                Text(String(first).uppercased())
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
            }
        }
        .scaleEffect(scale)
    }
}

// MARK: - Contact Orb View

private struct ContactOrbView: View {
    let contact: Contact
    let isRotating: Bool
    let depthScale: CGFloat
    let reduceMotion: Bool

    @State private var pulseScale: CGFloat = 1.0

    private var orbColor: Color {
        switch contact.relationship {
        case .family: return .orange
        case .partner: return .pink
        case .friend: return .blue
        case .colleague: return .purple
        case .mentor: return .green
        case .other: return .gray
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [orbColor.opacity(0.6), orbColor.opacity(0.2), .clear],
                        center: .center,
                        startRadius: 15,
                        endRadius: 40
                    )
                )
                .frame(width: 80, height: 80)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.9), orbColor.opacity(0.8), orbColor.opacity(0.5)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 25
                    )
                )
                .frame(width: 50, height: 50)
                .shadow(color: orbColor.opacity(0.8), radius: 10)

            if let avatarData = contact.avatarData,
               let uiImage = UIImage(data: avatarData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
            } else {
                Text(String(contact.name.prefix(1)).uppercased())
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack {
                Spacer().frame(height: 55)
                Text(contact.name)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
        }
        .scaleEffect(pulseScale)
        .onAppear {
            guard isRotating && !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.1
            }
        }
        .onChange(of: isRotating) { _, rotating in
            guard !reduceMotion else { return }
            if rotating {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseScale = 1.1
                }
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    pulseScale = 1.0
                }
            }
        }
    }
}

// MARK: - Stars View

private struct StarsView: View {
    let starColor: Color
    @State private var stars: [Star] = []

    var body: some View {
        Canvas { context, size in
            for star in stars {
                let rect = CGRect(
                    x: star.x * size.width,
                    y: star.y * size.height,
                    width: star.size,
                    height: star.size
                )
                context.fill(Circle().path(in: rect), with: .color(starColor.opacity(star.opacity)))
            }
        }
        .onAppear {
            if stars.isEmpty {
                stars = (0..<120).map { _ in
                    Star(
                        x: CGFloat.random(in: 0...1),
                        y: CGFloat.random(in: 0...1),
                        size: CGFloat.random(in: 0.5...2.5),
                        opacity: Double.random(in: 0.2...0.8)
                    )
                }
            }
        }
    }
}

private struct Star {
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let opacity: Double
}

// MARK: - Orb Chat View

struct OrbChatView: View {
    let contact: Contact
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [String] = []
    @State private var inputText = ""

    var body: some View {
        NavigationStack {
            VStack {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages, id: \.self) { message in
                            Text(message)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding()
                }

                HStack {
                    TextField(String(localized: "orbChat.placeholder"), text: $inputText)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        if !inputText.isEmpty {
                            messages.append(inputText)
                            inputText = ""
                        }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .disabled(inputText.isEmpty)
                }
                .padding()
            }
            .navigationTitle(contact.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "common.close")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    LightOrbUniverseView()
        .modelContainer(for: [Contact.self, Message.self, MemoryEntry.self, SoulProfile.self, AvatarProfile.self, DigitalSelfConfig.self, VoiceProfile.self, WritingStyleProfile.self], inMemory: true)
}

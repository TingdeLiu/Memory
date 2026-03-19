import SwiftUI

/// Immersive full-screen reveal animation when a time capsule is opened.
struct CapsuleRevealView: View {
    let capsule: TimeCapsule
    let onDismiss: () -> Void

    @State private var phase: RevealPhase = .sealed
    @State private var particleSystem = ParticleSystem()

    private enum RevealPhase {
        case sealed, glowing, bursting, revealing, complete
    }

    var body: some View {
        ZStack {
            // Deep background
            Color.black.ignoresSafeArea()

            // Star field
            Canvas { context, size in
                for particle in particleSystem.particles {
                    let rect = CGRect(
                        x: particle.x * size.width,
                        y: particle.y * size.height,
                        width: particle.size,
                        height: particle.size
                    )
                    context.fill(
                        Circle().path(in: rect),
                        with: .color(.white.opacity(particle.opacity))
                    )
                }
            }
            .ignoresSafeArea()

            // Central capsule
            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    // Glow rings
                    if phase != .sealed {
                        ForEach(0..<3) { i in
                            Circle()
                                .stroke(
                                    capsuleGradient.opacity(phase == .bursting ? 0.8 : 0.3),
                                    lineWidth: phase == .bursting ? 4 : 2
                                )
                                .frame(
                                    width: phase == .bursting ? CGFloat(200 + i * 80) : CGFloat(120 + i * 40),
                                    height: phase == .bursting ? CGFloat(200 + i * 80) : CGFloat(120 + i * 40)
                                )
                                .scaleEffect(phase == .bursting ? 1.5 : 1.0)
                                .opacity(phase == .complete ? 0 : 1)
                        }
                    }

                    // Core orb
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: orbColors,
                                center: .center,
                                startRadius: 5,
                                endRadius: phase == .bursting ? 80 : 50
                            )
                        )
                        .frame(width: orbSize, height: orbSize)
                        .shadow(color: orbShadowColor, radius: phase == .glowing ? 30 : 10)

                    // Icon
                    Image(systemName: phase == .complete ? "gift.fill" : "hourglass")
                        .font(.system(size: phase == .complete ? 50 : 40))
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, value: phase == .bursting)
                }
                .onTapGesture {
                    if phase == .sealed {
                        startReveal()
                    }
                }

                Spacer().frame(height: 40)

                // Text content
                VStack(spacing: 16) {
                    if phase == .sealed {
                        Text(String(localized: "capsuleReveal.tapToOpen"))
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.8))
                            .transition(.opacity)

                        capsuleInfoText
                    }

                    if phase == .complete {
                        revealedContent
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity
                            ))
                    }
                }
                .animation(.easeInOut(duration: 0.6), value: phase)

                Spacer()

                // Dismiss button
                if phase == .complete {
                    Button {
                        onDismiss()
                    } label: {
                        Text(String(localized: "capsuleReveal.continue"))
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: 280)
                            .padding(.vertical, 16)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                    .padding(.bottom, 60)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .sensoryFeedback(.success, trigger: phase == .complete)
        .onAppear {
            particleSystem.generateStars(count: 60)
        }
    }

    // MARK: - Reveal Animation

    private func startReveal() {
        // Phase 1: Glow
        withAnimation(.easeIn(duration: 0.8)) {
            phase = .glowing
        }

        // Phase 2: Burst
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                phase = .bursting
            }
        }

        // Phase 3: Reveal content
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.8)) {
                phase = .revealing
            }
        }

        // Phase 4: Complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
            withAnimation(.easeInOut(duration: 0.6)) {
                phase = .complete
            }
        }
    }

    // MARK: - Visual Properties

    private var orbSize: CGFloat {
        switch phase {
        case .sealed: return 100
        case .glowing: return 110
        case .bursting: return 140
        case .revealing: return 80
        case .complete: return 90
        }
    }

    private var orbColors: [Color] {
        switch capsule.unlockType {
        case .date: return [.orange, .yellow.opacity(0.6), .orange.opacity(0.2)]
        case .location: return [.blue, .cyan.opacity(0.6), .blue.opacity(0.2)]
        case .event: return [.purple, .pink.opacity(0.6), .purple.opacity(0.2)]
        }
    }

    private var orbShadowColor: Color {
        switch capsule.unlockType {
        case .date: return .orange.opacity(0.6)
        case .location: return .blue.opacity(0.6)
        case .event: return .purple.opacity(0.6)
        }
    }

    private var capsuleGradient: LinearGradient {
        LinearGradient(
            colors: orbColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var capsuleInfoText: some View {
        VStack(spacing: 8) {
            Label(capsule.unlockType.label, systemImage: capsule.unlockType.icon)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))

            Text(capsule.createdAt.formatted(date: .long, time: .omitted))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.3))
        }
    }

    private var revealedContent: some View {
        VStack(spacing: 16) {
            if let memory = capsule.memory {
                if let mood = memory.mood {
                    Text(mood.emoji)
                        .font(.system(size: 48))
                }

                Text(memory.title.isEmpty ? String(localized: "timeline.untitled") : memory.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                if !memory.content.isEmpty {
                    Text(memory.content)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineLimit(6)
                        .padding(.horizontal, 32)
                }

                Text(memory.createdAt.formatted(date: .long, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }
}

// MARK: - Particle System

private struct Particle: Identifiable {
    let id = UUID()
    var x: Double
    var y: Double
    var size: Double
    var opacity: Double
}

private struct ParticleSystem {
    var particles: [Particle] = []

    mutating func generateStars(count: Int) {
        particles = (0..<count).map { _ in
            Particle(
                x: Double.random(in: 0...1),
                y: Double.random(in: 0...1),
                size: Double.random(in: 1...3),
                opacity: Double.random(in: 0.1...0.6)
            )
        }
    }
}

import SwiftUI

struct WaveformView: View {
    let level: Float
    let isActive: Bool
    private let barCount = 40

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                WaveformBar(
                    level: level,
                    index: index,
                    totalBars: barCount,
                    isActive: isActive
                )
            }
        }
        .padding(.horizontal)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "voiceRecording.waveform"))
    }
}

struct WaveformBar: View {
    let level: Float
    let index: Int
    let totalBars: Int
    let isActive: Bool

    @State private var animatedHeight: CGFloat = 0.05
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(isActive ? Color.accentColor : Color(.systemGray4))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(y: animatedHeight, anchor: .center)
            .onChange(of: level) { _, newLevel in
                if reduceMotion {
                    animatedHeight = isActive ? CGFloat(max(0.05, newLevel)) : 0.05
                } else {
                    withAnimation(.easeInOut(duration: 0.08)) {
                        if isActive {
                            let center = Float(totalBars) / 2.0
                            let distance = abs(Float(index) - center) / center
                            let variation = Float.random(in: 0.6...1.0)
                            animatedHeight = CGFloat(max(0.05, newLevel * (1.0 - distance * 0.5) * variation))
                        } else {
                            animatedHeight = 0.05
                        }
                    }
                }
            }
            .onChange(of: isActive) { _, active in
                if !active {
                    if reduceMotion {
                        animatedHeight = 0.05
                    } else {
                        withAnimation(.easeOut(duration: 0.3)) {
                            animatedHeight = 0.05
                        }
                    }
                }
            }
    }
}

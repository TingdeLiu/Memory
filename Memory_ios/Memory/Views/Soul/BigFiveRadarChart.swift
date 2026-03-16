import SwiftUI

struct BigFiveRadarChart: View {
    let scores: BigFiveScores
    let size: CGFloat
    
    private let dimensions = 5
    private var dataPoints: [Double] {
        [scores.openness, scores.conscientiousness, scores.extraversion, scores.agreeableness, scores.neuroticism]
    }
    
    private let labels = [
        String(localized: "bigfive.openness"),
        String(localized: "bigfive.conscientiousness"),
        String(localized: "bigfive.extraversion"),
        String(localized: "bigfive.agreeableness"),
        String(localized: "bigfive.neuroticism")
    ]

    var body: some View {
        ZStack {
            // Background Web
            RadarWeb(levels: 5, dimensions: dimensions)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            
            // Labels
            RadarLabels(labels: labels, radius: size / 2 + 20)
            
            // Data Shape
            RadarDataShape(data: dataPoints)
                .fill(
                    RadialGradient(
                        colors: [.blue.opacity(0.7), .purple.opacity(0.5)],
                        center: .center,
                        startRadius: 0,
                        endRadius: size / 2
                    )
                )
                .overlay(
                    RadarDataShape(data: dataPoints)
                        .stroke(Color.blue, lineWidth: 2)
                )
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: dataPoints)
        }
        .frame(width: size, height: size)
    }
}

private struct RadarWeb: Shape {
    let levels: Int
    let dimensions: Int
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        
        for level in 1...levels {
            let currentRadius = radius * CGFloat(level) / CGFloat(levels)
            for i in 0..<dimensions {
                let angle = CGFloat(i) * (2 * .pi / CGFloat(dimensions)) - .pi / 2
                let point = CGPoint(
                    x: center.x + currentRadius * cos(angle),
                    y: center.y + currentRadius * sin(angle)
                )
                if i == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.closeSubpath()
        }
        
        // Spokes
        for i in 0..<dimensions {
            let angle = CGFloat(i) * (2 * .pi / CGFloat(dimensions)) - .pi / 2
            path.move(to: center)
            path.addLine(to: CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            ))
        }
        
        return path
    }
}

private struct RadarDataShape: Shape {
    let data: [Double]
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        
        for (i, value) in data.enumerated() {
            let angle = CGFloat(i) * (2 * .pi / CGFloat(data.count)) - .pi / 2
            let point = CGPoint(
                x: center.x + radius * CGFloat(value) * cos(angle),
                y: center.y + radius * CGFloat(value) * sin(angle)
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
}

private struct RadarLabels: View {
    let labels: [String]
    let radius: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            ForEach(0..<labels.count, id: \.self) { i in
                let angle = CGFloat(i) * (2 * .pi / CGFloat(labels.count)) - .pi / 2
                let x = center.x + radius * cos(angle)
                let y = center.y + radius * sin(angle)
                
                Text(labels[i])
                    .font(.caption2)
                    .fontWeight(.bold)
                    .position(x: x, y: y)
            }
        }
    }
}

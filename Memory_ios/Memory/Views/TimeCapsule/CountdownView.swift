import SwiftUI

struct CountdownView: View {
    let targetDate: Date?
    var style: CountdownStyle = .compact

    enum CountdownStyle {
        case compact    // Single line: "3d 12h 45m"
        case detailed   // Cards: days | hours | minutes | seconds
    }

    var body: some View {
        if let targetDate, targetDate > Date() {
            TimelineView(.periodic(from: .now, by: 1.0)) { context in
                let remaining = targetDate.timeIntervalSince(context.date)
                if remaining > 0 {
                    switch style {
                    case .compact:
                        compactCountdown(remaining: remaining)
                    case .detailed:
                        detailedCountdown(remaining: remaining)
                    }
                } else {
                    readyLabel
                }
            }
        } else {
            readyLabel
        }
    }

    private func compactCountdown(remaining: TimeInterval) -> some View {
        let days = Int(remaining) / 86400
        let hours = (Int(remaining) % 86400) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        return HStack(spacing: 4) {
            Image(systemName: "hourglass")
                .font(.caption2)
            if days > 0 {
                Text(String(localized: "capsule.countdown.daysHours \(days) \(hours)"))
                    .font(.caption)
            } else if hours > 0 {
                let secs = Int(remaining) % 60
                Text(String(localized: "capsule.countdown.hms \(hours) \(minutes) \(secs)"))
                    .font(.caption)
            } else {
                let secs = Int(remaining) % 60
                Text(String(localized: "capsule.countdown.ms \(minutes) \(secs)"))
                    .font(.caption)
            }
        }
        .foregroundStyle(.orange)
        .fontWeight(.medium)
    }

    private func detailedCountdown(remaining: TimeInterval) -> some View {
        let days = Int(remaining) / 86400
        let hours = (Int(remaining) % 86400) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60

        return HStack(spacing: 12) {
            if days > 0 {
                countdownUnit(value: days, label: String(localized: "capsule.unit.days"))
            }
            countdownUnit(value: hours, label: String(localized: "capsule.unit.hours"))
            countdownUnit(value: minutes, label: String(localized: "capsule.unit.min"))
            countdownUnit(value: seconds, label: String(localized: "capsule.unit.sec"))
        }
    }

    private func countdownUnit(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title2)
                .fontWeight(.bold)
                .monospacedDigit()
                .frame(minWidth: 44)
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var readyLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
            Text(String(localized: "capsule.countdown.ready"))
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundStyle(.green)
    }
}

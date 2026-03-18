import SwiftUI
import SwiftData
import MapKit

struct TimeCapsuleEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var existingCapsule: TimeCapsule?

    // Step state
    @State private var currentStep: EditorStep = .content
    @State private var didSeal = false

    // Memory content
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var selectedMood: Mood?

    // Unlock config
    @State private var unlockType: CapsuleUnlockType = .date
    @State private var unlockDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()

    // Location
    @State private var locationSearchText: String = ""
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var selectedLocationName: String = ""
    @State private var unlockRadius: Double = 200
    @State private var searchResults: [MKMapItem] = []
    @State private var mapCameraPosition: MapCameraPosition = .automatic

    // Event
    @State private var eventDescription: String = ""
    @State private var hasEventTargetDate: Bool = false
    @State private var eventTargetDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

    private var isEditing: Bool { existingCapsule != nil }

    enum EditorStep: Int, CaseIterable {
        case content = 0
        case condition = 1
        case confirm = 2

        var title: String {
            switch self {
            case .content: return String(localized: "capsule.step.content")
            case .condition: return String(localized: "capsule.step.condition")
            case .confirm: return String(localized: "capsule.step.confirm")
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Step indicator
                stepIndicator
                    .padding(.top, 8)

                // Content
                ScrollView {
                    VStack(spacing: 20) {
                        switch currentStep {
                        case .content:
                            contentStep
                        case .condition:
                            conditionStep
                        case .confirm:
                            confirmStep
                        }
                    }
                    .padding()
                    .padding(.bottom, 80)
                }

                // Bottom buttons
                bottomButtons
            }
            .navigationTitle(isEditing ? String(localized: "capsule.edit") : String(localized: "capsule.new"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        dismiss()
                    }
                }
            }
            .onAppear { loadExisting() }
            .sensoryFeedback(.success, trigger: didSeal)
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            ForEach(EditorStep.allCases, id: \.rawValue) { step in
                VStack(spacing: 4) {
                    Circle()
                        .fill(step.rawValue <= currentStep.rawValue ? Color.orange : Color(.systemGray4))
                        .frame(width: 28, height: 28)
                        .overlay {
                            Text("\(step.rawValue + 1)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(step.rawValue <= currentStep.rawValue ? .white : .secondary)
                        }

                    Text(step.title)
                        .font(.caption2)
                        .foregroundStyle(step == currentStep ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)

                if step.rawValue < EditorStep.allCases.count - 1 {
                    Rectangle()
                        .fill(step.rawValue < currentStep.rawValue ? Color.orange : Color(.systemGray4))
                        .frame(height: 2)
                        .padding(.bottom, 16)
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Step 1: Content

    private var contentStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "capsule.step.content.hint"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField(String(localized: "memoryEditor.title"), text: $title, axis: .vertical)
                .font(.title3.bold())
                .padding(12)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            ZStack(alignment: .topLeading) {
                TextEditor(text: $content)
                    .frame(minHeight: 150)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                if content.isEmpty {
                    Text(String(localized: "capsule.content.placeholder"))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 16)
                        .padding(.leading, 12)
                        .allowsHitTesting(false)
                }
            }
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Mood
            Text(String(localized: "memoryEditor.mood"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

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
                                    .foregroundStyle(selectedMood == mood ? Color.orange : .secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(selectedMood == mood ? Color.orange.opacity(0.12) : Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Step 2: Condition

    private var conditionStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Unlock type picker
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "capsule.condition.selectType"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(CapsuleUnlockType.allCases, id: \.self) { type in
                    Button {
                        withAnimation { unlockType = type }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: type.icon)
                                .font(.title3)
                                .frame(width: 32)
                                .foregroundStyle(unlockType == type ? .orange : .secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(type.label)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                Text(type.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if unlockType == type {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(12)
                        .background(unlockType == type ? Color.orange.opacity(0.08) : Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(unlockType == type ? Color.orange.opacity(0.3) : .clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            // Condition config
            switch unlockType {
            case .date:
                dateConditionConfig
            case .location:
                locationConditionConfig
            case .event:
                eventConditionConfig
            }
        }
    }

    private var dateConditionConfig: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "capsule.date.selectDate"))
                .font(.subheadline)
                .fontWeight(.semibold)

            DatePicker(
                "",
                selection: $unlockDate,
                in: Calendar.current.date(byAdding: .day, value: 1, to: Date())!...,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .tint(.orange)

            // Quick presets
            Text(String(localized: "capsule.date.presets"))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                datePresetButton(title: String(localized: "capsule.date.1month"), months: 1)
                datePresetButton(title: String(localized: "capsule.date.6months"), months: 6)
                datePresetButton(title: String(localized: "capsule.date.1year"), months: 12)
                datePresetButton(title: String(localized: "capsule.date.5years"), months: 60)
            }
        }
    }

    private func datePresetButton(title: String, months: Int) -> some View {
        Button {
            if let date = Calendar.current.date(byAdding: .month, value: months, to: Date()) {
                unlockDate = date
            }
        } label: {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var locationConditionConfig: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "capsule.location.selectPlace"))
                .font(.subheadline)
                .fontWeight(.semibold)

            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(String(localized: "capsule.location.search"), text: $locationSearchText)
                    .textFieldStyle(.plain)
                    .onSubmit { searchLocation() }
            }
            .padding(10)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Search results
            if !searchResults.isEmpty {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(searchResults, id: \.self) { item in
                            Button {
                                selectLocation(item)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name ?? "")
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                        if let subtitle = item.placemark.title {
                                            Text(subtitle)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 4)
                            }
                            .buttonStyle(.plain)
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 150)
            }

            // Map preview
            if let coord = selectedCoordinate {
                VStack(alignment: .leading, spacing: 4) {
                    if !selectedLocationName.isEmpty {
                        Label(selectedLocationName, systemImage: "mappin")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }

                    Map(position: $mapCameraPosition) {
                        MapCircle(
                            center: coord,
                            radius: unlockRadius
                        )
                        .foregroundStyle(.orange.opacity(0.2))
                        .stroke(.orange, lineWidth: 2)

                        Marker("", coordinate: coord)
                            .tint(.orange)
                    }
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Radius slider
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "capsule.location.radius \(Int(unlockRadius))"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $unlockRadius, in: 50...1000, step: 50)
                        .tint(.orange)
                }
            }

            // Location permission hint
            if TimeCapsuleService.shared.locationAuthorizationStatus == .notDetermined {
                Text(String(localized: "capsule.location.permissionHint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var eventConditionConfig: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "capsule.event.describe"))
                .font(.subheadline)
                .fontWeight(.semibold)

            TextField(String(localized: "capsule.event.placeholder"), text: $eventDescription, axis: .vertical)
                .lineLimit(2...4)
                .padding(12)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Toggle(isOn: $hasEventTargetDate) {
                Label(String(localized: "capsule.event.targetDate"), systemImage: "calendar")
                    .font(.subheadline)
            }

            if hasEventTargetDate {
                DatePicker(
                    "",
                    selection: $eventTargetDate,
                    in: Date()...,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)
                .tint(.orange)
            }

            Text(String(localized: "capsule.event.hint"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Step 3: Confirm

    private var confirmStep: some View {
        VStack(spacing: 20) {
            // Capsule preview
            Image(systemName: "hourglass")
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(colors: [.orange, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .padding(.top, 8)

            Text(String(localized: "capsule.confirm.title"))
                .font(.title3)
                .fontWeight(.bold)

            // Summary card
            VStack(alignment: .leading, spacing: 12) {
                SummaryRow(icon: "doc.text", label: String(localized: "capsule.confirm.memory"), value: title.isEmpty ? String(localized: "timeline.untitled") : title)

                SummaryRow(icon: unlockType.icon, label: String(localized: "capsule.confirm.condition"), value: conditionPreview)

                if let mood = selectedMood {
                    SummaryRow(icon: "heart", label: String(localized: "memoryEditor.mood"), value: "\(mood.emoji) \(mood.label)")
                }
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Warning
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(String(localized: "capsule.confirm.warning"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color.orange.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var conditionPreview: String {
        switch unlockType {
        case .date:
            return unlockDate.formatted(date: .long, time: .omitted)
        case .location:
            return selectedLocationName.isEmpty ? String(localized: "capsule.condition.location") : selectedLocationName
        case .event:
            return eventDescription.isEmpty ? String(localized: "capsule.condition.event") : eventDescription
        }
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        HStack(spacing: 12) {
            if currentStep.rawValue > 0 {
                Button {
                    withAnimation {
                        currentStep = EditorStep(rawValue: currentStep.rawValue - 1) ?? .content
                    }
                } label: {
                    Text(String(localized: "capsule.button.back"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
            }

            Button {
                if currentStep == .confirm {
                    seal()
                } else {
                    withAnimation {
                        currentStep = EditorStep(rawValue: currentStep.rawValue + 1) ?? .confirm
                    }
                }
            } label: {
                Text(currentStep == .confirm ? String(localized: "capsule.button.seal") : String(localized: "capsule.button.next"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(!canProceed)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private var canProceed: Bool {
        switch currentStep {
        case .content:
            return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                   !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .condition:
            switch unlockType {
            case .date: return unlockDate > Date()
            case .location: return selectedCoordinate != nil
            case .event: return !eventDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        case .confirm:
            return true
        }
    }

    // MARK: - Actions

    private func seal() {
        // Create memory
        let memory = MemoryEntry(
            title: title,
            content: content,
            type: .text,
            mood: selectedMood
        )
        modelContext.insert(memory)

        // Create capsule
        let capsule: TimeCapsule
        switch unlockType {
        case .date:
            capsule = TimeCapsule(
                unlockType: .date,
                unlockDate: unlockDate,
                memory: memory
            )
        case .location:
            capsule = TimeCapsule(
                unlockType: .location,
                unlockLatitude: selectedCoordinate?.latitude,
                unlockLongitude: selectedCoordinate?.longitude,
                unlockRadius: unlockRadius,
                unlockLocationName: selectedLocationName,
                memory: memory
            )
        case .event:
            capsule = TimeCapsule(
                unlockType: .event,
                eventDescription: eventDescription,
                eventTargetDate: hasEventTargetDate ? eventTargetDate : nil,
                memory: memory
            )
        }

        modelContext.insert(capsule)
        memory.timeCapsule = capsule

        // Schedule notification / geofence
        Task {
            _ = await TimeCapsuleService.shared.requestNotificationPermission()
            if unlockType == .date {
                TimeCapsuleService.shared.scheduleNotification(for: capsule)
            } else if unlockType == .location {
                TimeCapsuleService.shared.requestLocationPermission()
                TimeCapsuleService.shared.startMonitoring(capsule: capsule)
            }
        }

        didSeal = true
        dismiss()
    }

    private func searchLocation() {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = locationSearchText
        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            searchResults = response?.mapItems ?? []
        }
    }

    private func selectLocation(_ item: MKMapItem) {
        selectedCoordinate = item.placemark.coordinate
        selectedLocationName = item.name ?? ""
        locationSearchText = item.name ?? ""
        searchResults = []
        mapCameraPosition = .region(MKCoordinateRegion(
            center: item.placemark.coordinate,
            latitudinalMeters: unlockRadius * 4,
            longitudinalMeters: unlockRadius * 4
        ))
    }

    private func loadExisting() {
        guard let capsule = existingCapsule else { return }
        unlockType = capsule.unlockType
        if let date = capsule.unlockDate { unlockDate = date }
        if let lat = capsule.unlockLatitude, let lng = capsule.unlockLongitude {
            selectedCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            selectedLocationName = capsule.unlockLocationName ?? ""
            unlockRadius = capsule.unlockRadius ?? 200
            mapCameraPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                latitudinalMeters: unlockRadius * 4,
                longitudinalMeters: unlockRadius * 4
            ))
        }
        eventDescription = capsule.eventDescription ?? ""
        if let targetDate = capsule.eventTargetDate {
            hasEventTargetDate = true
            eventTargetDate = targetDate
        }
        if let memory = capsule.memory {
            title = memory.title
            content = memory.content
            selectedMood = memory.mood
        }
    }
}

// MARK: - Summary Row

private struct SummaryRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.orange)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
            }
            Spacer()
        }
    }
}

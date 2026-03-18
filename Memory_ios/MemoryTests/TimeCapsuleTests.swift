import Testing
import Foundation
@testable import Memory

// MARK: - Time Capsule Model Tests

@Suite("Time Capsule Tests")
struct TimeCapsuleTests {
    @Test func createDateCapsule() {
        let futureDate = Date().addingTimeInterval(86400 * 30) // 30 days
        let capsule = TimeCapsule(
            unlockType: .date,
            unlockDate: futureDate
        )

        #expect(capsule.unlockType == .date)
        #expect(capsule.unlockDate == futureDate)
        #expect(capsule.isUnlocked == false)
        #expect(capsule.unlockedAt == nil)
        #expect(capsule.memory == nil)
    }

    @Test func createLocationCapsule() {
        let capsule = TimeCapsule(
            unlockType: .location,
            unlockLatitude: 35.6762,
            unlockLongitude: 139.6503,
            unlockRadius: 500,
            unlockLocationName: "Tokyo Tower"
        )

        #expect(capsule.unlockType == .location)
        #expect(capsule.unlockLatitude == 35.6762)
        #expect(capsule.unlockLongitude == 139.6503)
        #expect(capsule.unlockRadius == 500)
        #expect(capsule._plainUnlockLocationName == "Tokyo Tower")
    }

    @Test func createEventCapsule() {
        let targetDate = Date().addingTimeInterval(86400 * 365)
        let capsule = TimeCapsule(
            unlockType: .event,
            eventDescription: "Graduation Day",
            eventTargetDate: targetDate
        )

        #expect(capsule.unlockType == .event)
        #expect(capsule._plainEventDescription == "Graduation Day")
        #expect(capsule.eventTargetDate == targetDate)
    }

    @Test func unlockCapsule() {
        let capsule = TimeCapsule(unlockType: .date, unlockDate: Date())
        #expect(capsule.isUnlocked == false)

        capsule.unlock()

        #expect(capsule.isUnlocked == true)
        #expect(capsule.unlockedAt != nil)
    }

    @Test func countdownTargetForDate() {
        let futureDate = Date().addingTimeInterval(86400)
        let capsule = TimeCapsule(unlockType: .date, unlockDate: futureDate)
        #expect(capsule.countdownTarget == futureDate)
    }

    @Test func countdownTargetForLocation() {
        let capsule = TimeCapsule(unlockType: .location)
        #expect(capsule.countdownTarget == nil)
    }

    @Test func countdownTargetForEvent() {
        let targetDate = Date().addingTimeInterval(86400 * 7)
        let capsule = TimeCapsule(
            unlockType: .event,
            eventDescription: "Birthday",
            eventTargetDate: targetDate
        )
        #expect(capsule.countdownTarget == targetDate)
    }

    @Test func isReadyForPastDate() {
        let pastDate = Date().addingTimeInterval(-86400)
        let capsule = TimeCapsule(unlockType: .date, unlockDate: pastDate)
        #expect(capsule.isReady == true)
    }

    @Test func isNotReadyForFutureDate() {
        let futureDate = Date().addingTimeInterval(86400 * 30)
        let capsule = TimeCapsule(unlockType: .date, unlockDate: futureDate)
        #expect(capsule.isReady == false)
    }

    @Test func locationCapsuleNeverAutoReady() {
        let capsule = TimeCapsule(
            unlockType: .location,
            unlockLatitude: 0,
            unlockLongitude: 0
        )
        #expect(capsule.isReady == false)
    }

    @Test func eventCapsuleNeverAutoReady() {
        let capsule = TimeCapsule(
            unlockType: .event,
            eventDescription: "Something"
        )
        #expect(capsule.isReady == false)
    }

    @Test func defaultRadiusIs200() {
        let capsule = TimeCapsule(unlockType: .location)
        #expect(capsule.unlockRadius == 200)
    }

    @Test func conditionSummaryForDate() {
        let date = Date().addingTimeInterval(86400)
        let capsule = TimeCapsule(unlockType: .date, unlockDate: date)
        let summary = capsule.conditionSummary
        #expect(!summary.isEmpty)
    }

    @Test func conditionSummaryForLocation() {
        let capsule = TimeCapsule(
            unlockType: .location,
            unlockLocationName: "Eiffel Tower"
        )
        #expect(capsule.conditionSummary == "Eiffel Tower")
    }

    @Test func conditionSummaryForEvent() {
        let capsule = TimeCapsule(
            unlockType: .event,
            eventDescription: "Wedding"
        )
        #expect(capsule.conditionSummary == "Wedding")
    }
}

// MARK: - CapsuleUnlockType Tests

@Suite("CapsuleUnlockType Tests")
struct CapsuleUnlockTypeTests {
    @Test func allCasesExist() {
        #expect(CapsuleUnlockType.allCases.count == 3)
        #expect(CapsuleUnlockType.allCases.contains(.date))
        #expect(CapsuleUnlockType.allCases.contains(.location))
        #expect(CapsuleUnlockType.allCases.contains(.event))
    }

    @Test func labelsNotEmpty() {
        for type in CapsuleUnlockType.allCases {
            #expect(!type.label.isEmpty)
        }
    }

    @Test func iconsNotEmpty() {
        for type in CapsuleUnlockType.allCases {
            #expect(!type.icon.isEmpty)
        }
    }

    @Test func descriptionsNotEmpty() {
        for type in CapsuleUnlockType.allCases {
            #expect(!type.description.isEmpty)
        }
    }

    @Test func rawValueRoundtrip() {
        for type in CapsuleUnlockType.allCases {
            let raw = type.rawValue
            let decoded = CapsuleUnlockType(rawValue: raw)
            #expect(decoded == type)
        }
    }

    @Test func specificIcons() {
        #expect(CapsuleUnlockType.date.icon == "calendar.badge.clock")
        #expect(CapsuleUnlockType.location.icon == "mappin.and.ellipse")
        #expect(CapsuleUnlockType.event.icon == "sparkles")
    }
}

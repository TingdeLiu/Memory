import Testing
import Foundation
@testable import Memory

// MARK: - MBTI Assessment Tests

@Suite("MBTI Assessment Tests")
struct MBTIAssessmentTests {
    @Test func calculateTypeReturnsNilForWrongCount() {
        let result = MBTIQuestions.calculateType(answers: [true, false])
        #expect(result == nil)
    }

    @Test func calculateTypeReturnsNilForEmptyAnswers() {
        let result = MBTIQuestions.calculateType(answers: [])
        #expect(result == nil)
    }

    @Test func calculateTypeReturnsValidMBTI() {
        // 20 answers: all true (option A for each)
        let answers = Array(repeating: true, count: 20)
        let result = MBTIQuestions.calculateType(answers: answers)
        #expect(result != nil)
        #expect(result?.count == 4)
    }

    @Test func calculateTypeAllFalse() {
        // All option B selected
        let answers = Array(repeating: false, count: 20)
        let result = MBTIQuestions.calculateType(answers: answers)
        #expect(result != nil)
        #expect(result?.count == 4)
        // All B means: I, N, F, P → INFP
        #expect(result == "INFP")
    }

    @Test func calculateTypeAllTrue() {
        // All option A selected
        let answers = Array(repeating: true, count: 20)
        let result = MBTIQuestions.calculateType(answers: answers)
        #expect(result != nil)
        // All A means: E, S, T, J → ESTJ
        #expect(result == "ESTJ")
    }

    @Test func questionsHave20Items() {
        #expect(MBTIQuestions.questions.count == 20)
    }

    @Test func questionsHaveNonEmptyText() {
        for question in MBTIQuestions.questions {
            #expect(!question.text.isEmpty)
            #expect(!question.optionA.isEmpty)
            #expect(!question.optionB.isEmpty)
        }
    }

    @Test func allDimensionsCovered() {
        let dimensions = Set(MBTIQuestions.questions.map { $0.dimension })
        #expect(dimensions.contains(.EI))
        #expect(dimensions.contains(.SN))
        #expect(dimensions.contains(.TF))
        #expect(dimensions.contains(.JP))
    }

    @Test func eachDimensionHas5Questions() {
        let grouped = Dictionary(grouping: MBTIQuestions.questions, by: { $0.dimension })
        for (_, questions) in grouped {
            #expect(questions.count == 5)
        }
    }
}

// MARK: - MBTIType Tests

@Suite("MBTIType Tests")
struct MBTITypeTests {
    @Test func allTypesExist() {
        #expect(MBTIType.allCases.count == 16)
    }

    @Test func nicknamesNotEmpty() {
        for type in MBTIType.allCases {
            #expect(!type.nickname.isEmpty)
        }
    }

    @Test func descriptionsNotEmpty() {
        for type in MBTIType.allCases {
            #expect(!type.description.isEmpty)
        }
    }

    @Test func rawValueRoundtrip() {
        for type in MBTIType.allCases {
            let decoded = MBTIType(rawValue: type.rawValue)
            #expect(decoded == type)
        }
    }
}

// MARK: - Assessment Result Model Tests

@Suite("Assessment Result Tests")
struct AssessmentResultTests {
    @Test func createMBTIAssessment() {
        let result = AssessmentResult(type: .mbti)
        #expect(result.type == .mbti)
        #expect(result.isCompleted == false)
        #expect(result.resultCode == nil)
    }

    @Test func completeMBTIAssessment() {
        let result = AssessmentResult(type: .mbti)
        result.complete(resultCode: "INTJ")
        #expect(result.isCompleted == true)
        #expect(result.resultCode == "INTJ")
        #expect(result.completedAt != nil)
    }

    @Test func assessmentTypeRawValues() {
        #expect(AssessmentType.mbti.rawValue == "mbti")
        #expect(AssessmentType.bigFive.rawValue == "bigFive")
        #expect(AssessmentType.loveLanguage.rawValue == "loveLanguage")
        #expect(AssessmentType.values.rawValue == "values")
    }
}

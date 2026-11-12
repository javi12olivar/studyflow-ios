import Foundation
import SwiftUI

// MARK: - Difficulty Enum
public enum ExamDifficulty: String, CaseIterable, Codable, Identifiable, Sendable {
    case easy = "Fácil"
    case medium = "Medio"
    case hard = "Difícil"
    
    public var id: String { rawValue }
    
    public var color: Color {
        switch self {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }
}

// MARK: - Step / Topic Model
public struct ExamStep: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var isCompleted: Bool
    public var targetDate: Date?
    public var estimatedMinutes: Int
    
    public init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        targetDate: Date? = nil,
        estimatedMinutes: Int = 30
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.targetDate = targetDate
        self.estimatedMinutes = estimatedMinutes
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, isCompleted, targetDate, estimatedMinutes
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title = try container.decode(String.self, forKey: .title)
        self.isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        self.targetDate = try container.decodeIfPresent(Date.self, forKey: .targetDate)
        self.estimatedMinutes = try container.decodeIfPresent(Int.self, forKey: .estimatedMinutes) ?? 30
    }
}

// MARK: - Chapter Model
public struct ExamChapter: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var recommendedDate: Date?
    public var steps: [ExamStep]
    
    public init(
        id: UUID = UUID(),
        title: String,
        recommendedDate: Date? = nil,
        steps: [ExamStep] = []
    ) {
        self.id = id
        self.title = title
        self.recommendedDate = recommendedDate
        self.steps = steps
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, recommendedDate, steps
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title = try container.decode(String.self, forKey: .title)
        self.recommendedDate = try container.decodeIfPresent(Date.self, forKey: .recommendedDate)
        self.steps = try container.decodeIfPresent([ExamStep].self, forKey: .steps) ?? []
    }
    
    public var progress: Double {
        guard !steps.isEmpty else { return 0.0 }
        let completed = steps.filter { $0.isCompleted }.count
        return Double(completed) / Double(steps.count)
    }
}

// MARK: - Exam Study Plan Model
public struct ExamPlan: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var subject: String
    public var examDate: Date
    public var difficulty: ExamDifficulty
    public var colorTag: String?
    public var chapters: [ExamChapter]
    
    public init(
        id: UUID = UUID(),
        title: String,
        subject: String,
        examDate: Date,
        difficulty: ExamDifficulty = .medium,
        colorTag: String? = nil,
        chapters: [ExamChapter] = []
    ) {
        self.id = id
        self.title = title
        self.subject = subject
        self.examDate = examDate
        self.difficulty = difficulty
        self.colorTag = colorTag
        self.chapters = chapters
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, subject, examDate, difficulty, colorTag, chapters
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title = try container.decode(String.self, forKey: .title)
        self.subject = try container.decode(String.self, forKey: .subject)
        self.examDate = try container.decode(Date.self, forKey: .examDate)
        self.difficulty = try container.decodeIfPresent(ExamDifficulty.self, forKey: .difficulty) ?? .medium
        self.colorTag = try container.decodeIfPresent(String.self, forKey: .colorTag)
        self.chapters = try container.decodeIfPresent([ExamChapter].self, forKey: .chapters) ?? []
    }
    
    public var daysRemaining: Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfExam = calendar.startOfDay(for: examDate)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfExam)
        return max(0, components.day ?? 0)
    }
    
    public var totalProgress: Double {
        let allSteps = chapters.flatMap { $0.steps }
        guard !allSteps.isEmpty else { return 0.0 }
        let completed = allSteps.filter { $0.isCompleted }.count
        return Double(completed) / Double(allSteps.count)
    }
    
    public var completedStepsCount: Int {
        chapters.flatMap { $0.steps }.filter { $0.isCompleted }.count
    }
    
    public var totalStepsCount: Int {
        chapters.flatMap { $0.steps }.count
    }
}

// MARK: - Exam Plan Manager
@MainActor
public class ExamPlanManager: ObservableObject {
    @Published public var plans: [ExamPlan] = [] {
        didSet { savePlans() }
    }
    
    private let storageKey = "sf_exam_study_plans"
    
    public init() {
        loadPlans()
        if plans.isEmpty {
            createDemoPlans()
        }
    }
    
    private func savePlans() {
        if let encoded = try? JSONEncoder().encode(plans) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    private func loadPlans() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([ExamPlan].self, from: data) {
            self.plans = decoded
        }
    }
    
    public func addPlan(_ plan: ExamPlan) {
        plans.insert(plan, at: 0)
    }
    
    public func addPlan(title: String, subject: String, examDate: Date, difficulty: ExamDifficulty, chapterTitles: [String]) {
        var chapters: [ExamChapter] = []
        for cTitle in chapterTitles where !cTitle.trimmingCharacters(in: .whitespaces).isEmpty {
            let steps = [
                ExamStep(title: "Lectura y resumen", estimatedMinutes: 30),
                ExamStep(title: "Ejercicios prácticos", estimatedMinutes: 45),
                ExamStep(title: "Simulacro / Repaso final", estimatedMinutes: 60)
            ]
            chapters.append(ExamChapter(title: cTitle, steps: steps))
        }
        
        let newPlan = ExamPlan(
            title: title,
            subject: subject,
            examDate: examDate,
            difficulty: difficulty,
            chapters: chapters
        )
        addPlan(newPlan)
    }
    
    // Returns steps scheduled on given date across all exams
    public func stepsOn(date: Date) -> [(plan: ExamPlan, chapter: ExamChapter, step: ExamStep)] {
        let calendar = Calendar.current
        var results: [(plan: ExamPlan, chapter: ExamChapter, step: ExamStep)] = []
        
        for plan in plans {
            for chapter in plan.chapters {
                for step in chapter.steps {
                    if let sDate = step.targetDate, calendar.isDate(sDate, inSameDayAs: date) {
                        results.append((plan, chapter, step))
                    } else if step.targetDate == nil, let cDate = chapter.recommendedDate, calendar.isDate(cDate, inSameDayAs: date) {
                        results.append((plan, chapter, step))
                    }
                }
            }
        }
        return results
    }
    
    // Total study minutes scheduled on date
    public func totalMinutesOn(date: Date) -> Int {
        stepsOn(date: date).reduce(0) { $0 + $1.step.estimatedMinutes }
    }
    
    // Adds plan with Ebbinghaus Spaced Repetition distribution dates
    @discardableResult
    public func addGeneratedPlan(
        subject: String,
        title: String,
        examDate: Date,
        difficulty: ExamDifficulty,
        rawChapters: [(title: String, steps: [(title: String, minutes: Int)])],
        colorTag: String? = nil
    ) -> ExamPlan {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfExam = calendar.startOfDay(for: examDate)
        let daysUntilExam = max(1, calendar.dateComponents([.day], from: startOfToday, to: startOfExam).day ?? 7)
        
        var totalStepsCount = 0
        for rc in rawChapters {
            totalStepsCount += max(1, rc.steps.count)
        }
        totalStepsCount = max(1, totalStepsCount)
        
        var stepCounter = 0
        var builtChapters: [ExamChapter] = []
        
        for (cIdx, rChap) in rawChapters.enumerated() {
            var builtSteps: [ExamStep] = []
            let stepsToBuild = rChap.steps.isEmpty ? [("Repaso conceptual", 40)] : rChap.steps
            
            for rStep in stepsToBuild {
                stepCounter += 1
                let offset = min(daysUntilExam, max(1, Int(round(Double(stepCounter) / Double(totalStepsCount) * Double(daysUntilExam)))))
                let targetDate = calendar.date(byAdding: .day, value: offset, to: startOfToday)
                
                builtSteps.append(ExamStep(
                    title: rStep.title,
                    isCompleted: false,
                    targetDate: targetDate,
                    estimatedMinutes: rStep.minutes > 0 ? rStep.minutes : 40
                ))
            }
            
            let recOffset = min(daysUntilExam, max(1, Int(round(Double(cIdx + 1) / Double(max(1, rawChapters.count)) * Double(daysUntilExam)))))
            let recommendedDate = calendar.date(byAdding: .day, value: recOffset, to: startOfToday)
            
            builtChapters.append(ExamChapter(
                title: rChap.title,
                recommendedDate: recommendedDate,
                steps: builtSteps
            ))
        }
        
        let newPlan = ExamPlan(
            title: title,
            subject: subject,
            examDate: examDate,
            difficulty: difficulty,
            colorTag: colorTag,
            chapters: builtChapters
        )
        addPlan(newPlan)
        return newPlan
    }
    
    @discardableResult
    public func toggleStep(planID: UUID, chapterID: UUID, stepID: UUID) -> Bool? {
        guard let pIndex = plans.firstIndex(where: { $0.id == planID }) else { return nil }
        guard let cIndex = plans[pIndex].chapters.firstIndex(where: { $0.id == chapterID }) else { return nil }
        guard let sIndex = plans[pIndex].chapters[cIndex].steps.firstIndex(where: { $0.id == stepID }) else { return nil }
        
        plans[pIndex].chapters[cIndex].steps[sIndex].isCompleted.toggle()
        return plans[pIndex].chapters[cIndex].steps[sIndex].isCompleted
    }
    
    public func deletePlan(at offsets: IndexSet) {
        plans.remove(atOffsets: offsets)
    }
    
    public func deletePlan(id: UUID) {
        plans.removeAll { $0.id == id }
    }
    
    private func createDemoPlans() {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let mathDate = calendar.date(byAdding: .day, value: 5, to: startOfToday) ?? Date()
        let bioDate = calendar.date(byAdding: .day, value: 12, to: startOfToday) ?? Date()
        
        // Math Plan with realistic Spaced Repetition dates
        let mStep1 = ExamStep(title: "Operaciones con matrices", isCompleted: true, targetDate: startOfToday, estimatedMinutes: 30)
        let mStep2 = ExamStep(title: "Rango y matriz inversa", isCompleted: true, targetDate: calendar.date(byAdding: .day, value: 1, to: startOfToday), estimatedMinutes: 45)
        let mStep3 = ExamStep(title: "Regla de Cramer", isCompleted: false, targetDate: calendar.date(byAdding: .day, value: 2, to: startOfToday), estimatedMinutes: 40)
        let mChap1 = ExamChapter(title: "Fase 1: Asimilación Teórica (Spaced Repetition)", recommendedDate: calendar.date(byAdding: .day, value: 1, to: startOfToday), steps: [mStep1, mStep2, mStep3])
        
        let mStep4 = ExamStep(title: "Indeterminaciones clásicas", isCompleted: false, targetDate: calendar.date(byAdding: .day, value: 3, to: startOfToday), estimatedMinutes: 40)
        let mStep5 = ExamStep(title: "Regla de L'Hôpital", isCompleted: false, targetDate: calendar.date(byAdding: .day, value: 4, to: startOfToday), estimatedMinutes: 45)
        let mChap2 = ExamChapter(title: "Fase 2: Consolidación & Práctica Feynman", recommendedDate: calendar.date(byAdding: .day, value: 3, to: startOfToday), steps: [mStep4, mStep5])
        
        let mStep6 = ExamStep(title: "Simulacro cronometrado de examen bajo reloj", isCompleted: false, targetDate: calendar.date(byAdding: .day, value: 5, to: startOfToday), estimatedMinutes: 60)
        let mChap3 = ExamChapter(title: "Fase 3: Simulacro y Cierre", recommendedDate: mathDate, steps: [mStep6])
        
        let mathPlan = ExamPlan(
            title: "Álgebra y Cálculo Final",
            subject: "Matemáticas",
            examDate: mathDate,
            difficulty: .hard,
            colorTag: "#ef4444",
            chapters: [mChap1, mChap2, mChap3]
        )
        
        // Biology Plan
        let bStep1 = ExamStep(title: "Replicación del ADN y enzimas", isCompleted: true, targetDate: calendar.date(byAdding: .day, value: 3, to: startOfToday), estimatedMinutes: 35)
        let bStep2 = ExamStep(title: "Transcripción y código genético", isCompleted: false, targetDate: calendar.date(byAdding: .day, value: 6, to: startOfToday), estimatedMinutes: 40)
        let bChap1 = ExamChapter(title: "Fase 1: Ácidos Nucleicos y Duplicación", recommendedDate: calendar.date(byAdding: .day, value: 4, to: startOfToday), steps: [bStep1, bStep2])
        
        let bStep3 = ExamStep(title: "Mutaciones génicas y cromosómicas", isCompleted: false, targetDate: calendar.date(byAdding: .day, value: 8, to: startOfToday), estimatedMinutes: 50)
        let bChap2 = ExamChapter(title: "Fase 2: Mutaciones y Síntesis Proteica", recommendedDate: calendar.date(byAdding: .day, value: 8, to: startOfToday), steps: [bStep3])
        
        let bStep4 = ExamStep(title: "Autoevaluación de esquemas y árboles", isCompleted: false, targetDate: calendar.date(byAdding: .day, value: 11, to: startOfToday), estimatedMinutes: 45)
        let bChap3 = ExamChapter(title: "Fase 3: Repaso Final", recommendedDate: calendar.date(byAdding: .day, value: 11, to: startOfToday), steps: [bStep4])
        
        let bioPlan = ExamPlan(
            title: "Genética Molecular",
            subject: "Biología",
            examDate: bioDate,
            difficulty: .medium,
            colorTag: "#10b981",
            chapters: [bChap1, bChap2, bChap3]
        )
        
        self.plans = [mathPlan, bioPlan]
    }
}
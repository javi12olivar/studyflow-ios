import SwiftUI

public struct ExamPlannerView: View {
    @ObservedObject var planManager: ExamPlanManager
    @ObservedObject var streakManager: StreakManager
    @State private var showingNewPlanSheet = false
    @State private var showingAISheet = false
    @State private var activeQuizPlan: ExamPlan? = nil
    @State private var activeRoadmapPlan: ExamPlan? = nil
    @State private var viewMode: Int = 0 // 0: Planes, 1: Calendario General
    
    public init(planManager: ExamPlanManager, streakManager: StreakManager) {
        self.planManager = planManager
        self.streakManager = streakManager
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented View Selector
                Picker("Modo de Vista", selection: $viewMode) {
                    Text("Mis Exámenes").tag(0)
                    Text("Calendario General").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(UIColor.systemBackground))
                
                Divider()
                
                if viewMode == 1 {
                    // Unified Master Calendar View
                    ScrollView(showsIndicators: false) {
                        MasterCalendarView(planManager: planManager)
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                            .padding(.bottom, 30)
                    }
                } else {
                    // List of Exam Plans & Roadmaps
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            if planManager.plans.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "calendar.badge.plus")
                                        .font(.system(size: 64))
                                        .foregroundColor(.gray.opacity(0.5))
                                        .padding(.top, 60)
                                    Text("No tienes exámenes programados")
                                        .font(.headline)
                                    Text("Crea tu primer plan de estudio con cuenta regresiva, Spaced Repetition y simulacros.")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 32)
                                    
                                    Button(action: {
                                        HapticManager.shared.light()
                                        showingAISheet = true
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "sparkles")
                                            Text("Crear Plan con IA")
                                                .fontWeight(.bold)
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 12)
                                        .background(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
                                        .foregroundColor(.white)
                                        .cornerRadius(16)
                                    }
                                    .padding(.top, 8)
                                }
                            } else {
                                ForEach(planManager.plans) { plan in
                                    ExamPlanCard(
                                        plan: plan,
                                        planManager: planManager,
                                        streakManager: streakManager,
                                        onViewRoadmap: {
                                            activeRoadmapPlan = plan
                                        },
                                        onStartQuiz: {
                                            activeQuizPlan = plan
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("Preparación de Exámenes")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        HapticManager.shared.light()
                        showingAISheet = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                            Text("IA")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .cornerRadius(12)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        HapticManager.shared.light()
                        showingNewPlanSheet = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.orange)
                    }
                }
            }
            .sheet(isPresented: $showingNewPlanSheet) {
                NewExamPlanSheet(planManager: planManager)
            }
            .sheet(isPresented: $showingAISheet) {
                AIPlanCreationSheet(planManager: planManager)
            }
            .sheet(item: $activeRoadmapPlan) { plan in
                ExamRoadmapSheet(plan: plan, planManager: planManager, streakManager: streakManager, onLaunchQuiz: {
                    activeQuizPlan = plan
                })
            }
            .sheet(item: $activeQuizPlan) { plan in
                MockExamQuizSheet(plan: plan, streakManager: streakManager)
            }
        }
    }
}

// MARK: - Exam Plan Card Component
struct ExamPlanCard: View {
    let plan: ExamPlan
    @ObservedObject var planManager: ExamPlanManager
    @ObservedObject var streakManager: StreakManager
    var onViewRoadmap: () -> Void
    var onStartQuiz: () -> Void
    @State private var isExpanded: Bool = true
    
    private var currentPlan: ExamPlan {
        planManager.plans.first(where: { $0.id == plan.id }) ?? plan
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Row: Subject, Difficulty, Countdown
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(currentPlan.subject)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.orange)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(currentPlan.difficulty.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(currentPlan.difficulty.color.opacity(0.15))
                            .foregroundColor(currentPlan.difficulty.color)
                            .cornerRadius(8)
                    }
                    
                    Text(currentPlan.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Countdown Badge
                VStack(spacing: 2) {
                    Text("\(currentPlan.daysRemaining)")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(currentPlan.daysRemaining <= 3 ? .red : .primary)
                    Text("DÍAS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .cornerRadius(14)
            }
            
            // Progress Bar & Counts
            VStack(spacing: 6) {
                HStack {
                    Text("Progreso de temas")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(currentPlan.completedStepsCount)/\(currentPlan.totalStepsCount) completados")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(0, min(geo.size.width * CGFloat(currentPlan.totalProgress), geo.size.width)), height: 8)
                    }
                }
                .frame(height: 8)
            }
            
            // Toggle Chapters
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(isExpanded ? "Ocultar temario" : "Ver temario (\(currentPlan.chapters.count) capítulos)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }
            
            // Chapters & Checklist
            if isExpanded {
                VStack(spacing: 12) {
                    Divider()
                    ForEach(currentPlan.chapters) { chapter in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(chapter.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                            
                            ForEach(chapter.steps) { step in
                                Button(action: {
                                    HapticManager.shared.light()
                                    let willComplete = !step.isCompleted
                                    planManager.toggleStep(planID: currentPlan.id, chapterID: chapter.id, stepID: step.id)
                                    if willComplete {
                                        streakManager.addXP(15)
                                        streakManager.completeStudySession(minutes: 15)
                                    }
                                }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: step.isCompleted ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 18))
                                            .foregroundColor(step.isCompleted ? .orange : .gray)
                                        
                                        Text(step.title)
                                            .font(.system(size: 14))
                                            .strikethrough(step.isCompleted, color: .gray)
                                            .foregroundColor(step.isCompleted ? .secondary : .primary)
                                        
                                        Spacer()
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            // Action buttons footer
            HStack(spacing: 8) {
                Button(action: {
                    HapticManager.shared.medium()
                    onViewRoadmap()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "map.fill")
                        Text("Hoja de Ruta")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.12))
                    .foregroundColor(.blue)
                    .cornerRadius(12)
                }
                
                Button(action: {
                    HapticManager.shared.medium()
                    onStartQuiz()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "bolt.fill")
                        Text("Simulacro")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.purple.opacity(0.12))
                    .foregroundColor(.purple)
                    .cornerRadius(12)
                }
                
                Spacer()
                
                Button(action: {
                    HapticManager.shared.light()
                    planManager.deletePlan(id: currentPlan.id)
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(8)
                }
            }
        }
        .padding(18)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - New Exam Plan Manual Sheet
struct NewExamPlanSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var planManager: ExamPlanManager
    
    @State private var title: String = ""
    @State private var subject: String = "Matemáticas"
    @State private var examDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var difficulty: ExamDifficulty = .medium
    @State private var chaptersText: String = "Capítulo 1: Fundamentos\n- Lectura inicial\n- Resumen\nCapítulo 2: Práctica\n- Ejercicios modelo"
    
    let subjects = ["Matemáticas", "Física", "Química", "Historia", "Lengua y Literatura", "Biología", "Economía", "Inglés"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Datos del Examen")) {
                    TextField("Título del examen (ej. Parcial Álgebra)", text: $title)
                    
                    Picker("Asignatura", selection: $subject) {
                        ForEach(subjects, id: \.self) { s in
                            Text(s).tag(s)
                        }
                    }
                    
                    DatePicker("Fecha del examen", selection: $examDate, displayedComponents: .date)
                    
                    Picker("Dificultad", selection: $difficulty) {
                        ForEach(ExamDifficulty.allCases, id: \.self) { d in
                            Text(d.rawValue).tag(d)
                        }
                    }
                }
                
                Section(header: Text("Capítulos y Pasos de Estudio"), footer: Text("Escribe capítulos y pasos. Usa guiones (-) para indicar cada paso dentro de un capítulo.")) {
                    TextEditor(text: $chaptersText)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("Nuevo Examen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Guardar") {
                        savePlan()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private func savePlan() {
        let lines = chaptersText.components(separatedBy: .newlines)
        var chapters: [ExamChapter] = []
        var currentChapTitle: String? = nil
        var currentSteps: [ExamStep] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            
            if trimmed.starts(with: "-") {
                let stepTitle = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                currentSteps.append(ExamStep(title: stepTitle, isCompleted: false))
            } else {
                if let title = currentChapTitle {
                    chapters.append(ExamChapter(title: title, steps: currentSteps.isEmpty ? [ExamStep(title: "Repaso general", isCompleted: false)] : currentSteps))
                    currentSteps = []
                }
                currentChapTitle = trimmed
            }
        }
        
        if let title = currentChapTitle {
            chapters.append(ExamChapter(title: title, steps: currentSteps.isEmpty ? [ExamStep(title: "Repaso general", isCompleted: false)] : currentSteps))
        }
        
        if chapters.isEmpty {
            chapters = [
                ExamChapter(title: "Bloque Principal", steps: [
                    ExamStep(title: "Estudio de temario", isCompleted: false),
                    ExamStep(title: "Resolución de problemas", isCompleted: false)
                ])
            ]
        }
        
        let newPlan = ExamPlan(
            title: title.trimmingCharacters(in: .whitespaces),
            subject: subject,
            examDate: examDate,
            difficulty: difficulty,
            chapters: chapters
        )
        
        planManager.addPlan(newPlan)
        HapticManager.shared.success()
        dismiss()
    }
}
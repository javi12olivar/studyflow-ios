import SwiftUI

// MARK: - Detailed Exam Roadmap Sheet
public struct ExamRoadmapSheet: View {
    @Environment(\.dismiss) private var dismiss
    let plan: ExamPlan
    @ObservedObject var planManager: ExamPlanManager
    @ObservedObject var streakManager: StreakManager
    var onLaunchQuiz: () -> Void
    
    public init(plan: ExamPlan, planManager: ExamPlanManager, streakManager: StreakManager, onLaunchQuiz: @escaping () -> Void) {
        self.plan = plan
        self.planManager = planManager
        self.streakManager = streakManager
        self.onLaunchQuiz = onLaunchQuiz
    }
    
    // Live reactive plan synchronized with ExamPlanManager mutations
    private var currentPlan: ExamPlan {
        planManager.plans.first(where: { $0.id == plan.id }) ?? plan
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(currentPlan.subject)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.orange)
                            
                            Spacer()
                            
                            Text(currentPlan.difficulty.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(currentPlan.difficulty.color.opacity(0.15))
                                .foregroundColor(currentPlan.difficulty.color)
                                .cornerRadius(8)
                        }
                        
                        Text(currentPlan.title)
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundColor(.primary)
                        
                        // Countdown & Progress
                        HStack(spacing: 16) {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                Text("\(currentPlan.daysRemaining) días restantes")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(currentPlan.daysRemaining <= 3 ? .red : .primary)
                            }
                            
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.green)
                                Text("\(currentPlan.completedStepsCount)/\(currentPlan.totalStepsCount) completados (\(Int(currentPlan.totalProgress * 100))%)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Progress Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.gray.opacity(0.15))
                                    .frame(height: 8)
                                
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: max(0, min(geo.size.width * CGFloat(currentPlan.totalProgress), geo.size.width)), height: 8)
                            }
                        }
                        .frame(height: 8)
                        .padding(.top, 4)
                    }
                    .padding(18)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(18)
                    
                    // Roadmap Methodology Callout
                    HStack(spacing: 12) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 22))
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Curva del Olvido de Ebbinghaus")
                                .font(.system(size: 14, weight: .bold))
                            Text("Cada fase está calculada para reactivar la memoria a largo plazo en intervalos estratégicos.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(14)
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(14)
                    
                    // Phases and Chapters
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Cronograma de Hitos y Fases")
                            .font(.system(size: 17, weight: .bold))
                        
                        ForEach(Array(currentPlan.chapters.enumerated()), id: \.element.id) { index, chapter in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
                                            .frame(width: 26, height: 26)
                                        Text("\(index + 1)")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    
                                    Text(chapter.title)
                                        .font(.system(size: 15, weight: .bold))
                                    
                                    Spacer()
                                    
                                    let comp = chapter.steps.filter { $0.isCompleted }.count
                                    Text("\(comp)/\(chapter.steps.count)")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                                
                                VStack(spacing: 8) {
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
                                            HStack(spacing: 12) {
                                                Image(systemName: step.isCompleted ? "checkmark.circle.fill" : "circle")
                                                    .font(.system(size: 20))
                                                    .foregroundColor(step.isCompleted ? .orange : .gray.opacity(0.5))
                                                
                                                Text(step.title)
                                                    .font(.system(size: 14))
                                                    .strikethrough(step.isCompleted, color: .gray)
                                                    .foregroundColor(step.isCompleted ? .secondary : .primary)
                                                    .multilineTextAlignment(.leading)
                                                
                                                Spacer()
                                            }
                                            .padding(12)
                                            .background(Color(UIColor.secondarySystemGroupedBackground))
                                            .cornerRadius(12)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Quiz Launcher Button
                    Button(action: {
                        dismiss()
                        onLaunchQuiz()
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 16, weight: .bold))
                            Text("Realizar Simulacro Tipo Test con IA")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    }
                    .padding(.top, 10)
                }
                .padding(20)
            }
            .navigationTitle("Hoja de Ruta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }
}

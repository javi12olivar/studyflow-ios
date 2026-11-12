import SwiftUI

public struct MockExamQuizSheet: View {
    let plan: ExamPlan
    @ObservedObject var streakManager: StreakManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var questions: [QuizQuestion] = []
    @State private var currentIndex: Int = 0
    @State private var selectedOption: Int? = nil
    @State private var score: Int = 0
    @State private var isLoading: Bool = true
    @State private var isFinished: Bool = false
    
    public init(plan: ExamPlan, streakManager: StreakManager) {
        self.plan = plan
        self.streakManager = streakManager
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.3)
                        Text("Generando simulacro pedagógico...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                } else if isFinished {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "star.fill")
                            .font(.system(size: 72))
                        
                        Text("¡Simulacro Completado!")
                            .font(.system(size: 24, weight: .heavy))
                        
                        Text("Has acertado \(score) de \(questions.count) preguntas")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 8) {
                            Text("+50 XP Ganados")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.green)
                            Text("Racha de estudio marcada para hoy")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.orange)
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 24)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(16)
                        
                        Spacer()
                        
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Volver a Estudiar")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
                                .cornerRadius(16)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                    }
                } else if !questions.isEmpty {
                    let q = questions[min(currentIndex, questions.count - 1)]
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // Header progress
                        HStack {
                            Text("Pregunta \(currentIndex + 1) de \(questions.count)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.orange)
                            Spacer()
                            Text("\(plan.subject)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 12)
                        
                        Text(q.question)
                            .font(.system(size: 18, weight: .bold))
                            .lineSpacing(4)
                            .foregroundColor(.primary)
                            .padding(.vertical, 6)
                        
                        // Options
                        VStack(spacing: 10) {
                            let letters = ["A", "B", "C", "D", "E", "F"]
                            ForEach(0..<q.options.count, id: \.self) { idx in
                                OptionButton(
                                    letter: idx < letters.count ? letters[idx] : "\(idx + 1)",
                                    text: q.options[idx],
                                    isSelected: selectedOption == idx,
                                    isCorrect: idx == q.correctIndex,
                                    hasAnswered: selectedOption != nil
                                ) {
                                    handleAnswer(idx, correct: idx == q.correctIndex)
                                }
                            }
                        }
                        
                        // Explanation
                        if let selected = selectedOption {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: selected == q.correctIndex ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(selected == q.correctIndex ? .green : .red)
                                    Text(selected == q.correctIndex ? "¡Correcto!" : "Respuesta incorrecta")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(selected == q.correctIndex ? .green : .red)
                                }
                                Text(q.explanation)
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                    .lineSpacing(2)
                            }
                            .padding(14)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(14)
                            .transition(.opacity)
                        }
                        
                        Spacer()
                        
                        if selectedOption != nil {
                            Button(action: nextQuestion) {
                                Text(currentIndex + 1 < questions.count ? "Siguiente Pregunta →" : "Ver Resultados ")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange)
                                    .cornerRadius(16)
                            }
                            .padding(.bottom, 20)
                        }
                    }
                    .padding(.horizontal, 20)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 44))
                            .foregroundColor(.orange)
                        Text("No se pudo cargar el simulacro")
                            .font(.headline)
                        Button("Reintentar") {
                            loadQuiz()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                }
            }
            .navigationTitle("Simulacro con IA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .onAppear(perform: loadQuiz)
        }
    }
    
    private func loadQuiz() {
        isLoading = true
        Task {
            let loaded = await GeminiService.shared.generateMockQuiz(for: plan)
            await MainActor.run {
                self.questions = loaded
                self.isLoading = false
            }
        }
    }
    
    private func handleAnswer(_ index: Int, correct: Bool) {
        guard selectedOption == nil else { return }
        selectedOption = index
        if correct {
            score += 1
            HapticManager.shared.success()
            SoundEffectManager.shared.playFlame()
        } else {
            HapticManager.shared.heavy()
            SoundEffectManager.shared.playCrack1()
        }
    }
    
    private func nextQuestion() {
        if currentIndex + 1 < questions.count {
            selectedOption = nil
            currentIndex += 1
        } else {
            isFinished = true
            streakManager.completeStudySession(minutes: 15)
            SoundEffectManager.shared.playCelebration()
            HapticManager.shared.success()
        }
    }
}

// MARK: - Option Button
struct OptionButton: View {
    let letter: String
    let text: String
    let isSelected: Bool
    let isCorrect: Bool
    let hasAnswered: Bool
    let action: () -> Void
    
    var backgroundColor: Color {
        guard hasAnswered else { return Color(UIColor.secondarySystemGroupedBackground) }
        if isCorrect { return Color.green.opacity(0.18) }
        if isSelected && !isCorrect { return Color.red.opacity(0.18) }
        return Color(UIColor.secondarySystemGroupedBackground)
    }
    
    var borderColor: Color {
        guard hasAnswered else { return Color.clear }
        if isCorrect { return Color.green }
        if isSelected && !isCorrect { return Color.red }
        return Color.clear
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(letter)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.orange.opacity(0.8)))
                
                Text(text)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            .padding(14)
            .background(backgroundColor)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(borderColor, lineWidth: 1.5)
            )
        }
        .disabled(hasAnswered)
    }
}
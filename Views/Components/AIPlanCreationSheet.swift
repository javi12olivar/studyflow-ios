import SwiftUI

@MainActor
public struct AIPlanCreationSheet: View {
    @ObservedObject var planManager: ExamPlanManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var subject: String = ""
    @State private var title: String = ""
    @State private var examDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var difficulty: ExamDifficulty = .medium
    @State private var notes: String = ""
    @State private var isGenerating: Bool = false
    @State private var showingApiSettings: Bool = false
    
    public init(planManager: ExamPlanManager) {
        self.planManager = planManager
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Información del Examen")) {
                    TextField("Asignatura (ej. Historia, Matemáticas)", text: $subject)
                    TextField("Título o Bloque (ej. EvAU Bloque 3)", text: $title)
                    DatePicker("Fecha del Examen", selection: $examDate, displayedComponents: [.date])
                    Picker("Dificultad", selection: $difficulty) {
                        ForEach(ExamDifficulty.allCases) { diff in
                            Text(diff.rawValue).tag(diff)
                        }
                    }
                }
                
                Section(header: Text("Temario o Apuntes a Desglosar (Opcional)")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 120)
                }
                
                Section {
                    Button(action: generatePlan) {
                        HStack {
                            Spacer()
                            if isGenerating {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Gemini Flash Planificando...")
                                    .fontWeight(.bold)
                            } else {
                                Image(systemName: "sparkles")
                                Text("Generar Plan con Spaced Repetition")
                                    .fontWeight(.bold)
                            }
                            Spacer()
                        }
                    }
                    .foregroundColor(.white)
                    .listRowBackground(Color.orange)
                    .disabled(subject.trimmingCharacters(in: .whitespaces).isEmpty || isGenerating)
                }
                
                if GeminiService.shared.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section {
                        Button(action: { showingApiSettings = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "key.fill")
                                    .foregroundColor(.orange)
                                Text("Configurar API Key de Gemini")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    } footer: {
                        Text("Introduce tu clave gratuita de Google Gemini para habilitar el desglose inteligente.")
                    }
                }
            }
            .navigationTitle("Crear Plan con IA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .sheet(isPresented: $showingApiSettings) {
                ApiConfigurationSheet()
            }
        }
    }
    
    private func generatePlan() {
        isGenerating = true
        HapticManager.shared.light()
        
        Task {
            let finalSubject = subject.isEmpty ? "Estudio General" : subject
            let finalTitle = title.isEmpty ? "Examen de \(finalSubject)" : title
            
            let plan = await GeminiService.shared.generateStudyPlan(
                subject: finalSubject,
                title: finalTitle,
                examDate: examDate,
                difficulty: difficulty,
                notes: notes
            )
            
            await MainActor.run {
                planManager.addPlan(plan)
                isGenerating = false
                HapticManager.shared.success()
                SoundEffectManager.shared.playCelebration()
                dismiss()
            }
        }
    }
}
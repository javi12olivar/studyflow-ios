import SwiftUI
import UIKit

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
    @State private var generationTask: Task<Void, Never>? = nil
    
    // Vision OCR Scanner
    @State private var isExtractingVision: Bool = false
    @State private var showingScanPicker: Bool = false
    @State private var scanPickerSource: UIImagePickerController.SourceType = .camera
    @State private var visionTask: Task<Void, Never>? = nil
    
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
                
                Section(header: Text("Temario o Apuntes a Desglosar")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 110)
                    
                    if isExtractingVision {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Gemini 3.1 Flash-Lite extrayendo temario y fórmulas...")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.orange)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            scanPickerSource = .camera
                            showingScanPicker = true
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "camera.fill")
                                Text("Foto de Apuntes")
                            }
                            .font(.system(size: 13, weight: .semibold))
                        }
                        .buttonStyle(.borderless)
                        
                        Spacer()
                        
                        Button(action: {
                            scanPickerSource = .photoLibrary
                            showingScanPicker = true
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "photo.on.rectangle")
                                Text("Galería")
                            }
                            .font(.system(size: 13, weight: .semibold))
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 2)
                }
                
                Section {
                    Button(action: generatePlan) {
                        HStack {
                            Spacer()
                            if isGenerating {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text(GroqService.shared.apiKey.count > 5 ? "Groq 120B Planificando..." : "IA Planificando día a día...")
                                    .fontWeight(.bold)
                            } else {
                                Image(systemName: "sparkles")
                                Text("Generar Plan Diario con IA")
                                    .fontWeight(.bold)
                            }
                            Spacer()
                        }
                    }
                    .foregroundColor(.white)
                    .listRowBackground(Color.orange)
                    .disabled(subject.trimmingCharacters(in: .whitespaces).isEmpty || isGenerating)
                }
                
                if GroqService.shared.apiKey.count <= 5 && GeminiService.shared.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section {
                        Button(action: { showingApiSettings = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "key.fill")
                                    .foregroundColor(.orange)
                                Text("Configurar API Keys (Groq / Gemini)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    } footer: {
                        Text("Introduce tu API Key de Groq o Gemini para crear desgloses de temario automáticos día por día.")
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Crear Plan con IA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        generationTask?.cancel()
                        visionTask?.cancel()
                        dismiss()
                    }
                }
            }
            .onDisappear {
                generationTask?.cancel()
                visionTask?.cancel()
            }
            .sheet(isPresented: $showingApiSettings) {
                ApiConfigurationSheet()
            }
            .sheet(isPresented: $showingScanPicker) {
                ImagePickerView(sourceType: scanPickerSource) { pickedImg in
                    processScannedImage(pickedImg)
                }
            }
        }
    }
    
    private func processScannedImage(_ img: UIImage) {
        isExtractingVision = true
        HapticManager.shared.light()
        
        visionTask?.cancel()
        visionTask = Task { @MainActor in
            defer { isExtractingVision = false }
            guard let data = img.jpegData(compressionQuality: 0.8) else { return }
            
            if let extracted = await GeminiService.shared.extractContentFromImage(imageData: data) {
                guard !Task.isCancelled else { return }
                if notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    notes = extracted
                } else {
                    notes += "\n\n" + extracted
                }
                HapticManager.shared.success()
            }
        }
    }
    
    private func generatePlan() {
        isGenerating = true
        HapticManager.shared.light()
        
        generationTask?.cancel()
        generationTask = Task { @MainActor in
            let finalSubject = subject.isEmpty ? "Estudio General" : subject
            let finalTitle = title.isEmpty ? "Examen de \(finalSubject)" : title
            
            let plan = await GeminiService.shared.generateStudyPlan(
                subject: finalSubject,
                title: finalTitle,
                examDate: examDate,
                difficulty: difficulty,
                notes: notes
            )
            
            guard !Task.isCancelled else { return }
            
            planManager.addPlan(plan)
            isGenerating = false
            HapticManager.shared.success()
            SoundEffectManager.shared.playCelebration()
            dismiss()
        }
    }
}
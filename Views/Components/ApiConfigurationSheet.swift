import SwiftUI

// MARK: - API Configuration Sheet
@MainActor
public struct ApiConfigurationSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var geminiKey: String = ""
    @State private var groqKey: String = ""
    @State private var mistralKey: String = ""
    
    @State private var showGeminiKey: Bool = false
    @State private var showGroqKey: Bool = false
    @State private var showMistralKey: Bool = false
    
    @State private var savedSuccess: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "shield.lefthalf.filled")
                                .foregroundColor(.green)
                            Text("Almacenamiento Seguro")
                                .font(.system(size: 14, weight: .bold))
                        }
                        Text("Tus claves de API se guardan cifradas en el **Keychain** de tu iPhone. Jamás se envían a servidores de terceros ni salen de tu dispositivo.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                // GROQ (Prioritario para chat ultra-rápido)
                Section(header: Label("Groq Cloud (Llama 3.3 70B)", systemImage: "bolt.fill")) {
                    HStack {
                        if showGroqKey {
                            TextField("gsk_...", text: $groqKey)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .font(.system(size: 14, design: .monospaced))
                        } else {
                            SecureField("gsk_...", text: $groqKey)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .font(.system(size: 14, design: .monospaced))
                        }
                        
                        Button(action: {
                            showGroqKey.toggle()
                            HapticManager.shared.light()
                        }) {
                            Image(systemName: showGroqKey ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("Estado:")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        if groqKey.trimmingCharacters(in: .whitespacesAndNewlines).count > 5 {
                            Label("Configurada", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.green)
                        } else {
                            Text("Sin configurar")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                } footer: {
                    Text("Recomendada para el tutor Aethelgard: respuestas instantáneas a más de 300 tokens/s con Llama 3.3 70B Versatile.")
                }
                
                // GOOGLE GEMINI (Prioritario para planificación de exámenes)
                Section(header: Label("Google Gemini (Flash 1.5)", systemImage: "sparkles")) {
                    HStack {
                        if showGeminiKey {
                            TextField("AIzaSy...", text: $geminiKey)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .font(.system(size: 14, design: .monospaced))
                        } else {
                            SecureField("AIzaSy...", text: $geminiKey)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .font(.system(size: 14, design: .monospaced))
                        }
                        
                        Button(action: {
                            showGeminiKey.toggle()
                            HapticManager.shared.light()
                        }) {
                            Image(systemName: showGeminiKey ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("Estado:")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        if geminiKey.trimmingCharacters(in: .whitespacesAndNewlines).count > 10 {
                            Label("Configurada", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.green)
                        } else {
                            Text("Sin configurar")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                } footer: {
                    Text("Utilizada para estructurar temarios de examen complejos con curva del olvido y fechas en tu Calendario Maestro.")
                }
                
                // MISTRAL AI
                Section(header: Label("Mistral AI", systemImage: "waveform")) {
                    HStack {
                        if showMistralKey {
                            TextField("Clave de API Mistral...", text: $mistralKey)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .font(.system(size: 14, design: .monospaced))
                        } else {
                            SecureField("Clave de API Mistral...", text: $mistralKey)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .font(.system(size: 14, design: .monospaced))
                        }
                        
                        Button(action: {
                            showMistralKey.toggle()
                            HapticManager.shared.light()
                        }) {
                            Image(systemName: showMistralKey ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("Estado:")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        if mistralKey.trimmingCharacters(in: .whitespacesAndNewlines).count > 5 {
                            Label("Configurada", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.green)
                        } else {
                            Text("Sin configurar")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // BOTÓN GUARDAR
                Section {
                    Button(action: saveKeys) {
                        HStack {
                            Spacer()
                            if savedSuccess {
                                Image(systemName: "checkmark")
                                    .fontWeight(.bold)
                                Text("¡Claves Guardadas en Keychain!")
                                    .fontWeight(.bold)
                            } else {
                                Image(systemName: "lock.shield.fill")
                                Text("Guardar Configuración")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .foregroundColor(.white)
                    .listRowBackground(savedSuccess ? Color.green : Color.orange)
                }
            }
            .navigationTitle("Configuración de IA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Listo") {
                        saveKeys()
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.orange)
                }
            }
            .onAppear {
                loadKeys()
            }
        }
    }
    
    private func loadKeys() {
        self.groqKey = GroqService.shared.apiKey
        self.geminiKey = GeminiService.shared.apiKey
        self.mistralKey = MistralService.shared.apiKey
    }
    
    private func saveKeys() {
        HapticManager.shared.success()
        GroqService.shared.saveApiKey(groqKey)
        GeminiService.shared.apiKey = geminiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        MistralService.shared.saveApiKey(mistralKey)
        
        withAnimation {
            savedSuccess = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation {
                savedSuccess = false
            }
        }
    }
}

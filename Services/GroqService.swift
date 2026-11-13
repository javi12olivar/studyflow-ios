import Foundation
import Security
import OSLog

// MARK: - Groq Cloud Service (120B Parameters — OpenAI/GPT-OSS 120B & DeepSeek R1)
@MainActor
public final class GroqService: ObservableObject {
    public static let shared = GroqService()
    private static let logger = Logger(subsystem: "com.studyflow.app", category: "GroqService")
    private let keychainKey = "sf_groq_api_key"
    
    @Published public var apiKey: String = ""
    public let model: String = "openai/gpt-oss-120b"
    public let fallbackModel: String = "openai/gpt-oss-120b"
    
    private init() {
        if let saved = UserDefaults.standard.string(forKey: keychainKey), !saved.isEmpty {
            self.apiKey = saved
        } else if let data = KeychainHelper.load(key: keychainKey),
                  let saved = String(data: data, encoding: .utf8), !saved.isEmpty {
            self.apiKey = saved
        }
    }
    
    public func saveApiKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        self.apiKey = trimmed
        UserDefaults.standard.set(trimmed, forKey: keychainKey)
        UserDefaults.standard.synchronize()
        if let data = trimmed.data(using: .utf8) {
            _ = KeychainHelper.save(key: keychainKey, data: data)
        }
    }
    
    // MARK: - Chat with Groq
    public func chat(message: String, context: String) async -> String? {
        guard apiKey.count > 5 else { return nil }
        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else { return nil }
        
        let systemPrompt = """
        Eres "Aethelgard Study AI", el tutor pedagógico inteligente y socrático integrado en StudyFlow.
        Estás impulsado por el modelo insignia OpenAI/GPT-OSS de 120 Billones de parámetros en Groq Cloud.
        
        PERFIL PEDAGÓGICO:
        1. Rigor intelectual y empatía: Eres el mejor profesor particular del mundo. No das respuestas genéricas, condescendientes ni vacías.
        2. Pensamiento estructurado: Utilizas principios de la curva del olvido de Ebbinghaus (Spaced Repetition) y la Técnica Feynman.
        3. Si el estudiante te consulta sobre un tema complejo, explícalo con una analogía didáctica brillante y pasos claros.
        4. Si el estudiante tiene dudas sobre exámenes, analiza su calendario y sugiere qué estudiar hoy en sus bloques Pomodoro.
        5. CONCISIÓN Y FORMATO MÓVIL (CRÍTICO): La app se ejecuta en un móvil iPhone con pantalla reducida. Escribe SIEMPRE respuestas directas, concisas y al grano. Si una duda puede responderse en 2 o 3 frases claras o con una lista con viñetas muy breve, hazlo así. No uses párrafos largos, ni rellenos vacíos, ni introducciones ceremoniosas; no ocupes pantalla innecesariamente.

        CAPACIDAD DE CONFIGURAR EXÁMENES Y CREAR PLANES EN EL CALENDARIO (PLANIFICACIÓN DÍA A DÍA):
        - Si el usuario te pide crear un plan de estudio, programar o añadir un examen en su calendario (por ejemplo: "tengo examen de...", "crea un plan para...", "añade el examen de..."):
          1. Analiza cuántos días faltan para la fecha del examen.
          2. Organiza el temario OBLIGATORIAMENTE DÍA POR DÍA previo al examen. Si faltan N días (ej. 5 días), crea N capítulos titulados estrictamente: "Día 1: [Temas o contenido de hoy]", "Día 2: [Temas o contenido]", ..., hasta "Día N: Simulacro final y repaso relámpago".
          3. En cada día, desglosa 2 a 3 pasos concretos y accionables con los subtemas, conceptos o ejercicios que debe completar ese día específico.
          4. AL FINAL de tu respuesta, INCLUYE OBLIGATORIAMENTE un bloque de acción JSON con este formato exacto:
        ```json:action
        {
          "action": "create_exam_plan",
          "subject": "Nombre de la Asignatura",
          "title": "Título descriptivo del examen",
          "examDate": "YYYY-MM-DD",
          "difficulty": "easy" | "medium" | "hard",
          "chapters": [
            {
              "title": "Día 1: Asimilación y Conceptos Clave de [Temario]",
              "steps": [
                { "title": "Lectura y subrayado de [Tema 1]", "estimatedMinutes": 35 },
                { "title": "Esquema conceptual y fórmulas", "estimatedMinutes": 25 }
              ]
            },
            {
              "title": "Día 2: Práctica y Ejercicios Tipo de [Temario]",
              "steps": [
                { "title": "Resolución de problemas guiados", "estimatedMinutes": 45 },
                { "title": "Identificación de errores típicos", "estimatedMinutes": 20 }
              ]
            },
            {
              "title": "Día 3: Simulacro y Cierre Cronometrado",
              "steps": [
                { "title": "Simulacro completo bajo reloj", "estimatedMinutes": 60 },
                { "title": "Repaso relámpago con Repetición Espaciada", "estimatedMinutes": 15 }
              ]
            }
          ]
        }
        ```
        StudyFlow detectará este bloque automáticamente, programará los días en el Calendario y creará la Hoja de Ruta interactiva día por día.
        
        CONTEXTO REAL DEL ESTUDIANTE:
        \(context)
        """
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": message]
            ],
            "temperature": 0.35,
            "max_tokens": 1500
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    return content.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } else {
                Self.logger.warning("Groq primary model returned non-200. Retrying with fallback model.")
                var fallbackBody = requestBody
                fallbackBody["model"] = fallbackModel
                request.httpBody = try JSONSerialization.data(withJSONObject: fallbackBody)
                let (fallbackData, fallbackRes) = try await URLSession.shared.data(for: request)
                if let http2 = fallbackRes as? HTTPURLResponse, http2.statusCode == 200,
                   let json = try JSONSerialization.jsonObject(with: fallbackData) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    return content.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        } catch {
            Self.logger.error("Groq API request failed: \(error.localizedDescription)")
        }
        return nil
    }
}
import Foundation
import Security
import OSLog

// MARK: - Native Secure Keychain Helper
public enum KeychainHelper {
    private static let serviceName = "com.studyflow.gemini"
    
    public static func save(key: String, data: Data) -> Bool {
        let searchQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let updateStatus = SecItemUpdate(searchQuery as CFDictionary, attributesToUpdate as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        
        if updateStatus == errSecItemNotFound {
            var insertQuery = searchQuery
            insertQuery[kSecValueData as String] = data
            insertQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            return SecItemAdd(insertQuery as CFDictionary, nil) == errSecSuccess
        }
        return false
    }
    
    public static func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        if status == errSecSuccess {
            return dataTypeRef as? Data
        }
        return nil
    }
    
    public static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Quiz Question Model for iOS
public struct QuizQuestion: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public let question: String
    public let options: [String]
    public let correctIndex: Int
    public let explanation: String
    
    enum CodingKeys: String, CodingKey {
        case question, options, correctIndex, explanation
    }
}

// MARK: - Gemini API DTO Models
private struct GeminiInlineData: Codable {
    let mimeType: String
    let data: String
}

private struct GeminiContentPart: Codable {
    let text: String?
    let inlineData: GeminiInlineData?
    
    init(text: String) {
        self.text = text
        self.inlineData = nil
    }
    
    init(mimeType: String, base64Data: String) {
        self.text = nil
        self.inlineData = GeminiInlineData(mimeType: mimeType, data: base64Data)
    }
}

private struct GeminiContent: Codable {
    let parts: [GeminiContentPart]
}

private struct GeminiGenerationConfig: Codable {
    let responseMimeType: String?
    
    enum CodingKeys: String, CodingKey {
        case responseMimeType = "response_mime_type"
    }
}

private struct GeminiRequest: Codable {
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig?
}

private struct GeminiResponse: Codable {
    struct Candidate: Codable {
        struct Content: Codable {
            struct Part: Codable {
                let text: String?
            }
            let parts: [Part]?
        }
        let content: Content?
    }
    let candidates: [Candidate]?
}

// MARK: - Gemini Service
@MainActor
public final class GeminiService: ObservableObject {
    public static let shared = GeminiService()
    
    private static let logger = Logger(subsystem: "com.studyflow.app", category: "GeminiService")
    private let keyStorageAccount = "sf_gemini_api_key"
    
    @Published public var apiKey: String = "" {
        didSet {
            persistApiKey(apiKey)
        }
    }
    
    private init() {
        self.apiKey = loadApiKey()
    }
    
    private func loadApiKey() -> String {
        if let saved = UserDefaults.standard.string(forKey: keyStorageAccount), !saved.isEmpty {
            return saved
        }
        if let data = KeychainHelper.load(key: keyStorageAccount),
           let key = String(data: data, encoding: .utf8), !key.isEmpty {
            return key
        }
        return ""
    }
    
    private func persistApiKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: keyStorageAccount)
        UserDefaults.standard.synchronize()
        if key.isEmpty {
            KeychainHelper.delete(key: keyStorageAccount)
        } else if let data = key.data(using: .utf8) {
            _ = KeychainHelper.save(key: keyStorageAccount, data: data)
        }
    }
    
    // MARK: - Multimodal Vision OCR (Gemini 3.1 Flash-Lite)
    public func extractContentFromImage(imageData: Data, mimeType: String = "image/jpeg") async -> String? {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count > 5 else {
            Self.logger.warning("Gemini API Key missing for vision OCR")
            return nil
        }
        
        let prompt = """
        Transcribe minuciosamente todo el texto, conceptos y fórmulas matemáticas de esta imagen en LaTeX estructurado ($...$ o $$...$$).
        Si contiene temario, esquemas o ejercicios, estructura los apartados claramente con títulos y viñetas para que otro modelo de IA pedagógico pueda planificarlo o resolverlo paso a paso.
        """
        
        let base64 = imageData.base64EncodedString()
        let payload = GeminiRequest(
            contents: [
                GeminiContent(parts: [
                    GeminiContentPart(text: prompt),
                    GeminiContentPart(mimeType: mimeType, base64Data: base64)
                ])
            ],
            generationConfig: nil
        )
        
        let modelsToTry = [
            "gemini-3.1-flash-lite",
            "gemini-3.8-flash",
            "gemini-3.7-flash",
            "gemini-flash-latest",
            "gemini-2.5-flash"
        ]
        
        for model in modelsToTry {
            guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent") else {
                continue
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
            
            do {
                request.httpBody = try JSONEncoder().encode(payload)
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                    let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
                    if let text = decoded.candidates?.first?.content?.parts?.first?.text,
                       !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Self.logger.info("Vision OCR succeeded with model \(model)")
                        return text.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            } catch {
                Self.logger.warning("Vision OCR failed with \(model): \(error.localizedDescription)")
            }
        }
        
        return nil
    }
    
    // MARK: - Generate Exam Plan
    public func generateStudyPlan(
        subject: String,
        title: String,
        examDate: Date,
        difficulty: ExamDifficulty,
        notes: String
    ) async -> ExamPlan {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        let dateStr = dateFormatter.string(from: examDate)
        
        // 1. Try Groq Cloud 120B first if configured
        if GroqService.shared.apiKey.count > 5 {
            let groqMsg = """
            Genera un plan de estudio estructurado día a día para el siguiente examen:
            - Asignatura: "\(subject)"
            - Título: "\(title)"
            - Fecha del Examen: "\(dateStr)"
            - Dificultad: "\(difficulty.rawValue)"
            - Notas/Temario: "\(notes)"
            
            OBLIGATORIO: Organiza los capítulos día a día ("Día 1: ...", "Día 2: ...") con 2 a 3 pasos por día.
            Incluye al final el bloque ```json:action con "action": "create_exam_plan" y la lista de chapters.
            """
            if let resp = await GroqService.shared.chat(message: groqMsg, context: "") {
                let pattern = #"(?s)```(?:json:action|json)?\s*(\{.*?"action"\s*:\s*"create_exam_plan".*?\})\s*```"#
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    let ns = resp as NSString
                    let matches = regex.matches(in: resp, options: [], range: NSRange(location: 0, length: ns.length))
                    if let match = matches.first, match.numberOfRanges > 1 {
                        let jsonStr = ns.substring(with: match.range(at: 1))
                        if let data = jsonStr.data(using: .utf8),
                           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let rawChapters = dict["chapters"] as? [[String: Any]] {
                            let calendar = Calendar.current
                            let startOfToday = calendar.startOfDay(for: Date())
                            var chapters: [ExamChapter] = []
                            for (cIdx, chapDict) in rawChapters.enumerated() {
                                let cTitle = chapDict["title"] as? String ?? "Día \(cIdx + 1): Preparación"
                                var steps: [ExamStep] = []
                                if let rawSteps = chapDict["steps"] as? [[String: Any]] {
                                    for st in rawSteps {
                                        let sTitle = st["title"] as? String ?? "Sesión de estudio"
                                        let mins = st["estimatedMinutes"] as? Int ?? 30
                                        steps.append(ExamStep(title: sTitle, estimatedMinutes: mins))
                                    }
                                }
                                if steps.isEmpty {
                                    steps = [ExamStep(title: "Repaso conceptual"), ExamStep(title: "Ejercicios prácticos")]
                                }
                                let rDate = calendar.date(byAdding: .day, value: cIdx, to: startOfToday)
                                chapters.append(ExamChapter(title: cTitle, recommendedDate: rDate, steps: steps))
                            }
                            return ExamPlan(title: title, subject: subject, examDate: examDate, difficulty: difficulty, chapters: chapters)
                        }
                    }
                }
            }
        }
        
        // 2. Try Gemini Flash-Lite if key available
        if key.count > 10 {
            let prompt = """
            Eres Aethelgard Study AI, tutor pedagógico inteligente en StudyFlow.
            Genera una planificación de estudio organizada DÍA A DÍA con Spaced Repetition para el siguiente examen:
            - Asignatura: "\(subject)"
            - Título: "\(title)"
            - Fecha del Examen: "\(dateStr)"
            - Dificultad: "\(difficulty.rawValue)"
            - Notas/Temario: "\(notes)"

            ORGANIZACIÓN DÍA A DÍA:
            Organiza el plan día por día hasta el examen. Los capítulos deben titularse obligatoriamente "Día 1: ...", "Día 2: ...", etc., asignando a cada día pasos concretos de asimilación, práctica o simulacro.

            Responde OBLIGATORIAMENTE en JSON puro válido conforme a este esquema:
            {
              "chapters": [
                {
                  "title": "Día 1: Asimilación y Conceptos Clave",
                  "steps": [
                    { "title": "Lectura y conceptos iniciales", "estimatedMinutes": 40 },
                    { "title": "Esquema y fórmulas esenciales", "estimatedMinutes": 30 }
                  ]
                }
              ]
            }
            """
            
            if let plan = await callGeminiForPlan(prompt: prompt, key: key, subject: subject, title: title, examDate: examDate, difficulty: difficulty) {
                return plan
            }
        }
        
        // Smart Local Spaced Repetition Fallback
        return generateLocalPlan(subject: subject, title: title, examDate: examDate, difficulty: difficulty, notes: notes)
    }
    
    private func callGeminiForPlan(
        prompt: String,
        key: String,
        subject: String,
        title: String,
        examDate: Date,
        difficulty: ExamDifficulty
    ) async -> ExamPlan? {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent") else {
            Self.logger.error("Invalid Gemini API URL endpoint")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        
        let payload = GeminiRequest(
            contents: [GeminiContent(parts: [GeminiContentPart(text: prompt)])],
            generationConfig: GeminiGenerationConfig(responseMimeType: "application/json")
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(payload)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpRes = response as? HTTPURLResponse else {
                Self.logger.warning("No HTTP response received from Gemini API")
                return nil
            }
            
            guard httpRes.statusCode == 200 else {
                Self.logger.warning("Gemini plan generation failed with status code: \(httpRes.statusCode)")
                return nil
            }
            
            let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
            if let text = decoded.candidates?.first?.content?.parts?.first?.text {
                var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if let match = text.range(of: #"\{[\s\S]*\}"#, options: .regularExpression) {
                    cleaned = String(text[match])
                }
                
                if let planData = cleaned.data(using: .utf8),
                   let parsed = try? JSONSerialization.jsonObject(with: planData) as? [String: Any],
                   let chaptersArray = parsed["chapters"] as? [[String: Any]] {
                    
                    let calendar = Calendar.current
                    let startOfToday = calendar.startOfDay(for: Date())
                    let startOfExam = calendar.startOfDay(for: examDate)
                    let daysUntilExam = max(1, calendar.dateComponents([.day], from: startOfToday, to: startOfExam).day ?? 7)
                    
                    var totalStepsCount = 0
                    for chapDict in chaptersArray {
                        let steps = chapDict["steps"] as? [[String: Any]] ?? []
                        totalStepsCount += max(1, steps.count)
                    }
                    totalStepsCount = max(1, totalStepsCount)
                    
                    var stepCounter = 0
                    var chapters: [ExamChapter] = []
                    
                    for (cIdx, chapDict) in chaptersArray.enumerated() {
                        let chapTitle = chapDict["title"] as? String ?? "Capítulo"
                        var steps: [ExamStep] = []
                        let stepsArray = chapDict["steps"] as? [[String: Any]] ?? []
                        
                        for stepDict in stepsArray {
                            stepCounter += 1
                            let stepTitle = stepDict["title"] as? String ?? "Paso de estudio"
                            let mins = stepDict["estimatedMinutes"] as? Int ?? 40
                            let offset = min(daysUntilExam, max(1, Int(round(Double(stepCounter) / Double(totalStepsCount) * Double(daysUntilExam)))))
                            let targetDate = calendar.date(byAdding: .day, value: offset, to: startOfToday)
                            
                            steps.append(ExamStep(title: stepTitle, isCompleted: false, targetDate: targetDate, estimatedMinutes: mins))
                        }
                        
                        if steps.isEmpty {
                            stepCounter += 1
                            let offset = min(daysUntilExam, max(1, Int(round(Double(stepCounter) / Double(totalStepsCount) * Double(daysUntilExam)))))
                            steps.append(ExamStep(title: "Repaso de \(chapTitle)", isCompleted: false, targetDate: calendar.date(byAdding: .day, value: offset, to: startOfToday), estimatedMinutes: 40))
                        }
                        
                        let recOffset = min(daysUntilExam, max(1, Int(round(Double(cIdx + 1) / Double(max(1, chaptersArray.count)) * Double(daysUntilExam)))))
                        let recDate = calendar.date(byAdding: .day, value: recOffset, to: startOfToday)
                        chapters.append(ExamChapter(title: chapTitle, recommendedDate: recDate, steps: steps))
                    }
                    
                    return ExamPlan(
                        title: title,
                        subject: subject,
                        examDate: examDate,
                        difficulty: difficulty,
                        chapters: chapters
                    )
                }
            }
        } catch {
            Self.logger.error("Gemini plan generation error: \(error.localizedDescription)")
            return nil
        }
        return nil
    }
    
    // MARK: - Generate Mock Exam Quiz
    public func generateMockQuiz(for plan: ExamPlan) async -> [QuizQuestion] {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.count > 10 {
            let prompt = """
            Genera un cuestionario de 3 preguntas tipo test para evaluar el siguiente examen:
            - Asignatura: "\(plan.subject)"
            - Título: "\(plan.title)"
            - Dificultad: "\(plan.difficulty.rawValue)"

            Responde estrictamente en formato JSON con esta estructura:
            [
              {
                "question": "Texto de la pregunta",
                "options": ["Opción A", "Opción B", "Opción C", "Opción D"],
                "correctIndex": 0,
                "explanation": "Argumentación pedagógica detallada de por qué esta opción es la correcta."
              }
            ]
            """
            
            if let questions = await callGeminiForQuiz(prompt: prompt, key: key) {
                return questions
            }
        }
        
        // Local Quiz Fallback
        return [
            QuizQuestion(
                question: "¿Cuál es el método más efectivo según la curva del olvido de Ebbinghaus para dominar \(plan.title)?",
                options: [
                  "Repetición espaciada con autoevaluación activa y resolución de problemas",
                  "Lectura pasiva una única vez sin comprobar la retención",
                  "Memorización forzada la noche antes del examen",
                  "Descartar los conceptos teóricos y confiar en el azar"
                ],
                correctIndex: 0,
                explanation: "La repetición espaciada reactiva las conexiones neuronales antes de que el recuerdo se degrade, optimizando la memoria a largo plazo."
            ),
            QuizQuestion(
                question: "Al enfrentarse a un caso práctico de \(plan.subject), ¿cuál es el primer paso recomendado?",
                options: [
                  "Anotar la solución inmediatamente sin leer el problema",
                  "Desglosar el enunciado, identificar variables y estructurar el enfoque",
                  "Copiar fórmulas sin justificar su aplicabilidad",
                  "Pasar a la siguiente pregunta sin intentarlo"
                ],
                correctIndex: 1,
                explanation: "El análisis sistemático del enunciado previene sesgos cognitivos y garantiza un planteamiento riguroso."
            ),
            QuizQuestion(
                question: "¿Qué papel juega el análisis de errores en los simulacros de \(plan.title)?",
                options: [
                  "Ninguno, solo importa contabilizar la nota final",
                  "Permite la metacognición para convertir lagunas en aprendizaje profundo",
                  "Indica que no vale la pena seguir repasando",
                  "Demuestra que el temario estaba mal diseñado"
                ],
                correctIndex: 1,
                explanation: "Aprender de los fallos reestructura los modelos mentales y consolida el dominio definitivo de la materia."
            )
        ]
    }
    
    private func callGeminiForQuiz(prompt: String, key: String) async -> [QuizQuestion]? {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent") else {
            Self.logger.error("Invalid Gemini API URL endpoint for quiz")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        
        let payload = GeminiRequest(
            contents: [GeminiContent(parts: [GeminiContentPart(text: prompt)])],
            generationConfig: GeminiGenerationConfig(responseMimeType: "application/json")
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(payload)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
                Self.logger.warning("Gemini quiz generation HTTP error")
                return nil
            }
            
            let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
            if let text = decoded.candidates?.first?.content?.parts?.first?.text {
                var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if let match = text.range(of: #"\[[\s\S]*\]"#, options: .regularExpression) {
                    cleaned = String(text[match])
                }
                if let quizData = cleaned.data(using: .utf8) {
                    return try? JSONDecoder().decode([QuizQuestion].self, from: quizData)
                }
            }
        } catch {
            Self.logger.error("Gemini quiz generation error: \(error.localizedDescription)")
            return nil
        }
        return nil
    }
    
    // MARK: - Direct Chat with Aethelgard Study AI
    public func chatWithAethelgard(
        message: String,
        context: String
    ) async -> String {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.count > 10 {
            let prompt = """
            Eres Aethelgard Study AI, el tutor pedagógico inteligente e interactivo de StudyFlow.
            Tu misión es acompañar al estudiante en su preparación de exámenes, resolución de dudas académicas, organización de su calendario y optimización de su técnica de estudio (Pomodoro, Repetición Espaciada y Feynman).
            
            Contexto actual del estudiante en la app:
            \(context)
            
            Pregunta o mensaje del estudiante:
            "\(message)"
            
            Directrices de respuesta:
            1. Tono motivador, riguroso, empático y estructurado.
            2. CONCISIÓN Y FORMATO MÓVIL (CRÍTICO): Escribe SIEMPRE respuestas cortas y directas al grano, adaptadas a pantallas de móvil. Si una duda puede resolverse en 2 o 3 frases o con una lista con viñetas muy breve, hazlo así. No uses párrafos largos innecesarios.
            3. Evita explicaciones vacías. Si explicas un concepto, usa analogías claras y pasos concretos.
            4. Si el estudiante tiene un examen próximo, anímale e indícale su próximo paso en el calendario.
            
            CAPACIDAD DE CONFIGURAR EXÁMENES Y CREAR PLANES EN EL CALENDARIO:
            - Si el usuario te pide crear un plan de estudio, programar o añadir un examen en su calendario (por ejemplo: "tengo examen de...", "crea un plan para...", "añade el examen de..."):
              1. Explícale brevemente en texto cómo has estructurado las fases pedagógicas de repaso (Asimilación, Práctica Feynman y Simulacro).
              2. AL FINAL de tu respuesta, INCLUYE OBLIGATORIAMENTE un bloque de acción JSON con este formato exacto:
            ```json:action
            {
              "action": "create_exam_plan",
              "subject": "Nombre de la Asignatura",
              "title": "Título descriptivo del examen",
              "examDate": "YYYY-MM-DD",
              "difficulty": "easy" | "medium" | "hard",
              "chapters": [
                {
                  "title": "Fase 1: Asimilación Conceptual",
                  "steps": [
                    { "title": "Subtema o lectura", "estimatedMinutes": 40 }
                  ]
                },
                {
                  "title": "Fase 2: Consolidación & Práctica Feynman",
                  "steps": [
                    { "title": "Resolución de ejercicios tipo", "estimatedMinutes": 45 }
                  ]
                },
                {
                  "title": "Fase 3: Simulacro y Cierre Cronometrado",
                  "steps": [
                    { "title": "Simulacro completo bajo reloj", "estimatedMinutes": 60 }
                  ]
                }
              ]
            }
            ```
            StudyFlow detectará este bloque automáticamente, programará los días en el Calendario y creará el plan interactivo.
            """
            
            if let answer = await callGeminiForChat(prompt: prompt, key: key) {
                return answer
            }
        }
        
        // Intelligent Offline Pedagogical Fallback
        return generateOfflineChatResponse(message: message, context: context)
    }
    
    private func callGeminiForChat(prompt: String, key: String) async -> String? {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent") else {
            Self.logger.error("Invalid Gemini API URL endpoint for chat")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        
        let payload = GeminiRequest(
            contents: [GeminiContent(parts: [GeminiContentPart(text: prompt)])],
            generationConfig: nil
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(payload)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
                Self.logger.warning("Gemini chat HTTP error")
                return nil
            }
            
            let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
            if let text = decoded.candidates?.first?.content?.parts?.first?.text {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            Self.logger.error("Gemini chat generation error: \(error.localizedDescription)")
            return nil
        }
        return nil
    }
    
    // MARK: - Local Spaced Repetition Plan Generator (Day-by-Day)
    private func generateLocalPlan(
        subject: String,
        title: String,
        examDate: Date,
        difficulty: ExamDifficulty,
        notes: String
    ) -> ExamPlan {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfExam = calendar.startOfDay(for: examDate)
        let daysUntilExam = max(1, calendar.dateComponents([.day], from: startOfToday, to: startOfExam).day ?? 7)
        
        let lines = notes.components(separatedBy: .newlines).filter { $0.trimmingCharacters(in: .whitespaces).count > 3 }
        let topic1 = lines.indices.contains(0) ? lines[0] : "Fundamentos y Conceptos Clave"
        let topic2 = lines.indices.contains(1) ? lines[1] : "Aplicación Práctica y Ejercicios"
        let topic3 = lines.indices.contains(2) ? lines[2] : "Resolución de Dudas y Modelos de Examen"
        
        var chapters: [ExamChapter] = []
        let numDays = min(max(3, daysUntilExam), 7)
        
        for dayIdx in 1...numDays {
            let dayDate = calendar.date(byAdding: .day, value: dayIdx - 1, to: startOfToday) ?? startOfToday
            let dayTitle: String
            let steps: [ExamStep]
            
            if dayIdx == 1 {
                dayTitle = "Día 1: Asimilación y Conceptos Clave (\(topic1))"
                steps = [
                    ExamStep(title: "\(topic1) — Lectura comprensiva y subrayado activo", isCompleted: false, targetDate: dayDate, estimatedMinutes: 35),
                    ExamStep(title: "Elaboración de esquemas conceptuales y fórmulas", isCompleted: false, targetDate: dayDate, estimatedMinutes: 25)
                ]
            } else if dayIdx == numDays {
                dayTitle = "Día \(dayIdx): Simulacro Final y Cierre Cronometrado"
                steps = [
                    ExamStep(title: "Simulacro completo bajo reloj (condiciones reales)", isCompleted: false, targetDate: dayDate, estimatedMinutes: 60),
                    ExamStep(title: "Repaso relámpago con Spaced Repetition", isCompleted: false, targetDate: dayDate, estimatedMinutes: 20)
                ]
            } else if dayIdx == numDays - 1 {
                dayTitle = "Día \(dayIdx): Técnica Feynman y Repaso Activo"
                steps = [
                    ExamStep(title: "Explicar conceptos en voz alta sin mirar notas (Feynman)", isCompleted: false, targetDate: dayDate, estimatedMinutes: 40),
                    ExamStep(title: "Resolución de dudas críticas del temario", isCompleted: false, targetDate: dayDate, estimatedMinutes: 30)
                ]
            } else {
                let topic = lines.indices.contains(dayIdx - 1) ? lines[dayIdx - 1] : (dayIdx % 2 == 0 ? topic2 : topic3)
                dayTitle = "Día \(dayIdx): Práctica Intensiva y Ejercicios (\(topic))"
                steps = [
                    ExamStep(title: "\(topic) — Resolución de ejercicios tipo", isCompleted: false, targetDate: dayDate, estimatedMinutes: 45),
                    ExamStep(title: "Identificación y corrección de errores típicos", isCompleted: false, targetDate: dayDate, estimatedMinutes: 20)
                ]
            }
            chapters.append(ExamChapter(title: dayTitle, recommendedDate: dayDate, steps: steps))
        }
        
        return ExamPlan(
            title: title,
            subject: subject,
            examDate: examDate,
            difficulty: difficulty,
            chapters: chapters
        )
    }
    
    private func generateOfflineChatResponse(message: String, context: String) -> String {
        let lower = message.lowercased()
        
        // Check if user is asking to plan an exam / create a plan
        if lower.contains("examen") && (lower.contains("plan") || lower.contains("añade") || lower.contains("prepara") || lower.contains("calendario")) {
            let targetDateStr: String
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let future = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
            targetDateStr = formatter.string(from: future)
            
            var guessedSubject = "Historia"
            if lower.contains("mate") || lower.contains("cálculo") || lower.contains("álgebra") {
                guessedSubject = "Matemáticas"
            } else if lower.contains("bio") || lower.contains("ciencias") {
                guessedSubject = "Biología"
            } else if lower.contains("física") {
                guessedSubject = "Física"
            } else if lower.contains("química") {
                guessedSubject = "Química"
            } else if lower.contains("filo") {
                guessedSubject = "Filosofía"
            } else if lower.contains("inglés") {
                guessedSubject = "Inglés"
            }
            
            return """
            He preparado tu plan de preparación pedagógica estructurado en 3 fases de consolidación activa: Asimilación Conceptual, Práctica Feynman y Simulacro Cronometrado.
            
            ```json:action
            {
              "action": "create_exam_plan",
              "subject": "\(guessedSubject)",
              "title": "Examen de \(guessedSubject)",
              "examDate": "\(targetDateStr)",
              "difficulty": "medium",
              "chapters": [
                {
                  "title": "Fase 1: Asimilación Conceptual",
                  "steps": [
                    { "title": "Lectura activa del temario y mapa conceptual", "estimatedMinutes": 40 },
                    { "title": "Fichas de memoria de definiciones clave", "estimatedMinutes": 30 }
                  ]
                },
                {
                  "title": "Fase 2: Consolidación & Práctica Feynman",
                  "steps": [
                    { "title": "Resolución de ejercicios tipo y casos prácticos", "estimatedMinutes": 45 },
                    { "title": "Explicación socrática de conceptos sin notas", "estimatedMinutes": 40 }
                  ]
                },
                {
                  "title": "Fase 3: Simulacro y Cierre Cronometrado",
                  "steps": [
                    { "title": "Simulacro completo bajo reloj", "estimatedMinutes": 60 }
                  ]
                }
              ]
            }
            ```
            """
        }
        
        if lower.contains("organizo") || lower.contains("hoy") || lower.contains("sesion") || lower.contains("sesión") {
            return """
            Vamos a planificar tu jornada con máxima eficiencia cognitiva:

            1. **Bloque 1 (25 min - Pomodoro):** Elige el tema más desafiante de tu temario. Sin distracciones.
            2. **Descanso Activo (5 min):** Hidrátate y estira la espalda, sin pantallas.
            3. **Bloque 2 (25 min):** Resolución activa de problemas o autoevaluación (Active Recall).
            4. **Cierre de Racha:** Al terminar, registra tu sesión para sumar +50 XP y mantener protegida tu racha.
            """
        } else if lower.contains("feynman") || lower.contains("dificil") || lower.contains("difícil") || lower.contains("concepto") {
            return """
            La **Técnica Feynman** es el método para dominar cualquier concepto complejo:

            1. **Elige el concepto:** Escribe el título en una hoja en blanco.
            2. **Explícalo como a un niño de 10 años:** Usa vocabulario sencillo y analogías cotidianas.
            3. **Identifica tus bloqueos:** Cuando te trabes, vuelve a tus notas solo para aclarar ese punto exacto.
            4. **Simplifica y conecta:** Reescribe la explicación hasta que fluya con naturalidad.
            """
        } else if lower.contains("olvido") || lower.contains("ebbinghaus") || lower.contains("memoria") || lower.contains("repaso") {
            return """
            La **Curva del Olvido de Ebbinghaus** demuestra que olvidamos hasta el 70% de lo estudiado en las primeras 48 horas si no hay reactivación:

            - **Repaso 1:** A las 24 horas (5-10 minutos de recapitulación rápida).
            - **Repaso 2:** Al 3er día (resolver 3 ejercicios prácticos).
            - **Repaso 3:** Al 7º día (simulacro o flashcards).
            - **Repaso 4:** A los 14-21 días (consolidación permanente en la memoria a largo plazo).
            """
        }
        
        return """
        Como tu tutor Aethelgard, te recomiendo abordar este reto desglosándolo en tres fases:

        1. **Diagnóstico:** Identifica qué aspecto concreto te genera más fricción.
        2. **Aplicación:** Resuelve un ejemplo práctico inmediatamente usando la técnica de Estudio Activo.
        3. **Validación:** Comprueba tu respuesta o utiliza nuestro generador de Simulacros para medir tu dominio.

        ¿Quieres que preparemos un plan de estudio en tu calendario o prefieres configurar una sesión Pomodoro ahora?
        """
    }
}
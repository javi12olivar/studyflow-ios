import SwiftUI

// MARK: - Chat Message Model
public struct ChatMessage: Identifiable, Equatable, Sendable, Codable {
    public let id: UUID
    public let isUser: Bool
    public let text: String
    public let createdPlan: ExamPlan?
    public let timestamp: Date
    
    public init(id: UUID = UUID(), isUser: Bool, text: String, createdPlan: ExamPlan? = nil, timestamp: Date = Date()) {
        self.id = id
        self.isUser = isUser
        self.text = text
        self.createdPlan = createdPlan
        self.timestamp = timestamp
    }
}

// MARK: - Chat Session Model
public struct ChatSession: Identifiable, Codable, Equatable {
    public let id: String
    public var title: String
    public var updatedAt: Date
    public var messages: [ChatMessage]
    
    public init(id: String = UUID().uuidString, title: String = "Nueva sesión", updatedAt: Date = Date(), messages: [ChatMessage] = []) {
        self.id = id
        self.title = title
        self.updatedAt = updatedAt
        self.messages = messages
    }
}

// MARK: - Aethelgard Chat View
public struct AethelgardChatView: View {
    @ObservedObject var streakManager: StreakManager
    @ObservedObject var planManager: ExamPlanManager
    
    @State private var sessions: [ChatSession] = []
    @State private var activeSessionId: String = ""
    @State private var showingSessionsSheet: Bool = false
    
    @State private var inputText: String = ""
    @State private var isThinking: Bool = false
    @State private var activeTask: Task<Void, Never>? = nil
    
    private let defaultWelcome = "¡Hola! Soy **Aethelgard**, tu tutor pedagógico de StudyFlow.\n\nEstoy aquí para guiarte en tu preparación de exámenes, resolver dudas conceptuales, optimizar tus bloques Pomodoro y aplicar la técnica de Repetición Espaciada para que nada se te olvide.\n\n¿En qué asignatura o tema nos enfocamos hoy?"
    
    private let suggestionChips = [
        "Planificar examen en mi Calendario",
        "Técnica Feynman para conceptos difíciles",
        "Estrategia de repaso para mi próximo examen",
        "¿Cómo vencer la curva del olvido?"
    ]
    
    public init(streakManager: StreakManager, planManager: ExamPlanManager) {
        self.streakManager = streakManager
        self.planManager = planManager
        
        let welcome = "¡Hola! Soy **Aethelgard**, tu tutor pedagógico de StudyFlow.\n\nEstoy aquí para guiarte en tu preparación de exámenes, resolver dudas conceptuales, optimizar tus bloques Pomodoro y aplicar la técnica de Repetición Espaciada para que nada se te olvide.\n\n¿En qué asignatura o tema nos enfocamos hoy?"
        
        if let data = UserDefaults.standard.data(forKey: "sf_chat_sessions"),
           let decoded = try? JSONDecoder().decode([ChatSession].self, from: data),
           !decoded.isEmpty {
            _sessions = State(initialValue: decoded)
            let savedId = UserDefaults.standard.string(forKey: "sf_active_session_id") ?? decoded[0].id
            _activeSessionId = State(initialValue: decoded.contains(where: { $0.id == savedId }) ? savedId : decoded[0].id)
        } else {
            let initial = ChatSession(title: "Nueva sesión", messages: [ChatMessage(isUser: false, text: welcome)])
            _sessions = State(initialValue: [initial])
            _activeSessionId = State(initialValue: initial.id)
        }
    }
    
    private var currentSession: ChatSession {
        if let found = sessions.first(where: { $0.id == activeSessionId }) {
            return found
        }
        return sessions.first ?? ChatSession(title: "Sesión inicial", messages: [ChatMessage(isUser: false, text: defaultWelcome)])
    }
    
    private var messages: [ChatMessage] {
        currentSession.messages
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Status Bar
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "sparkles")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Aethelgard Study AI")
                            .font(.system(size: 15, weight: .bold))
                        HStack(spacing: 6) {
                            Circle()
                                .fill(GroqService.shared.apiKey.count > 5 ? Color.orange : (MistralService.shared.apiKey.count > 5 ? Color.purple : (GeminiService.shared.apiKey.count > 10 ? Color.green : Color.gray)))
                                .frame(width: 7, height: 7)
                            Text(GroqService.shared.apiKey.count > 5 ? "Groq 70B Conectado" : (MistralService.shared.apiKey.count > 5 ? "Mistral Large 123B Conectado" : (GeminiService.shared.apiKey.count > 10 ? "Gemini Flash Conectado" : "Modo Pedagógico Activo")))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Student Context Pill
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                        Text("\(streakManager.currentStreak)d")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                
                Divider()
                
                // Messages Scroll
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(messages) { msg in
                                ChatBubbleRow(message: msg)
                            }
                            
                            if isThinking {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Aethelgard está estructurando la respuesta...")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .id("thinking_indicator")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 10)
                    }
                    .onChange(of: messages.count) { _ in
                        withAnimation {
                            if let last = messages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: isThinking) { thinking in
                        if thinking {
                            withAnimation {
                                proxy.scrollTo("thinking_indicator", anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Quick Suggestion Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestionChips, id: \.self) { chip in
                            Button(action: {
                                HapticManager.shared.light()
                                sendMessage(chip)
                            }) {
                                Text(chip)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(Color(UIColor.secondarySystemGroupedBackground))
                                    .cornerRadius(14)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                
                Divider()
                
                // Input Bar
                HStack(spacing: 10) {
                    TextField("Pregunta a Aethelgard sobre tu estudio...", text: $inputText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(20)
                        .font(.system(size: 14))
                        .onSubmit {
                            sendMessage(inputText)
                        }
                    
                    Button(action: {
                        sendMessage(inputText)
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? .gray.opacity(0.4) : .orange)
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isThinking)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(UIColor.systemGroupedBackground))
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Button(action: {
                        HapticManager.shared.light()
                        showingSessionsSheet = true
                    }) {
                        HStack(spacing: 6) {
                            Text(currentSession.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        createNewSession()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .bold))
                            Text("Nueva")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.orange)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        HapticManager.shared.light()
                        showingSessionsSheet = true
                    }) {
                        Image(systemName: "clock")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showingSessionsSheet) {
                ChatSessionsSheet(
                    sessions: $sessions,
                    activeSessionId: $activeSessionId,
                    onSelectSession: { id in
                        activeTask?.cancel()
                        isThinking = false
                        activeSessionId = id
                        saveSessions()
                        showingSessionsSheet = false
                    },
                    onCreateNew: {
                        createNewSession()
                        showingSessionsSheet = false
                    },
                    onDeleteSession: { id in
                        deleteSession(id: id)
                    }
                )
            }
            .onAppear {
                loadSessions()
            }
            .onDisappear {
                activeTask?.cancel()
            }
        }
    }
    
    private func loadSessions() {
        if let data = UserDefaults.standard.data(forKey: "sf_chat_sessions"),
           let decoded = try? JSONDecoder().decode([ChatSession].self, from: data),
           !decoded.isEmpty {
            self.sessions = decoded
            self.activeSessionId = UserDefaults.standard.string(forKey: "sf_active_session_id") ?? decoded[0].id
            if !sessions.contains(where: { $0.id == activeSessionId }) {
                self.activeSessionId = sessions[0].id
            }
        } else {
            let initial = ChatSession(title: "Nueva sesión", messages: [ChatMessage(isUser: false, text: defaultWelcome)])
            self.sessions = [initial]
            self.activeSessionId = initial.id
            saveSessions()
        }
    }
    
    private func saveSessions() {
        if let encoded = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(encoded, forKey: "sf_chat_sessions")
            UserDefaults.standard.set(activeSessionId, forKey: "sf_active_session_id")
        }
    }
    
    private func createNewSession() {
        activeTask?.cancel()
        isThinking = false
        let newSess = ChatSession(title: "Nueva sesión", messages: [ChatMessage(isUser: false, text: defaultWelcome)])
        sessions.insert(newSess, at: 0)
        activeSessionId = newSess.id
        saveSessions()
        HapticManager.shared.light()
    }
    
    private func deleteSession(id: String) {
        sessions.removeAll(where: { $0.id == id })
        if sessions.isEmpty {
            createNewSession()
        } else if activeSessionId == id {
            activeSessionId = sessions[0].id
        }
        saveSessions()
        HapticManager.shared.medium()
    }
    
    private func appendMessageToActiveSession(_ msg: ChatMessage) {
        guard let idx = sessions.firstIndex(where: { $0.id == activeSessionId }) else { return }
        sessions[idx].messages.append(msg)
        sessions[idx].updatedAt = Date()
        saveSessions()
    }
    
    private func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        HapticManager.shared.light()
        let userMsg = ChatMessage(isUser: true, text: trimmed)
        appendMessageToActiveSession(userMsg)
        
        if currentSession.title == "Nueva sesión" {
            if let idx = sessions.firstIndex(where: { $0.id == activeSessionId }) {
                sessions[idx].title = String(trimmed.prefix(32))
                saveSessions()
            }
        }
        
        inputText = ""
        isThinking = true
        
        // Build Dynamic Student Context
        var context = "Racha actual: \(streakManager.currentStreak) días. XP acumulada: \(streakManager.totalXP).\n"
        if planManager.plans.isEmpty {
            context += "No tiene exámenes activos registrados en este momento.\n"
        } else {
            context += "Exámenes registrados:\n"
            for plan in planManager.plans {
                context += "- \(plan.title) (\(plan.subject)), en \(plan.daysRemaining) días. Progreso: \(plan.completedStepsCount)/\(plan.totalStepsCount) pasos completados.\n"
            }
        }
        
        activeTask?.cancel()
        activeTask = Task { @MainActor in
            defer { isThinking = false }
            var responseText: String? = nil
            
            if GroqService.shared.apiKey.count > 5 {
                responseText = await GroqService.shared.chat(message: trimmed, context: context)
            }
            guard !Task.isCancelled else { return }
            
            if responseText == nil && MistralService.shared.apiKey.count > 5 {
                responseText = await MistralService.shared.chat(message: trimmed, context: context)
            }
            guard !Task.isCancelled else { return }
            
            if responseText == nil {
                responseText = await GeminiService.shared.chatWithAethelgard(message: trimmed, context: context)
            }
            guard !Task.isCancelled else { return }
            
            var cleanText = responseText ?? "No se pudo obtener respuesta."
            var newPlan: ExamPlan? = nil
            
            // Check for create_exam_plan action JSON in reply
            if let raw = responseText {
                let pattern = #"(?s)```(?:json:action|json)?\s*(\{.*?"action"\s*:\s*"create_exam_plan".*?\})\s*```"#
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    let nsString = raw as NSString
                    let results = regex.matches(in: raw, options: [], range: NSRange(location: 0, length: nsString.length))
                    if let firstMatch = results.first, firstMatch.numberOfRanges > 1 {
                        let subRange = firstMatch.range(at: 1)
                        if subRange.location != NSNotFound {
                            let jsonStr = nsString.substring(with: subRange)
                            if let jsonData = jsonStr.data(using: .utf8),
                               let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                                
                                let subject = dict["subject"] as? String ?? "General"
                                let title = dict["title"] as? String ?? "Examen de \(subject)"
                                let dateStr = dict["examDate"] as? String ?? ""
                                
                                let formatter = DateFormatter()
                                formatter.locale = Locale(identifier: "en_US_POSIX")
                                formatter.dateFormat = "yyyy-MM-dd"
                                let fallbackDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date().addingTimeInterval(7 * 86400)
                                let targetDate = formatter.date(from: dateStr) ?? fallbackDate
                                
                                var chapters: [ExamChapter] = []
                                if let rawChapters = dict["chapters"] as? [[String: Any]] {
                                    for (cIdx, chapDict) in rawChapters.enumerated() {
                                        let chapTitle = chapDict["title"] as? String ?? "Fase \(cIdx + 1): Preparación"
                                        var steps: [ExamStep] = []
                                        if let rawSteps = chapDict["steps"] as? [[String: Any]] {
                                            for st in rawSteps {
                                                let sTitle = st["title"] as? String ?? "Sesión de estudio"
                                                steps.append(ExamStep(title: sTitle))
                                            }
                                        }
                                        if steps.isEmpty {
                                            steps = [ExamStep(title: "Repaso conceptual"), ExamStep(title: "Resolución de ejercicios")]
                                        }
                                        chapters.append(ExamChapter(title: chapTitle, steps: steps))
                                    }
                                }
                                
                                let diffStr = (dict["difficulty"] as? String ?? "medium").lowercased()
                                let diff: ExamDifficulty = diffStr == "easy" ? .easy : (diffStr == "hard" ? .hard : .medium)
                                
                                let created = ExamPlan(
                                    title: title,
                                    subject: subject,
                                    examDate: targetDate,
                                    difficulty: diff,
                                    chapters: chapters
                                )
                                planManager.addPlan(created)
                                streakManager.addXP(30)
                                newPlan = created
                            }
                            cleanText = regex.stringByReplacingMatches(in: raw, options: [], range: NSRange(location: 0, length: nsString.length), withTemplate: "").trimmingCharacters(in: .whitespacesAndNewlines)
                            if cleanText.isEmpty {
                                cleanText = "He creado y programado el plan de examen para \(newPlan?.title ?? "tu asignatura") en tu calendario."
                            }
                        }
                    }
                }
            }
            
            appendMessageToActiveSession(ChatMessage(isUser: false, text: cleanText, createdPlan: newPlan))
            HapticManager.shared.medium()
        }
    }
}

// MARK: - Chat Bubble Row
struct ChatBubbleRow: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if message.isUser {
                Spacer(minLength: 40)
                Text(LocalizedStringKey(message.text))
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.secondarySystemGroupedBackground).opacity(1.3))
                    .cornerRadius(18)
            } else {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "graduationcap.fill")
                            .font(.system(size: 14))
                    )
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedStringKey(message.text))
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                        )
                    
                    if let plan = message.createdPlan {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 8, height: 8)
                                Text(plan.subject)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.orange)
                                Spacer()
                                Text(plan.difficulty.rawValue)
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(plan.difficulty.color.opacity(0.2))
                                    .foregroundColor(plan.difficulty.color)
                                    .cornerRadius(6)
                            }
                            Text(plan.title)
                                .font(.system(size: 14, weight: .bold))
                            Text("Examen: \(plan.examDate.formatted(date: .abbreviated, time: .omitted)) (\(plan.daysRemaining) días restantes)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10))
                                Text("\(plan.totalStepsCount) sesiones de repaso programadas en tu calendario")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(Color(UIColor.tertiarySystemGroupedBackground))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.orange.opacity(0.35), lineWidth: 1)
                        )
                    }
                }
                Spacer(minLength: 40)
            }
        }
    }
}

// MARK: - Chat Sessions Sheet
struct ChatSessionsSheet: View {
    @Binding var sessions: [ChatSession]
    @Binding var activeSessionId: String
    let onSelectSession: (String) -> Void
    let onCreateNew: () -> Void
    let onDeleteSession: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(action: onCreateNew) {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 20))
                            Text("Iniciar nueva conversación")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.orange)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section(header: Text("Conversaciones guardadas")) {
                    ForEach(sessions) { session in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.title)
                                    .font(.system(size: 15, weight: session.id == activeSessionId ? .bold : .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                Text("\(session.messages.count) mensajes")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if session.id == activeSessionId {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.orange)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelectSession(session.id)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            onDeleteSession(sessions[index].id)
                        }
                    }
                }
            }
            .navigationTitle("Sesiones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                }
            }
        }
    }
}

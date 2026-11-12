import SwiftUI

public struct StudyTimerView: View {
    @ObservedObject var streakManager: StreakManager
    
    @State private var selectedDurationMinutes: Int = 25
    @State private var timeRemaining: Int = 25 * 60
    @State private var timerIsRunning: Bool = false
    @State private var timer: Timer? = nil
    @State private var minutesStudiedInSession: Int = 0
    @State private var sessionEarnedXP: Int = 0
    
    public init(streakManager: StreakManager) {
        self.streakManager = streakManager
    }
    
    private var totalSeconds: Int {
        selectedDurationMinutes * 60
    }
    
    private var progress: Double {
        guard totalSeconds > 0 else { return 0.0 }
        return Double(totalSeconds - timeRemaining) / Double(totalSeconds)
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Preset Selector
                if !timerIsRunning {
                    HStack(spacing: 12) {
                        ForEach([15, 25, 45, 60], id: \.self) { mins in
                            Button(action: {
                                HapticManager.shared.light()
                                selectedDurationMinutes = mins
                                timeRemaining = mins * 60
                            }) {
                                Text("\(mins) min")
                                    .font(.system(size: 14, weight: .semibold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedDurationMinutes == mins ? Color.orange : Color(UIColor.secondarySystemGroupedBackground))
                                    .foregroundColor(selectedDurationMinutes == mins ? .white : .primary)
                                    .cornerRadius(14)
                            }
                        }
                    }
                    .padding(.top, 10)
                }
                
                Spacer()
                
                // Circular Timer Gauge
                ZStack {
                    // Outer Track
                    Circle()
                        .stroke(Color.gray.opacity(0.15), lineWidth: 16)
                        .frame(width: 260, height: 260)
                    
                    // Animated Progress Fill
                    Circle()
                        .trim(from: 0.0, to: CGFloat(progress))
                        .stroke(
                            LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 16, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 260, height: 260)
                        .animation(.linear(duration: 1.0), value: timeRemaining)
                    
                    // Central Clock & XP Display
                    VStack(spacing: 6) {
                        Text(formatTime(timeRemaining))
                            .font(.system(size: 52, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.orange)
                            Text("+\(sessionEarnedXP) XP acumulados")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Control Buttons
                HStack(spacing: 24) {
                    // Reset Button
                    Button(action: {
                        HapticManager.shared.medium()
                        resetTimer()
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 58, height: 58)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .clipShape(Circle())
                    }
                    
                    // Play / Pause Main Button
                    Button(action: {
                        HapticManager.shared.heavy()
                        toggleTimer()
                    }) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 78, height: 78)
                                .shadow(color: .orange.opacity(0.4), radius: 12, y: 4)
                            
                            Image(systemName: timerIsRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                                .offset(x: timerIsRunning ? 0 : 2)
                        }
                    }
                    
                    // Complete Session Early Button
                    Button(action: {
                        HapticManager.shared.success()
                        finishSession()
                    }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.orange)
                            .frame(width: 58, height: 58)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("Temporizador de Estudio")
            .onDisappear {
                if timerIsRunning {
                    timer?.invalidate()
                    timer = nil
                    timerIsRunning = false
                }
            }
        }
    }
    
    private func toggleTimer() {
        if timerIsRunning {
            timer?.invalidate()
            timer = nil
            timerIsRunning = false
        } else {
            timer?.invalidate()
            timerIsRunning = true
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                if timeRemaining > 0 {
                    timeRemaining -= 1
                    // Award 2 XP per minute studied (as identified in Knowunity REA)
                    if (totalSeconds - timeRemaining) % 60 == 0 {
                        minutesStudiedInSession += 1
                        sessionEarnedXP += 2
                    }
                } else {
                    finishSession()
                }
            }
        }
    }
    
    private func resetTimer() {
        timer?.invalidate()
        timer = nil
        timerIsRunning = false
        timeRemaining = selectedDurationMinutes * 60
        minutesStudiedInSession = 0
        sessionEarnedXP = 0
    }
    
    private func finishSession() {
        timer?.invalidate()
        timer = nil
        timerIsRunning = false
        
        let completedMinutes = max(1, (totalSeconds - timeRemaining) / 60)
        streakManager.recordStudySession(minutes: completedMinutes)
        AudioManager.shared.play(.celebration)
        
        resetTimer()
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

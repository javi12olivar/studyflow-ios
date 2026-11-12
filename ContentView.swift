import SwiftUI

public struct ContentView: View {
    @StateObject private var streakManager = StreakManager()
    @StateObject private var planManager = ExamPlanManager()
    @State private var selectedTab: Int = 0
    
    public init() {}
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            StreakHubView(streakManager: streakManager)
                .tabItem {
                    Label("Racha", systemImage: "flame.fill")
                }
                .tag(0)
            
            ExamPlannerView(planManager: planManager, streakManager: streakManager)
                .tabItem {
                    Label("Exámenes", systemImage: "calendar.badge.clock")
                }
                .tag(1)
            
            AethelgardChatView(streakManager: streakManager, planManager: planManager)
                .tabItem {
                    Label("Tutor IA", systemImage: "sparkles")
                }
                .tag(2)
            
            StudyTimerView(streakManager: streakManager)
                .tabItem {
                    Label("Temporizador", systemImage: "timer")
                }
                .tag(3)
        }
        .tint(.orange)
        .environmentObject(streakManager)
        .environmentObject(planManager)
    }
}

#Preview {
    ContentView()
}
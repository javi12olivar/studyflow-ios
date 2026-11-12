import SwiftUI

public struct StreakHubView: View {
    @ObservedObject var streakManager: StreakManager
    @State private var showingUnfreezeSheet = false
    @State private var animateNumber = false
    
    public init(streakManager: StreakManager) {
        self.streakManager = streakManager
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Level & Freeze Inventory Top Bar
                    HStack {
                        // User Level Badge
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                                    .frame(width: 38, height: 38)
                                    .overlay(
                                        Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                                Text("\(streakManager.userLevel)")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Nivel \(streakManager.userLevel)")
                                    .font(.system(size: 14, weight: .bold))
                                Text("\(streakManager.totalXP) XP")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        // Freeze Token Pill
                        HStack(spacing: 6) {
                            Image(systemName: "snowflake")
                                .foregroundColor(.cyan)
                                .font(.system(size: 14, weight: .bold))
                            Text("\(streakManager.freezeCount)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.cyan.opacity(0.12))
                        .cornerRadius(20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    // Central Flame Stage
                    VStack(spacing: 12) {
                        NativeFlameView(
                            streakCount: streakManager.currentStreak,
                            isFrozen: streakManager.isFrozen
                        )
                        .frame(height: 200)
                        
                        // Streak Number & Subtitle
                        VStack(spacing: 4) {
                            Text("\(streakManager.currentStreak)")
                                .font(.system(size: 58, weight: .heavy, design: .rounded))
                                .foregroundColor(streakManager.isFrozen ? .cyan : .primary)
                                .scaleEffect(animateNumber ? 1.05 : 1.0)
                            
                            Text(streakManager.isFrozen ? "Racha congelada" : "Días de racha")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        
                        if streakManager.isFrozen {
                            Button(action: {
                                HapticManager.shared.medium()
                                showingUnfreezeSheet = true
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "flame.fill")
                                    Text("Romper el hielo y rescatar")
                                }
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.cyan)
                                .cornerRadius(16)
                                .shadow(color: .cyan.opacity(0.4), radius: 8, y: 3)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    // Weekly Streak Ribbon (7-Day Calendar)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Esta semana")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        
                        HStack(spacing: 10) {
                            ForEach(streakManager.getRecentDays()) { day in
                                VStack(spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(backgroundForStatus(day.status))
                                            .frame(width: 42, height: 42)
                                        
                                        iconForStatus(day.status)
                                    }
                                    
                                    Text(shortWeekday(for: day.dateString))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(20)
                        .padding(.horizontal, 20)
                    }
                    
                    // Milestone Badges Carousel
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Hitos de Racha")
                                .font(.system(size: 17, weight: .bold))
                            Spacer()
                            Text("Récord: \(streakManager.longestStreak) d")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(streakManager.milestoneGoals, id: \.self) { goal in
                                    let achieved = streakManager.longestStreak >= goal
                                    VStack(spacing: 8) {
                                        ZStack {
                                            Circle()
                                                .fill(achieved
                                                      ? Color.orange.opacity(0.15)
                                                      : Color(UIColor.tertiarySystemGroupedBackground))
                                                .frame(width: 56, height: 56)
                                            
                                            Image(systemName: achieved ? "trophy.fill" : "lock.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(achieved ? .orange : .gray.opacity(0.6))
                                        }
                                        
                                        Text("\(goal) Días")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(achieved ? .primary : .secondary)
                                    }
                                    .frame(width: 80)
                                    .padding(.vertical, 12)
                                    .background(Color(UIColor.secondarySystemGroupedBackground))
                                    .cornerRadius(18)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // Daily Goal Completion Button (1/day limiter)
                    Button(action: {
                        guard !streakManager.hasStudiedToday else { return }
                        HapticManager.shared.success()
                        AudioManager.shared.play(.celebration)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                            streakManager.recordStudySession(minutes: 25)
                            animateNumber = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            animateNumber = false
                        }
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: streakManager.hasStudiedToday ? "checkmark.seal.fill" : "checkmark.circle.fill")
                                .font(.system(size: 17, weight: .bold))
                            Text(streakManager.hasStudiedToday ? "Estudio de hoy completado (+50 XP)" : "Completar Sesión de Hoy (+50 XP)")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(streakManager.hasStudiedToday ? .secondary : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            streakManager.hasStudiedToday
                                ? Color(UIColor.secondarySystemGroupedBackground)
                                : Color.orange
                        )
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(streakManager.hasStudiedToday ? Color.gray.opacity(0.25) : Color.clear, lineWidth: 1)
                        )
                    }
                    .disabled(streakManager.hasStudiedToday)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Mi Racha")
            .sheet(isPresented: $showingUnfreezeSheet) {
                StreakUnfreezeSheet(streakManager: streakManager)
            }
        }
    }
    
    private func backgroundForStatus(_ status: DayStatus) -> Color {
        switch status {
        case .completed: return Color.orange.opacity(0.15)
        case .frozen: return Color.cyan.opacity(0.15)
        case .missed: return Color.red.opacity(0.1)
        case .pending: return Color(UIColor.tertiarySystemGroupedBackground)
        }
    }
    
    @ViewBuilder
    private func iconForStatus(_ status: DayStatus) -> some View {
        switch status {
        case .completed:
            Image(systemName: "flame.fill")
                .foregroundColor(.orange)
                .font(.system(size: 18))
        case .frozen:
            Image(systemName: "snowflake")
                .foregroundColor(.cyan)
                .font(.system(size: 18))
        case .missed:
            Image(systemName: "xmark")
                .foregroundColor(.red)
                .font(.system(size: 14, weight: .bold))
        case .pending:
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 8, height: 8)
        }
    }
    
    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    
    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "EEE"
        return f
    }()
    
    private func shortWeekday(for dateString: String) -> String {
        guard let date = Self.isoFormatter.date(from: dateString) else { return "" }
        return Self.weekdayFormatter.string(from: date).capitalized
    }
}

import Foundation
import SwiftUI

// MARK: - Streak Day Status
public enum DayStatus: String, Codable, Sendable {
    case completed
    case frozen
    case missed
    case pending
}

public struct StreakDay: Identifiable, Codable, Sendable {
    public var id: String { dateString }
    public let dateString: String // YYYY-MM-DD
    public var status: DayStatus
    
    public init(dateString: String, status: DayStatus) {
        self.dateString = dateString
        self.status = status
    }
}

// MARK: - Streak Manager & Model
@MainActor
public class StreakManager: ObservableObject {
    @Published public var currentStreak: Int {
        didSet { UserDefaults.standard.set(currentStreak, forKey: "sf_currentStreak") }
    }
    @Published public var longestStreak: Int {
        didSet { UserDefaults.standard.set(longestStreak, forKey: "sf_longestStreak") }
    }
    @Published public var freezeCount: Int {
        didSet { UserDefaults.standard.set(freezeCount, forKey: "sf_freezeCount") }
    }
    @Published public var isFrozen: Bool {
        didSet { UserDefaults.standard.set(isFrozen, forKey: "sf_isFrozen") }
    }
    @Published public var lastStudyDate: Date? {
        didSet { UserDefaults.standard.set(lastStudyDate, forKey: "sf_lastStudyDate") }
    }
    @Published public var totalXP: Int {
        didSet { UserDefaults.standard.set(totalXP, forKey: "sf_totalXP") }
    }
    @Published public var userLevel: Int {
        didSet { UserDefaults.standard.set(userLevel, forKey: "sf_userLevel") }
    }
    @Published public var completedDates: [String] {
        didSet { UserDefaults.standard.set(completedDates, forKey: "sf_completed_dates") }
    }
    
    // Milestones discovered from Knowunity REA: 3, 7, 10, 20, 30, 40, 50, 100
    public let milestoneGoals: [Int] = [3, 7, 10, 20, 30, 40, 50, 100]
    
    public var hasStudiedToday: Bool {
        guard let last = lastStudyDate else { return false }
        return Calendar.current.isDateInToday(last)
    }
    
    public static func dateToString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    public init() {
        self.currentStreak = UserDefaults.standard.integer(forKey: "sf_currentStreak")
        self.longestStreak = UserDefaults.standard.integer(forKey: "sf_longestStreak")
        self.freezeCount = UserDefaults.standard.object(forKey: "sf_freezeCount") != nil ? UserDefaults.standard.integer(forKey: "sf_freezeCount") : 2
        self.isFrozen = UserDefaults.standard.bool(forKey: "sf_isFrozen")
        self.lastStudyDate = UserDefaults.standard.object(forKey: "sf_lastStudyDate") as? Date
        self.totalXP = UserDefaults.standard.integer(forKey: "sf_totalXP")
        self.userLevel = max(1, UserDefaults.standard.integer(forKey: "sf_userLevel"))
        self.completedDates = UserDefaults.standard.stringArray(forKey: "sf_completed_dates") ?? []
        
        // Initial setup for demonstration if brand new
        if currentStreak == 0 && lastStudyDate == nil {
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            self.currentStreak = 5
            self.longestStreak = 14
            self.freezeCount = 2
            self.lastStudyDate = yesterday
            self.totalXP = 340
            self.userLevel = 3
            
            var pastDates: [String] = []
            for d in (1...5).reversed() {
                if let past = Calendar.current.date(byAdding: .day, value: -d, to: Date()) {
                    pastDates.append(Self.dateToString(past))
                }
            }
            self.completedDates = pastDates
            
            UserDefaults.standard.set(5, forKey: "sf_currentStreak")
            UserDefaults.standard.set(14, forKey: "sf_longestStreak")
            UserDefaults.standard.set(2, forKey: "sf_freezeCount")
            UserDefaults.standard.set(yesterday, forKey: "sf_lastStudyDate")
            UserDefaults.standard.set(340, forKey: "sf_totalXP")
            UserDefaults.standard.set(3, forKey: "sf_userLevel")
            UserDefaults.standard.set(pastDates, forKey: "sf_completed_dates")
        }
        
        checkIntegrityOnLaunch()
    }
    
    public func checkIntegrityOnLaunch() {
        guard let last = lastStudyDate else { return }
        let calendar = Calendar.current
        
        if calendar.isDateInToday(last) {
            return
        }
        
        if calendar.isDateInYesterday(last) {
            return
        }
        
        let daysMissed = calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: calendar.startOfDay(for: Date())).day ?? 0
        
        if daysMissed > 1 {
            if freezeCount > 0 && !isFrozen {
                freezeCount -= 1
                isFrozen = true
            } else if !isFrozen {
                currentStreak = 0
            }
        }
    }
    
    // Strict 1-per-day Daily Goal Completion
    public func completeDailyStreak() {
        guard !hasStudiedToday else { return }
        let calendar = Calendar.current
        let today = Date()
        let todayStr = Self.dateToString(today)
        
        if let last = lastStudyDate, calendar.isDateInYesterday(last) || isFrozen {
            currentStreak += 1
        } else {
            currentStreak = 1
        }
        
        if currentStreak > longestStreak {
            longestStreak = currentStreak
        }
        
        isFrozen = false
        lastStudyDate = today
        
        if !completedDates.contains(todayStr) {
            completedDates.append(todayStr)
        }
        
        addXP(50) // Exactly +50 XP bonus as specified in Knowunity REA
    }
    
    public func recordStudySession(minutes: Int) {
        let calendar = Calendar.current
        let today = Date()
        let todayStr = Self.dateToString(today)
        
        if let last = lastStudyDate, calendar.isDateInToday(last) {
            addXP(minutes * 2)
            return
        }
        
        if isFrozen {
            isFrozen = false
        }
        
        if let last = lastStudyDate, calendar.isDateInYesterday(last) {
            currentStreak += 1
        } else {
            currentStreak = 1
        }
        
        if currentStreak > longestStreak {
            longestStreak = currentStreak
        }
        
        lastStudyDate = today
        if !completedDates.contains(todayStr) {
            completedDates.append(todayStr)
        }
        
        addXP(minutes * 2 + 50)
    }
    
    public func completeStudySession(minutes: Int = 15) {
        recordStudySession(minutes: minutes)
    }
    
    public func unfreezeManually() {
        isFrozen = false
    }
    
    public func addXP(_ amount: Int) {
        totalXP += amount
        let calculatedLevel = (totalXP / 200) + 1
        if calculatedLevel > userLevel {
            userLevel = calculatedLevel
        }
    }
    
    public func isDateCompleted(_ dateStr: String) -> Bool {
        completedDates.contains(dateStr)
    }
    
    public func getRecentDays() -> [StreakDay] {
        let calendar = Calendar.current
        let today = Date()
        
        var days: [StreakDay] = []
        for i in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            let dStr = Self.dateToString(date)
            
            var status: DayStatus = .pending
            if i == 0 {
                if hasStudiedToday {
                    status = .completed
                } else if isFrozen {
                    status = .frozen
                } else {
                    status = .pending
                }
            } else if completedDates.contains(dStr) {
                status = .completed
            } else if i == 1 && isFrozen {
                status = .frozen
            } else {
                status = .missed
            }
            days.append(StreakDay(dateString: dStr, status: status))
        }
        return days
    }
}
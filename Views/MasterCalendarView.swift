import SwiftUI

// MARK: - Master Study Calendar View for iOS
public struct MasterCalendarView: View {
    @ObservedObject var planManager: ExamPlanManager
    @State private var currentMonth: Date = Date()
    @State private var selectedDate: Date = Date()
    
    public init(planManager: ExamPlanManager) {
        self.planManager = planManager
    }
    
    private let calendar = Calendar.current
    private let daysOfWeek = ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"]
    
    // Cached DateFormatters to prevent ICU overhead during layout
    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()
    
    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateStyle = .medium
        return formatter
    }()
    
    public var body: some View {
        VStack(spacing: 16) {
            // Month Navigation Header
            HStack {
                Button(action: {
                    changeMonth(by: -1)
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text(monthYearString(from: currentMonth))
                    .font(.system(size: 18, weight: .bold))
                    .textCase(.uppercase)
                
                Spacer()
                
                Button(action: {
                    changeMonth(by: 1)
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 4)
            
            // Weekday Headers
            HStack {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar Days Grid with Safe Stable Identifiers
            let days = generateDaysInMonth(for: currentMonth)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 8) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        DayCellView(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            plansOnDate: plansOn(date: date),
                            onTap: {
                                HapticManager.shared.light()
                                selectedDate = date
                            }
                        )
                    } else {
                        Color.clear
                            .frame(height: 48)
                    }
                }
            }
            
            Divider()
            
            // Selected Day Agenda Detail
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Agenda: \(formattedFullDate(selectedDate))")
                        .font(.system(size: 15, weight: .bold))
                    
                    Spacer()
                    
                    let count = plansOn(date: selectedDate).count
                    Text(count == 0 ? "Sin eventos" : "\(count) evento\(count > 1 ? "s" : "")")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                
                let selectedPlans = plansOn(date: selectedDate)
                if selectedPlans.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.seal")
                            .font(.system(size: 28))
                            .foregroundColor(.gray.opacity(0.4))
                        Text("No hay entregas ni exámenes programados en esta fecha.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                } else {
                    VStack(spacing: 8) {
                        ForEach(selectedPlans) { plan in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(plan.difficulty.color)
                                    .frame(width: 10, height: 10)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(plan.title)
                                        .font(.system(size: 14, weight: .bold))
                                    Text("\(plan.subject) • Examen Oficial")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text("\(plan.daysRemaining) días")
                                    .font(.system(size: 12, weight: .bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(plan.difficulty.color.opacity(0.15))
                                    .foregroundColor(plan.difficulty.color)
                                    .cornerRadius(8)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.systemGroupedBackground))
        .cornerRadius(18)
    }
    
    private func changeMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newDate
        }
    }
    
    private func monthYearString(from date: Date) -> String {
        Self.monthYearFormatter.string(from: date)
    }
    
    private func formattedFullDate(_ date: Date) -> String {
        Self.fullDateFormatter.string(from: date)
    }
    
    private func plansOn(date: Date) -> [ExamPlan] {
        planManager.plans.filter { calendar.isDate($0.examDate, inSameDayAs: date) }
    }
    
    private func generateDaysInMonth(for date: Date) -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date),
              let range = calendar.range(of: .day, in: .month, for: date) else {
            return []
        }
        let firstDay = monthInterval.start
        
        let weekday = calendar.component(.weekday, from: firstDay)
        // Convert to Monday = 0
        let offset = (weekday + 5) % 7
        
        var days: [Date?] = Array(repeating: nil, count: offset)
        
        for day in range {
            if let d = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(d)
            }
        }
        
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days
    }
}

// MARK: - Day Cell Component
struct DayCellView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let plansOnDate: [ExamPlan]
    let onTap: () -> Void
    
    private var dayNumber: String {
        let day = Calendar.current.component(.day, from: date)
        return "\(day)"
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Text(dayNumber)
                    .font(.system(size: 13, weight: isToday || isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .white : (isToday ? .orange : .primary))
                
                HStack(spacing: 3) {
                    if !plansOnDate.isEmpty {
                        ForEach(plansOnDate.prefix(3)) { plan in
                            Circle()
                                .fill(isSelected ? Color.white : plan.difficulty.color)
                                .frame(width: 5, height: 5)
                        }
                    } else {
                        Color.clear.frame(height: 5)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
                    } else if isToday {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.orange, lineWidth: 1.5)
                            .background(Color.orange.opacity(0.08).cornerRadius(12))
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}

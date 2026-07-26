import SwiftUI

struct UnifiedCalendarView: View {
    @EnvironmentObject var state: AppState
    let days: Int

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Calendrier d'adhérence")
                .font(.headline)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(dates, id: \.self) { day in
                    let summary = summaryForDay(day)
                    VStack(spacing: 2) {
                        Text(dayLabel(day))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(fillColor(summary))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(summary.hasCheckIn ? Color.blue : Color.clear, lineWidth: 1.5)
                            )
                            .overlay(alignment: .topTrailing) {
                                if summary.potentialMissedReminder {
                                    Circle()
                                        .fill(.red)
                                        .frame(width: 6, height: 6)
                                        .padding(4)
                                }
                            }
                            .frame(height: 28)
                    }
                }
            }
            legend
        }
    }

    private var dates: [Date] {
        let cal = Calendar.current
        return (0..<max(7, days))
            .compactMap { cal.date(byAdding: .day, value: -$0, to: Date()) }
            .sorted()
    }

    private func summaryForDay(_ day: Date) -> DaySummary {
        let snapshot = state.buildSnapshot()
        let daily = DailyPlanner.buildWidgetSnapshot(from: snapshot, now: day)
        let ratio = daily.progressTotal == 0 ? 0 : Double(daily.progressDone) / Double(daily.progressTotal)
        let hasCheckIn = state.dailyCheckIns.contains {
            Calendar.current.isDate($0.date, inSameDayAs: day)
        }
        let hadReminder = state.reminders.contains {
            $0.enabled && DailyPlanner.isReminderScheduledToday($0, now: day)
        }
        let potentialMissedReminder = hadReminder && ratio == 0 && !hasCheckIn
        return DaySummary(completionRatio: ratio, hasCheckIn: hasCheckIn, potentialMissedReminder: potentialMissedReminder)
    }

    private func dayLabel(_ day: Date) -> String {
        let dayNumber = Calendar.current.component(.day, from: day)
        return "\(dayNumber)"
    }

    private func fillColor(_ summary: DaySummary) -> Color {
        if summary.completionRatio >= 1 { return Color.green.opacity(0.9) }
        if summary.completionRatio >= 0.7 { return Color.green.opacity(0.7) }
        if summary.completionRatio >= 0.4 { return Color.green.opacity(0.45) }
        if summary.completionRatio > 0 { return Color.yellow.opacity(0.45) }
        return Color(UIColor.secondarySystemBackground)
    }

    private var legend: some View {
        HStack(spacing: 12) {
            legendItem(color: Color.green.opacity(0.9), label: "Fait")
            legendItem(color: Color.yellow.opacity(0.45), label: "Partiel")
            legendItem(color: Color(UIColor.secondarySystemBackground), label: "Aucune complétion")
            HStack(spacing: 4) {
                Circle().fill(.red).frame(width: 6, height: 6)
                Text("Rappel potentiellement manqué").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 10, height: 10)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct DaySummary {
    let completionRatio: Double
    let hasCheckIn: Bool
    let potentialMissedReminder: Bool
}


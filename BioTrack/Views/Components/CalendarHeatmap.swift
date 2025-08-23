import SwiftUI

struct CalendarHeatmap: View {
    let entries: [MetricEntry]
    let startDate: Date
    let endDate: Date

    var body: some View {
        GeometryReader { geo in
            let cal = Calendar.current
            let grouped = Dictionary(grouping: entries) { cal.startOfDay(for: $0.date) }
            let days: [Date] = {
                var arr: [Date] = []
                var d = cal.startOfDay(for: startDate)
                let end = cal.startOfDay(for: endDate)
                while d <= end { arr.append(d); d = cal.date(byAdding: .day, value: 1, to: d)! }
                return arr
            }()
            let columns = Int(geo.size.width / 20)
            let size: CGFloat = floor(geo.size.width / CGFloat(max(columns, 1))) - 2

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(size), spacing: 2), count: max(columns, 1)), spacing: 2) {
                ForEach(days, id: \.self) { d in
                    let count = grouped[d]?.count ?? 0
                    Rectangle()
                        .fill(color(for: count))
                        .frame(width: size, height: size)
                        .overlay(
                            Text(count > 0 ? "" : "")
                        )
                        .accessibilityLabel(Text("\(count) entrée(s) le \(DateFormatter.localizedString(from: d, dateStyle: .medium, timeStyle: .none))"))
                }
            }
        }
    }

    private func color(for count: Int) -> Color {
        switch count {
        case 0: return Color(UIColor.secondarySystemBackground)
        case 1: return .teal.opacity(0.4)
        case 2: return .teal.opacity(0.6)
        case 3: return .teal.opacity(0.8)
        default: return .teal
        }
    }
}



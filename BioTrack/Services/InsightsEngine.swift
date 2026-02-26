import Foundation

enum InsightsEngine {
    static func generateCorrelationInsights(snapshot: BioTrackSnapshot,
                                            windowDays: Int = 90,
                                            minSampleSize: Int = 8,
                                            lags: [Int] = [0, 1, 2]) -> [CorrelationInsight] {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -windowDays, to: end) ?? end
        let metrics = snapshot.metrics
        guard metrics.count >= 2 else { return [] }

        var insights: [CorrelationInsight] = []
        for i in 0..<metrics.count {
            for j in (i + 1)..<metrics.count {
                let mA = metrics[i]
                let mB = metrics[j]
                let mapA = dailyAverageMap(metricId: mA.id, entries: snapshot.metricEntries, start: start, end: end)
                let mapB = dailyAverageMap(metricId: mB.id, entries: snapshot.metricEntries, start: start, end: end)
                for lag in lags {
                    let pairs = alignedPairs(mapA: mapA, mapB: mapB, lagDays: lag)
                    guard pairs.count >= minSampleSize else { continue }
                    let xs = pairs.map { $0.0 }
                    let ys = pairs.map { $0.1 }
                    let pearsonValue = pearson(xs, ys)
                    guard !pearsonValue.isNaN else { continue }
                    let summary = summaryText(metricA: mA.name, metricB: mB.name, pearson: pearsonValue, lag: lag, sample: pairs.count)
                    insights.append(
                        CorrelationInsight(
                            metricAId: mA.id,
                            metricBId: mB.id,
                            windowDays: windowDays,
                            lagDays: lag,
                            pearson: pearsonValue,
                            sampleSize: pairs.count,
                            summary: summary
                        )
                    )
                }
            }
        }
        return insights.sorted { abs($0.pearson) > abs($1.pearson) }
    }

    static func adherenceInsights(snapshot: BioTrackSnapshot, days: Int = 14) -> [String] {
        let calendar = Calendar.current
        var lines: [String] = []
        let now = Date()
        var totalScheduled = 0
        var totalDone = 0
        var weekdayCounts: [Int: (done: Int, total: Int)] = [:]

        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            var daySnapshot = DailyPlanner.buildWidgetSnapshot(from: snapshot, now: day)
            let dayDone = daySnapshot.progressDone
            let dayTotal = daySnapshot.progressTotal
            totalDone += dayDone
            totalScheduled += dayTotal
            let wd = RoutineEngine.currentWeekdayMon1ToSun7(now: day)
            let current = weekdayCounts[wd] ?? (0, 0)
            weekdayCounts[wd] = (current.done + dayDone, current.total + dayTotal)
        }

        let rate = totalScheduled == 0 ? 0.0 : Double(totalDone) / Double(totalScheduled)
        if rate < 0.6 {
            lines.append("Votre adhérence sur \(days) jours est faible (\(Int(rate * 100))%). Réduisez la charge quotidienne.")
        } else if rate >= 0.85 {
            lines.append("Très bonne constance (\(Int(rate * 100))%). Vous pouvez augmenter légèrement vos objectifs.")
        }

        if let weakest = weekdayCounts
            .map({ (key: $0.key, value: $0.value.total == 0 ? 0.0 : Double($0.value.done) / Double($0.value.total)) })
            .min(by: { $0.value < $1.value }) {
            let labels = [1: "Lun", 2: "Mar", 3: "Mer", 4: "Jeu", 5: "Ven", 6: "Sam", 7: "Dim"]
            lines.append("Jour le plus difficile: \(labels[weakest.key] ?? "-") (\(Int(weakest.value * 100))%).")
        }
        return lines
    }

    private static func alignedPairs(mapA: [Date: Double], mapB: [Date: Double], lagDays: Int) -> [(Double, Double)] {
        let calendar = Calendar.current
        var pairs: [(Double, Double)] = []
        for (day, valueA) in mapA {
            let keyB = calendar.date(byAdding: .day, value: -lagDays, to: day) ?? day
            if let valueB = mapB[keyB] {
                pairs.append((valueA, valueB))
            }
        }
        return pairs
    }

    private static func dailyAverageMap(metricId: UUID, entries: [MetricEntry], start: Date, end: Date) -> [Date: Double] {
        let calendar = Calendar.current
        let filtered = entries.filter {
            $0.metricId == metricId &&
            $0.date >= start &&
            $0.date <= end
        }
        let grouped = Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.date) }
        var output: [Date: Double] = [:]
        for (day, items) in grouped {
            let avg = items.map(\.value).reduce(0, +) / Double(items.count)
            output[day] = avg
        }
        return output
    }

    private static func pearson(_ x: [Double], _ y: [Double]) -> Double {
        guard x.count == y.count, x.count > 1 else { return .nan }
        let n = Double(x.count)
        let sx = x.reduce(0, +)
        let sy = y.reduce(0, +)
        let sxx = x.reduce(0) { $0 + $1 * $1 }
        let syy = y.reduce(0) { $0 + $1 * $1 }
        let sxy = zip(x, y).reduce(0) { $0 + $1.0 * $1.1 }
        let num = n * sxy - sx * sy
        let denLeft = n * sxx - sx * sx
        let denRight = n * syy - sy * sy
        guard denLeft > 0, denRight > 0 else { return .nan }
        return num / sqrt(denLeft * denRight)
    }

    private static func summaryText(metricA: String, metricB: String, pearson: Double, lag: Int, sample: Int) -> String {
        let strength: String
        switch abs(pearson) {
        case ..<0.2: strength = "très faible"
        case ..<0.4: strength = "faible"
        case ..<0.6: strength = "modérée"
        case ..<0.8: strength = "forte"
        default: strength = "très forte"
        }
        let direction = pearson >= 0 ? "positive" : "négative"
        if lag == 0 {
            return "Corrélation \(strength) \(direction) entre \(metricA) et \(metricB) (\(sample) points)."
        }
        return "Corrélation \(strength) \(direction) entre \(metricA) et \(metricB) avec décalage \(lag) jour(s) (\(sample) points)."
    }
}


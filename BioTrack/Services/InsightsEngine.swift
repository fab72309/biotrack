import Foundation

enum InsightsEngine {
    private struct CorrelationCandidate {
        let metricA: Metric
        let metricB: Metric
        let lag: Int
        let estimate: CorrelationEstimate
        var adjustedPValue: Double = 1
    }

    static func generateCorrelationInsights(snapshot: BioTrackSnapshot,
                                            windowDays: Int = 90,
                                            minSampleSize: Int = 12,
                                            lags: [Int] = [-2, -1, 0, 1, 2]) -> [CorrelationInsight] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let endExclusive = calendar.date(byAdding: .day, value: 1, to: today) ?? Date()
        let start = calendar.date(byAdding: .day, value: -(max(windowDays, 1) - 1), to: today) ?? today
        let metrics = snapshot.metrics
        guard metrics.count >= 2 else { return [] }

        let dailyMaps = Dictionary(
            uniqueKeysWithValues: metrics.map { metric in
                (
                    metric.id,
                    dailyAverageMap(
                        metricId: metric.id,
                        entries: snapshot.metricEntries,
                        start: start,
                        endExclusive: endExclusive
                    )
                )
            }
        )

        var candidates: [CorrelationCandidate] = []
        for i in 0..<metrics.count {
            for j in (i + 1)..<metrics.count {
                let mA = metrics[i]
                let mB = metrics[j]
                guard let mapA = dailyMaps[mA.id],
                      let mapB = dailyMaps[mB.id] else {
                    continue
                }
                for lag in lags {
                    let pairs = alignedPairs(mapA: mapA, mapB: mapB, lagDays: lag)
                    guard pairs.count >= minSampleSize else { continue }
                    let xs = pairs.map { $0.0 }
                    let ys = pairs.map { $0.1 }
                    guard let estimate = CorrelationStatistics.estimate(x: xs, y: ys) else { continue }
                    candidates.append(CorrelationCandidate(metricA: mA, metricB: mB, lag: lag, estimate: estimate))
                }
            }
        }

        let adjusted = CorrelationStatistics.adjustedPValues(candidates.map(\.estimate.pValue))
        for index in candidates.indices {
            candidates[index].adjustedPValue = adjusted[index]
        }

        let eligible = candidates.filter { candidate in
            let estimate = candidate.estimate
            return candidate.adjustedPValue <= 0.10 &&
                abs(estimate.pearson) >= 0.30 &&
                abs(estimate.spearman) >= 0.25 &&
                estimate.effectiveSampleSize >= 8 &&
                estimate.confidenceExcludesZero &&
                estimate.rankAgreementIsAcceptable &&
                estimate.trendAgreementIsAcceptable
        }

        let grouped = Dictionary(grouping: eligible) {
            PairKey(first: $0.metricA.id, second: $0.metricB.id)
        }

        return grouped.values.compactMap { group -> CorrelationInsight? in
            guard let best = group.max(by: { evidenceScore($0) < evidenceScore($1) }) else { return nil }
            let estimate = best.estimate
            let evidence = evidenceLevel(
                effectiveSampleSize: estimate.effectiveSampleSize,
                pearson: estimate.pearson,
                spearman: estimate.spearman,
                trendAdjustedPearson: estimate.trendAdjustedPearson ?? 0,
                adjustedPValue: best.adjustedPValue
            )
            return CorrelationInsight(
                metricAId: best.metricA.id,
                metricBId: best.metricB.id,
                windowDays: windowDays,
                lagDays: best.lag,
                pearson: estimate.pearson,
                sampleSize: estimate.sampleSize,
                summary: summaryText(
                    metricA: best.metricA.name,
                    metricB: best.metricB.name,
                    pearson: estimate.pearson,
                    lag: best.lag,
                    sample: estimate.sampleSize
                ),
                spearman: estimate.spearman,
                trendAdjustedPearson: estimate.trendAdjustedPearson,
                confidenceLower: estimate.confidenceLower,
                confidenceUpper: estimate.confidenceUpper,
                adjustedPValue: best.adjustedPValue,
                effectiveSampleSize: estimate.effectiveSampleSize,
                evidence: evidence
            )
        }
        .sorted {
            let left = insightScore($0)
            let right = insightScore($1)
            if left == right { return $0.sampleSize > $1.sampleSize }
            return left > right
        }
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
            let daySnapshot = DailyPlanner.buildWidgetSnapshot(from: snapshot, now: day)
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
            lines.append("Très bonne constance (\(Int(rate * 100))%). Conservez ce rythme ou ajustez vos objectifs prudemment.")
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
        for day in mapA.keys.sorted() {
            guard let valueA = mapA[day] else { continue }
            // A positive lag means A is observed before B.
            let keyB = calendar.date(byAdding: .day, value: lagDays, to: day) ?? day
            if let valueB = mapB[keyB] {
                pairs.append((valueA, valueB))
            }
        }
        return pairs
    }

    private static func dailyAverageMap(metricId: UUID, entries: [MetricEntry], start: Date, endExclusive: Date) -> [Date: Double] {
        let calendar = Calendar.current
        let filtered = entries.filter {
            $0.metricId == metricId &&
            $0.date >= start &&
            $0.date < endExclusive &&
            $0.value.isFinite
        }
        let grouped = Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.date) }
        var output: [Date: Double] = [:]
        for (day, items) in grouped {
            let avg = items.map(\.value).reduce(0, +) / Double(items.count)
            output[day] = avg
        }
        return output
    }

    private static func summaryText(metricA: String, metricB: String, pearson: Double, lag: Int, sample: Int) -> String {
        let strength: String
        switch abs(pearson) {
        case ..<0.4: strength = "faible"
        case ..<0.6: strength = "modérée"
        case ..<0.8: strength = "forte"
        default: strength = "très forte"
        }
        let direction = pearson >= 0 ? "dans le même sens" : "en sens opposé"
        if lag == 0 {
            return "\(metricA) et \(metricB) évoluent \(direction) le même jour. Association \(strength), sur \(sample) jours alignés."
        }
        let earlierMetric = lag > 0 ? metricA : metricB
        let laterMetric = lag > 0 ? metricB : metricA
        let dayCount = abs(lag)
        let dayLabel = dayCount > 1 ? "jours" : "jour"
        return "\(earlierMetric) précède de \(dayCount) \(dayLabel) des variations \(direction) de \(laterMetric). Association \(strength), sur \(sample) jours alignés."
    }

    private static func evidenceScore(_ candidate: CorrelationCandidate) -> Double {
        let estimate = candidate.estimate
        let trendStrength = abs(estimate.trendAdjustedPearson ?? 0)
        let conservativeStrength = min(
            min(abs(estimate.pearson), abs(estimate.spearman)),
            trendStrength
        )
        let confidenceFloor = min(abs(estimate.confidenceLower), abs(estimate.confidenceUpper))
        let sampleWeight = min(1, Double(estimate.effectiveSampleSize) / 30)
        let lagPenalty = Double(abs(candidate.lag)) * 0.02
        return conservativeStrength * 0.62 + confidenceFloor * 0.28 + sampleWeight * 0.10 - lagPenalty
    }

    private static func insightScore(_ insight: CorrelationInsight) -> Double {
        let rankStrength = abs(insight.spearman ?? insight.pearson)
        let trendStrength = abs(insight.trendAdjustedPearson ?? 0)
        let conservativeStrength = min(
            min(abs(insight.pearson), rankStrength),
            trendStrength
        )
        let confidenceFloor = min(abs(insight.confidenceLower ?? 0), abs(insight.confidenceUpper ?? 0))
        return conservativeStrength * 0.7 + confidenceFloor * 0.3
    }

    private static func evidenceLevel(
        effectiveSampleSize: Int,
        pearson: Double,
        spearman: Double,
        trendAdjustedPearson: Double,
        adjustedPValue: Double
    ) -> CorrelationEvidence {
        let conservativeStrength = min(
            min(abs(pearson), abs(spearman)),
            abs(trendAdjustedPearson)
        )
        if effectiveSampleSize >= 30, conservativeStrength >= 0.50, adjustedPValue <= 0.01 {
            return .strong
        }
        if effectiveSampleSize >= 20, conservativeStrength >= 0.40, adjustedPValue <= 0.05 {
            return .moderate
        }
        return .exploratory
    }

    private struct PairKey: Hashable {
        let first: UUID
        let second: UUID
    }
}

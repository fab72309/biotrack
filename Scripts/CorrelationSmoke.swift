import Foundation

@main
enum CorrelationSmoke {
    static func main() {
        verifyCoreStatistics()
        verifyLagSelection()
        print("Correlation smoke tests passed")
    }

    private static func verifyCoreStatistics() {
        let values = [1.0, 2, 3, 4, 5, 6]
        guard let positive = CorrelationStatistics.estimate(
            x: values,
            y: values.map { $0 * 2 + 10 }
        ) else {
            fatalError("Expected a correlation estimate")
        }
        precondition(abs(positive.pearson - 1) < 0.000_001)
        precondition(abs(positive.spearman - 1) < 0.000_001)
        precondition(CorrelationStatistics.estimate(x: [2, 2, 2, 2], y: [1, 2, 3, 4]) == nil)

        let adjusted = CorrelationStatistics.adjustedPValues([0.01, 0.04, 0.03])
        precondition(abs(adjusted[0] - 0.03) < 0.000_001)
        precondition(abs(adjusted[1] - 0.04) < 0.000_001)
        precondition(abs(adjusted[2] - 0.04) < 0.000_001)
    }

    private static func verifyLagSelection() {
        let metricA = Metric(name: "Routine", kind: .number, unit: "score")
        let metricB = Metric(name: "Énergie", kind: .number, unit: "score")
        let values: [Double] = [
            2, 9, 4, 7, 1, 8, 5, 3, 10, 6, 2, 8,
            1, 7, 4, 10, 3, 6, 9, 5, 2, 7, 1, 8,
            4, 9, 3, 6, 10, 5
        ]
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        guard let firstDay = calendar.date(byAdding: .day, value: -(values.count + 2), to: today) else {
            fatalError("Unable to create test date")
        }
        var entries: [MetricEntry] = []

        for (index, value) in values.enumerated() {
            guard let predictorDate = calendar.date(byAdding: .day, value: index, to: firstDay),
                  let outcomeDate = calendar.date(byAdding: .day, value: 1, to: predictorDate) else {
                fatalError("Unable to create aligned dates")
            }
            entries.append(MetricEntry(metricId: metricA.id, date: predictorDate, value: value))
            entries.append(MetricEntry(metricId: metricB.id, date: outcomeDate, value: value * 2 + 3))
        }

        let snapshot = BioTrackSnapshot(metrics: [metricA, metricB], metricEntries: entries)
        let insights = InsightsEngine.generateCorrelationInsights(
            snapshot: snapshot,
            windowDays: 90,
            minSampleSize: 12
        )
        guard insights.count == 1, let insight = insights.first else {
            fatalError("Expected exactly one retained association")
        }
        precondition(insight.lagDays == 1)
        precondition(insight.pearson > 0.99)
        precondition((insight.spearman ?? 0) > 0.99)
        precondition(insight.summary.contains("Routine précède de 1 jour"))
    }
}

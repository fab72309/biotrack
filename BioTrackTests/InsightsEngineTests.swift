import XCTest
@testable import BioTrack

final class InsightsEngineTests: XCTestCase {
    func testEngineFindsOneBestLagAndDescribesItsDirection() throws {
        let metricA = Metric(name: "Routine", kind: .number, unit: "score")
        let metricB = Metric(name: "Énergie", kind: .number, unit: "score")
        let values: [Double] = [
            2, 9, 4, 7, 1, 8, 5, 3, 10, 6, 2, 8,
            1, 7, 4, 10, 3, 6, 9, 5, 2, 7, 1, 8,
            4, 9, 3, 6, 10, 5
        ]
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        let firstDay = try XCTUnwrap(calendar.date(byAdding: .day, value: -(values.count + 2), to: today))
        var entries: [MetricEntry] = []

        for (index, value) in values.enumerated() {
            let predictorDate = try XCTUnwrap(calendar.date(byAdding: .day, value: index, to: firstDay))
            let outcomeDate = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: predictorDate))
            entries.append(MetricEntry(metricId: metricA.id, date: predictorDate, value: value))
            entries.append(MetricEntry(metricId: metricB.id, date: outcomeDate, value: value * 2 + 3))
        }

        let snapshot = BioTrackSnapshot(metrics: [metricA, metricB], metricEntries: entries)
        let insights = InsightsEngine.generateCorrelationInsights(
            snapshot: snapshot,
            windowDays: 90,
            minSampleSize: 12
        )

        let insight = try XCTUnwrap(insights.first)
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insight.lagDays, 1)
        XCTAssertGreaterThan(insight.pearson, 0.99)
        XCTAssertGreaterThan(insight.spearman ?? 0, 0.99)
        XCTAssertTrue(insight.summary.contains("Routine précède de 1 jour"))
    }
}

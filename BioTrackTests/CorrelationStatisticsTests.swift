import XCTest
@testable import BioTrack

final class CorrelationStatisticsTests: XCTestCase {
    func testPearsonDetectsPerfectPositiveAndNegativeRelationships() throws {
        let x = [1.0, 2, 3, 4, 5, 6]
        let positive = try XCTUnwrap(CorrelationStatistics.estimate(x: x, y: x.map { $0 * 3 + 7 }))
        let negative = try XCTUnwrap(CorrelationStatistics.estimate(x: x, y: x.map { -$0 }))

        XCTAssertEqual(positive.pearson, 1, accuracy: 0.000_001)
        XCTAssertEqual(positive.spearman, 1, accuracy: 0.000_001)
        XCTAssertEqual(negative.pearson, -1, accuracy: 0.000_001)
        XCTAssertEqual(negative.spearman, -1, accuracy: 0.000_001)
    }

    func testSpearmanUsesAverageRanksForTies() throws {
        let estimate = try XCTUnwrap(
            CorrelationStatistics.estimate(
                x: [1, 1, 2, 3, 3, 4],
                y: [10, 10, 20, 30, 30, 40]
            )
        )

        XCTAssertEqual(estimate.spearman, 1, accuracy: 0.000_001)
    }

    func testConstantSeriesIsRejected() {
        XCTAssertNil(
            CorrelationStatistics.estimate(
                x: [2, 2, 2, 2, 2],
                y: [1, 2, 3, 4, 5]
            )
        )
    }

    func testBenjaminiHochbergAdjustmentIsMonotonic() {
        let adjusted = CorrelationStatistics.adjustedPValues([0.01, 0.04, 0.03])

        XCTAssertEqual(adjusted[0], 0.03, accuracy: 0.000_001)
        XCTAssertEqual(adjusted[1], 0.04, accuracy: 0.000_001)
        XCTAssertEqual(adjusted[2], 0.04, accuracy: 0.000_001)
    }

    func testLegacyInsightDecodesWithoutNewEvidenceFields() throws {
        let metricA = UUID()
        let metricB = UUID()
        let json = """
        {
          "id": "\(UUID().uuidString)",
          "metricAId": "\(metricA.uuidString)",
          "metricBId": "\(metricB.uuidString)",
          "windowDays": 90,
          "lagDays": 0,
          "pearson": 0.6,
          "sampleSize": 20,
          "summary": "Legacy"
        }
        """.data(using: .utf8)!

        let insight = try JSONDecoder().decode(CorrelationInsight.self, from: json)
        XCTAssertNil(insight.spearman)
        XCTAssertNil(insight.confidenceLower)
        XCTAssertNil(insight.adjustedPValue)
        XCTAssertNil(insight.evidence)
    }
}

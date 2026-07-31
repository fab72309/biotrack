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

    func testEffectiveSampleSizePenalizesAutocorrelatedSeries() throws {
        let x = (0..<40).map { index in
            Double(index) * 0.08 + sin(Double(index) / 8)
        }
        let y = x.enumerated().map { index, value in
            value * 1.8 + cos(Double(index) / 6) * 0.05
        }

        let estimate = try XCTUnwrap(CorrelationStatistics.estimate(x: x, y: y))

        XCTAssertLessThan(estimate.effectiveSampleSize, estimate.sampleSize)
        XCTAssertGreaterThanOrEqual(estimate.effectiveSampleSize, 4)
    }

    func testTrendAdjustedCorrelationRejectsPureSharedLinearTrend() throws {
        let x = (0..<20).map(Double.init)
        let y = x.map { $0 * 4 + 12 }

        let estimate = try XCTUnwrap(CorrelationStatistics.estimate(x: x, y: y))

        XCTAssertNil(estimate.trendAdjustedPearson)
        XCTAssertFalse(estimate.trendAgreementIsAcceptable)
    }

    func testRobustStandardScoresCenterAndLimitTheDisplay() {
        let scores = CorrelationStatistics.robustStandardScores([1, 2, 3, 4, 100])

        XCTAssertEqual(scores.count, 5)
        XCTAssertEqual(scores[2], 0, accuracy: 0.000_001)
        XCTAssertEqual(scores[4], 3, accuracy: 0.000_001)
        XCTAssertEqual(scores[1], -scores[3], accuracy: 0.000_001)
        XCTAssertLessThan(scores[0], scores[1])
        XCTAssertEqual(
            CorrelationStatistics.robustStandardScores([5, 5, 5]),
            [0, 0, 0]
        )
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
        XCTAssertNil(insight.trendAdjustedPearson)
        XCTAssertNil(insight.confidenceLower)
        XCTAssertNil(insight.adjustedPValue)
        XCTAssertNil(insight.effectiveSampleSize)
        XCTAssertNil(insight.evidence)
    }
}

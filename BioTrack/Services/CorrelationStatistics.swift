import Foundation

struct CorrelationEstimate {
    let pearson: Double
    let spearman: Double
    let confidenceLower: Double
    let confidenceUpper: Double
    let pValue: Double
    let sampleSize: Int

    var confidenceExcludesZero: Bool {
        confidenceLower > 0 || confidenceUpper < 0
    }

    var rankAgreementIsAcceptable: Bool {
        pearson.sign == spearman.sign && abs(pearson - spearman) <= 0.25
    }
}

enum CorrelationStatistics {
    static func estimate(x: [Double], y: [Double]) -> CorrelationEstimate? {
        guard x.count == y.count, x.count >= 4 else { return nil }
        guard x.allSatisfy(\.isFinite), y.allSatisfy(\.isFinite) else { return nil }
        guard let pearsonValue = pearson(x, y),
              let spearmanValue = spearman(x, y) else {
            return nil
        }

        let interval = fisherConfidenceInterval(correlation: pearsonValue, sampleSize: x.count)
        return CorrelationEstimate(
            pearson: pearsonValue,
            spearman: spearmanValue,
            confidenceLower: interval.lower,
            confidenceUpper: interval.upper,
            pValue: twoSidedPValue(correlation: pearsonValue, sampleSize: x.count),
            sampleSize: x.count
        )
    }

    static func pearson(_ x: [Double], _ y: [Double]) -> Double? {
        guard x.count == y.count, x.count > 1 else { return nil }
        let count = Double(x.count)
        let meanX = x.reduce(0, +) / count
        let meanY = y.reduce(0, +) / count

        var covariance = 0.0
        var varianceX = 0.0
        var varianceY = 0.0
        for (valueX, valueY) in zip(x, y) {
            let centeredX = valueX - meanX
            let centeredY = valueY - meanY
            covariance += centeredX * centeredY
            varianceX += centeredX * centeredX
            varianceY += centeredY * centeredY
        }

        guard varianceX > .ulpOfOne, varianceY > .ulpOfOne else { return nil }
        let value = covariance / sqrt(varianceX * varianceY)
        guard value.isFinite else { return nil }
        return min(1, max(-1, value))
    }

    static func spearman(_ x: [Double], _ y: [Double]) -> Double? {
        guard x.count == y.count, x.count > 1 else { return nil }
        return pearson(averageRanks(x), averageRanks(y))
    }

    static func adjustedPValues(_ pValues: [Double]) -> [Double] {
        guard !pValues.isEmpty else { return [] }
        let sorted = pValues.enumerated().sorted {
            if $0.element == $1.element { return $0.offset < $1.offset }
            return $0.element < $1.element
        }
        let count = Double(pValues.count)
        var adjusted = Array(repeating: 1.0, count: pValues.count)
        var runningMinimum = 1.0

        for position in stride(from: sorted.count - 1, through: 0, by: -1) {
            let original = sorted[position]
            let rank = Double(position + 1)
            let candidate = min(1, max(0, original.element) * count / rank)
            runningMinimum = min(runningMinimum, candidate)
            adjusted[original.offset] = runningMinimum
        }
        return adjusted
    }

    private static func averageRanks(_ values: [Double]) -> [Double] {
        let sorted = values.enumerated().sorted {
            if $0.element == $1.element { return $0.offset < $1.offset }
            return $0.element < $1.element
        }
        var ranks = Array(repeating: 0.0, count: values.count)
        var start = 0

        while start < sorted.count {
            var end = start
            while end + 1 < sorted.count, sorted[end + 1].element == sorted[start].element {
                end += 1
            }
            let averageRank = (Double(start + 1) + Double(end + 1)) / 2
            for index in start...end {
                ranks[sorted[index].offset] = averageRank
            }
            start = end + 1
        }
        return ranks
    }

    private static func fisherConfidenceInterval(
        correlation: Double,
        sampleSize: Int,
        zCritical: Double = 1.959_963_984_540_054
    ) -> (lower: Double, upper: Double) {
        guard sampleSize > 3 else { return (-1, 1) }
        let clamped = min(0.999_999, max(-0.999_999, correlation))
        let fisherZ = 0.5 * log((1 + clamped) / (1 - clamped))
        let margin = zCritical / sqrt(Double(sampleSize - 3))
        return (tanh(fisherZ - margin), tanh(fisherZ + margin))
    }

    private static func twoSidedPValue(correlation: Double, sampleSize: Int) -> Double {
        guard sampleSize > 3 else { return 1 }
        let clamped = min(0.999_999, max(-0.999_999, correlation))
        let fisherZ = abs(0.5 * log((1 + clamped) / (1 - clamped))) * sqrt(Double(sampleSize - 3))
        return min(1, max(0, complementaryErrorFunction(fisherZ / sqrt(2))))
    }

    // Stable approximation of erfc for non-negative inputs (Numerical Recipes).
    private static func complementaryErrorFunction(_ value: Double) -> Double {
        let z = abs(value)
        let t = 1 / (1 + 0.5 * z)
        let polynomial = t * exp(
            -z * z - 1.265_512_23 +
            t * (1.000_023_68 +
            t * (0.374_091_96 +
            t * (0.096_784_18 +
            t * (-0.186_288_06 +
            t * (0.278_868_07 +
            t * (-1.135_203_98 +
            t * (1.488_515_87 +
            t * (-0.822_152_23 +
            t * 0.170_872_77))))))))
        )
        return value >= 0 ? polynomial : 2 - polynomial
    }
}

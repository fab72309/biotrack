import Foundation

public struct AdaptiveGoalPolicy: Codable, Equatable {
    public var enabled: Bool = false
    public var aggressiveness: Double = 0.15
    public var minDailyTarget: Int = 1
    public var maxDailyTarget: Int = 20
    public var lastAppliedAt: Date? = nil

    public init(enabled: Bool = false,
                aggressiveness: Double = 0.15,
                minDailyTarget: Int = 1,
                maxDailyTarget: Int = 20,
                lastAppliedAt: Date? = nil) {
        self.enabled = enabled
        self.aggressiveness = aggressiveness
        self.minDailyTarget = minDailyTarget
        self.maxDailyTarget = maxDailyTarget
        self.lastAppliedAt = lastAppliedAt
    }
}

public struct CorrelationInsight: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var metricAId: UUID
    public var metricBId: UUID
    public var windowDays: Int
    public var lagDays: Int
    public var pearson: Double
    public var sampleSize: Int
    public var summary: String
}

public enum RecommendationPriority: String, Codable, CaseIterable, Identifiable {
    case low
    case medium
    case high

    public var id: String { rawValue }
}

public struct RecommendationItem: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var title: String
    public var message: String
    public var actionDeepLink: String?
    public var priority: RecommendationPriority
    public var reason: String
    public var createdAt: Date = Date()
}


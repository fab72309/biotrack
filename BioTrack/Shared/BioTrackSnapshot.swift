import Foundation

public struct BioTrackSnapshot: Codable {
    public var schemaVersion: Int = 3
    public var protocols: [ProtocolItem] = []
    public var customProtocolTemplates: [CustomProtocolTemplate] = []
    public var protocolCompletions: [ProtocolCompletion] = []
    public var supplements: [Supplement] = []
    public var customSupplementTemplates: [CustomSupplementTemplate] = []
    public var supplementIntakes: [SupplementIntake] = []
    public var metrics: [Metric] = []
    public var metricEntries: [MetricEntry] = []
    public var reminders: [Reminder] = []
    public var dailyCheckIns: [DailyCheckIn] = []
    public var routineProfiles: [RoutineProfile] = []
    public var activeRoutineProfileKindRaw: String? = nil
    public var experiments: [NOf1Experiment] = []
    public var experimentObservations: [NOf1Observation] = []
    public var adaptiveGoalPolicy: AdaptiveGoalPolicy = AdaptiveGoalPolicy()
    public var correlationInsights: [CorrelationInsight] = []
    public var recommendations: [RecommendationItem] = []

    public init(schemaVersion: Int = 3,
                protocols: [ProtocolItem] = [],
                customProtocolTemplates: [CustomProtocolTemplate] = [],
                protocolCompletions: [ProtocolCompletion] = [],
                supplements: [Supplement] = [],
                customSupplementTemplates: [CustomSupplementTemplate] = [],
                supplementIntakes: [SupplementIntake] = [],
                metrics: [Metric] = [],
                metricEntries: [MetricEntry] = [],
                reminders: [Reminder] = [],
                dailyCheckIns: [DailyCheckIn] = [],
                routineProfiles: [RoutineProfile] = [],
                activeRoutineProfileKindRaw: String? = nil,
                experiments: [NOf1Experiment] = [],
                experimentObservations: [NOf1Observation] = [],
                adaptiveGoalPolicy: AdaptiveGoalPolicy = AdaptiveGoalPolicy(),
                correlationInsights: [CorrelationInsight] = [],
                recommendations: [RecommendationItem] = []) {
        self.schemaVersion = schemaVersion
        self.protocols = protocols
        self.customProtocolTemplates = customProtocolTemplates
        self.protocolCompletions = protocolCompletions
        self.supplements = supplements
        self.customSupplementTemplates = customSupplementTemplates
        self.supplementIntakes = supplementIntakes
        self.metrics = metrics
        self.metricEntries = metricEntries
        self.reminders = reminders
        self.dailyCheckIns = dailyCheckIns
        self.routineProfiles = routineProfiles
        self.activeRoutineProfileKindRaw = activeRoutineProfileKindRaw
        self.experiments = experiments
        self.experimentObservations = experimentObservations
        self.adaptiveGoalPolicy = adaptiveGoalPolicy
        self.correlationInsights = correlationInsights
        self.recommendations = recommendations
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case protocols
        case customProtocolTemplates
        case protocolCompletions
        case supplements
        case customSupplementTemplates
        case supplementIntakes
        case metrics
        case metricEntries
        case reminders
        case dailyCheckIns
        case routineProfiles
        case activeRoutineProfileKindRaw
        case experiments
        case experimentObservations
        case adaptiveGoalPolicy
        case correlationInsights
        case recommendations
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        protocols = try container.decodeIfPresent([ProtocolItem].self, forKey: .protocols) ?? []
        customProtocolTemplates = try container.decodeIfPresent([CustomProtocolTemplate].self, forKey: .customProtocolTemplates) ?? []
        protocolCompletions = try container.decodeIfPresent([ProtocolCompletion].self, forKey: .protocolCompletions) ?? []
        supplements = try container.decodeIfPresent([Supplement].self, forKey: .supplements) ?? []
        customSupplementTemplates = try container.decodeIfPresent([CustomSupplementTemplate].self, forKey: .customSupplementTemplates) ?? []
        supplementIntakes = try container.decodeIfPresent([SupplementIntake].self, forKey: .supplementIntakes) ?? []
        metrics = try container.decodeIfPresent([Metric].self, forKey: .metrics) ?? []
        metricEntries = try container.decodeIfPresent([MetricEntry].self, forKey: .metricEntries) ?? []
        reminders = try container.decodeIfPresent([Reminder].self, forKey: .reminders) ?? []
        dailyCheckIns = try container.decodeIfPresent([DailyCheckIn].self, forKey: .dailyCheckIns) ?? []
        routineProfiles = try container.decodeIfPresent([RoutineProfile].self, forKey: .routineProfiles) ?? []
        activeRoutineProfileKindRaw = try container.decodeIfPresent(String.self, forKey: .activeRoutineProfileKindRaw)
        experiments = try container.decodeIfPresent([NOf1Experiment].self, forKey: .experiments) ?? []
        experimentObservations = try container.decodeIfPresent([NOf1Observation].self, forKey: .experimentObservations) ?? []
        adaptiveGoalPolicy = try container.decodeIfPresent(AdaptiveGoalPolicy.self, forKey: .adaptiveGoalPolicy) ?? AdaptiveGoalPolicy()
        correlationInsights = try container.decodeIfPresent([CorrelationInsight].self, forKey: .correlationInsights) ?? []
        recommendations = try container.decodeIfPresent([RecommendationItem].self, forKey: .recommendations) ?? []
    }
}

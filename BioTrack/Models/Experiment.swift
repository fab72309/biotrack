import Foundation

public enum NOf1ExperimentStatus: String, Codable, CaseIterable, Identifiable {
    case draft
    case active
    case completed
    case paused

    public var id: String { rawValue }
}

public enum NOf1Phase: String, Codable, CaseIterable, Identifiable {
    case baselineA
    case interventionB
    case washout

    public var id: String { rawValue }
}

public struct NOf1Experiment: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var title: String
    public var hypothesis: String
    public var targetMetricId: UUID
    public var startDate: Date
    public var durationDays: Int
    public var phaseDurationDays: Int
    public var status: NOf1ExperimentStatus
    public var controlLabel: String
    public var interventionLabel: String
}

public struct NOf1Observation: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var experimentId: UUID
    public var date: Date
    public var phase: NOf1Phase
    public var value: Double
    public var notes: String?
}


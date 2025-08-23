import Foundation

public enum MetricKind: String, Codable, Hashable {
    case number // generic numeric (e.g., stress 0-10)
    case hoursMinutes // sleep duration
}

public struct Metric: Identifiable, Codable, Equatable, Hashable {
    public var id: UUID = UUID()
    public var name: String
    public var kind: MetricKind
    public var unit: String? // e.g., "1-10", "kg", "h"
    public var description: String? = nil
}

public struct MetricEntry: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var metricId: UUID
    public var date: Date
    public var value: Double // minutes for hoursMinutes; or raw value
    public var notes: String? = nil
}

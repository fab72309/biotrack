import Foundation

public enum Frequency: Codable, Equatable {
    case daily
    case weekly(days: [Int]) // 1=Mon ... 7=Sun
    case timesPerDay(Int)
}

public struct ProtocolItem: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var name: String
    public var detail: String?
    public var goal: String? = nil
    public var intervention: String? = nil
    public var frequency: Frequency
    public var preferredHour: DateComponents? // e.g. 7:00
    public var targetMinutes: Int?
    public var notes: String?
    public var remindersEnabled: Bool = false
    public var isArchived: Bool = false
    public var startDate: Date = Date()
    public var endDate: Date? = nil
    public var active: Bool = true
    public var activationSpans: [ActivationSpan] = []
    // Nouvelle propriété pour classer les protocoles
    public var category: String? = nil
}

public struct ProtocolCompletion: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var protocolId: UUID
    public var date: Date
    public var completed: Bool
}

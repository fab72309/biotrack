import Foundation

public enum RoutineProfileKind: String, Codable, CaseIterable, Identifiable {
    case weekday
    case weekend
    case travel

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .weekday: return "Semaine"
        case .weekend: return "Weekend"
        case .travel: return "Voyage"
        }
    }
}

public struct RoutineProfile: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var kind: RoutineProfileKind
    public var name: String
    // 1 = Monday ... 7 = Sunday
    public var weekdays: [Int]
    public var disabledProtocolIds: [UUID]
    public var disabledSupplementIds: [UUID]
    public var disabledReminderIds: [UUID]
}


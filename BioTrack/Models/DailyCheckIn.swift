import Foundation

public enum CheckInPeriod: String, Codable, CaseIterable, Identifiable {
    case morning
    case evening

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .morning: return "Matin"
        case .evening: return "Soir"
        }
    }
}

public struct DailyCheckIn: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var date: Date
    public var period: CheckInPeriod
    public var energy: Int // 1...10
    public var mood: Int // 1...10
    public var sleepQuality: Int? // 1...10 (matin)
    public var stress: Int? // 1...10 (soir)
    public var note: String?
}


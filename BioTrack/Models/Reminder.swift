import Foundation

public struct Reminder: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var notificationBaseId: String
    public var title: String
    public var hour: Int
    public var minute: Int
    // 1 = Sunday ... 7 = Saturday (UNCalendarNotificationTrigger convention)
    public var weekdays: [Int] // empty = every day
    public var notes: String?
    public var enabled: Bool = true

    public init(id: UUID = UUID(),
                notificationBaseId: String? = nil,
                title: String,
                hour: Int,
                minute: Int,
                weekdays: [Int],
                notes: String? = nil,
                enabled: Bool = true) {
        self.id = id
        self.notificationBaseId = notificationBaseId ?? "reminder-\(id.uuidString)"
        self.title = title
        self.hour = hour
        self.minute = minute
        self.weekdays = weekdays
        self.notes = notes
        self.enabled = enabled
    }

    enum CodingKeys: String, CodingKey {
        case id
        case notificationBaseId
        case title
        case hour
        case minute
        case weekdays
        case notes
        case enabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        notificationBaseId = try container.decodeIfPresent(String.self, forKey: .notificationBaseId) ?? "reminder-\(id.uuidString)"
        title = try container.decode(String.self, forKey: .title)
        hour = try container.decode(Int.self, forKey: .hour)
        minute = try container.decode(Int.self, forKey: .minute)
        weekdays = try container.decode([Int].self, forKey: .weekdays)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
    }
}


import Foundation

public struct Reminder: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var title: String
    public var hour: Int
    public var minute: Int
    // 1 = Sunday ... 7 = Saturday (UNCalendarNotificationTrigger convention)
    public var weekdays: [Int] // empty = every day
    public var notes: String?
    public var enabled: Bool = true
}



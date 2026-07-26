import Foundation

enum WidgetPriorityKind: String, Codable {
    case protocolItem = "protocol"
    case supplement = "supplement"
}

struct WidgetPriorityItem: Identifiable, Codable {
    let itemId: UUID
    let kind: WidgetPriorityKind
    let title: String
    let isDone: Bool
    let subtitle: String?
    let preferredMinutes: Int?

    var id: String {
        "\(kind.rawValue)-\(itemId.uuidString)"
    }
}

struct WidgetReminderItem: Identifiable, Codable {
    let reminderId: UUID
    let title: String
    let hour: Int
    let minute: Int
    let enabled: Bool

    var id: String { reminderId.uuidString }
}

struct WidgetDailySnapshot: Codable {
    let date: Date
    let progressDone: Int
    let progressTotal: Int
    let priorityItems: [WidgetPriorityItem]
    let upcomingReminders: [WidgetReminderItem]
    let routineProfileName: String?
    let recommendations: [String]

    static let empty = WidgetDailySnapshot(
        date: Date(),
        progressDone: 0,
        progressTotal: 0,
        priorityItems: [],
        upcomingReminders: [],
        routineProfileName: nil,
        recommendations: []
    )
}

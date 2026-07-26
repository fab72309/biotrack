import AppIntents
import Foundation

struct ToggleProtocolCompletionIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Protocol Completion"

    @Parameter(title: "Protocol ID")
    var protocolId: String

    init() {}

    init(protocolId: String) {
        self.protocolId = protocolId
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: protocolId) else {
            WidgetEventLogger.log("widget_action_protocol_toggle", metadata: ["success": "false", "reason": "invalid_id"])
            return .result()
        }
        var found = false
        SharedStore.mutate { snapshot in
            guard snapshot.protocols.contains(where: { $0.id == id }) else { return }
            found = true
            DailyPlanner.toggleProtocolCompletion(protocolId: id, in: &snapshot, now: Date())
        }
        WidgetEventLogger.log(
            "widget_action_protocol_toggle",
            metadata: ["success": found ? "true" : "false", "reason": found ? "ok" : "not_found"]
        )
        WidgetRefresh.reloadAll()
        return .result()
    }
}

struct ToggleSupplementIntakeIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Supplement Intake"

    @Parameter(title: "Supplement ID")
    var supplementId: String

    init() {}

    init(supplementId: String) {
        self.supplementId = supplementId
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: supplementId) else {
            WidgetEventLogger.log("widget_action_supplement_toggle", metadata: ["success": "false", "reason": "invalid_id"])
            return .result()
        }
        var found = false
        SharedStore.mutate { snapshot in
            guard snapshot.supplements.contains(where: { $0.id == id }) else { return }
            found = true
            DailyPlanner.toggleSupplementIntake(supplementId: id, in: &snapshot, now: Date())
        }
        WidgetEventLogger.log(
            "widget_action_supplement_toggle",
            metadata: ["success": found ? "true" : "false", "reason": found ? "ok" : "not_found"]
        )
        WidgetRefresh.reloadAll()
        return .result()
    }
}

struct ToggleReminderEnabledIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Reminder Enabled"

    @Parameter(title: "Reminder ID")
    var reminderId: String

    init() {}

    init(reminderId: String) {
        self.reminderId = reminderId
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: reminderId) else {
            WidgetEventLogger.log("widget_action_reminder_toggle", metadata: ["success": "false", "reason": "invalid_id"])
            return .result()
        }
        var updatedReminder: Reminder?
        SharedStore.mutate { snapshot in
            guard let idx = snapshot.reminders.firstIndex(where: { $0.id == id }) else { return }
            DailyPlanner.toggleReminder(reminderId: id, in: &snapshot)
            updatedReminder = snapshot.reminders[idx]
        }
        if let reminder = updatedReminder {
            if reminder.enabled {
                ReminderNotificationScheduler.scheduleReminder(reminder)
            } else {
                ReminderNotificationScheduler.cancelReminder(baseId: reminder.notificationBaseId)
            }
        }
        WidgetEventLogger.log(
            "widget_action_reminder_toggle",
            metadata: ["success": updatedReminder == nil ? "false" : "true", "reason": updatedReminder == nil ? "not_found" : "ok"]
        )
        WidgetRefresh.reloadAll()
        return .result()
    }
}

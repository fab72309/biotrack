import Foundation
import UserNotifications

enum ReminderNotificationScheduler {
    static let reminderCategoryId = "BIOTRACK_REMINDER_CATEGORY"

    static func scheduleReminder(_ reminder: Reminder) {
        cancelReminder(baseId: reminder.notificationBaseId) {
            guard reminder.enabled else { return }
            if reminder.weekdays.isEmpty {
                scheduleDailyReminder(
                    id: "\(reminder.notificationBaseId)-daily",
                    title: reminder.title,
                    hour: reminder.hour,
                    minute: reminder.minute,
                    baseId: reminder.notificationBaseId
                )
            } else {
                for day in reminder.weekdays {
                    scheduleWeeklyReminder(
                        id: "\(reminder.notificationBaseId)-w\(day)",
                        title: reminder.title,
                        hour: reminder.hour,
                        minute: reminder.minute,
                        weekday: day,
                        baseId: reminder.notificationBaseId
                    )
                }
            }
        }
    }

    static func cancelReminder(baseId: String) {
        cancelReminder(baseId: baseId, completion: nil)
    }

    private static func cancelReminder(baseId: String, completion: (() -> Void)?) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(baseId) }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
            }
            completion?()
        }
    }

    private static func scheduleDailyReminder(id: String, title: String, hour: Int, minute: Int, baseId: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.sound = .default
        content.categoryIdentifier = reminderCategoryId
        content.userInfo = [
            "reminderBaseId": baseId,
            "reminderTitle": title
        ]
        var date = DateComponents()
        date.hour = hour
        date.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private static func scheduleWeeklyReminder(id: String, title: String, hour: Int, minute: Int, weekday: Int, baseId: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.sound = .default
        content.categoryIdentifier = reminderCategoryId
        content.userInfo = [
            "reminderBaseId": baseId,
            "reminderTitle": title
        ]
        var date = DateComponents()
        date.weekday = weekday
        date.hour = hour
        date.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}

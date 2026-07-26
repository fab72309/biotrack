import Foundation

enum SnapshotSchemaVersion {
    static let v1 = 1
    static let v2 = 2
    static let v3 = 3
    static let current = v3
}

enum MigrationService {
    static func migrate(_ snapshot: inout BioTrackSnapshot) {
        if snapshot.schemaVersion < SnapshotSchemaVersion.v2 {
            migrateV1toV2(&snapshot)
        }
        if snapshot.schemaVersion < SnapshotSchemaVersion.v3 {
            migrateV2toV3(&snapshot)
        }
        snapshot.schemaVersion = SnapshotSchemaVersion.current
    }

    private static func migrateV1toV2(_ snapshot: inout BioTrackSnapshot) {
        snapshot.reminders = snapshot.reminders.map { reminder in
            var value = reminder
            if value.notificationBaseId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                value.notificationBaseId = "reminder-\(value.id.uuidString)"
            }
            return value
        }
        if snapshot.routineProfiles.isEmpty {
            snapshot.routineProfiles = defaultRoutineProfiles()
        }
        if snapshot.activeRoutineProfileKindRaw == nil {
            snapshot.activeRoutineProfileKindRaw = RoutineProfileKind.weekday.rawValue
        }
        snapshot.schemaVersion = SnapshotSchemaVersion.v2
    }

    private static func migrateV2toV3(_ snapshot: inout BioTrackSnapshot) {
        if snapshot.adaptiveGoalPolicy.minDailyTarget <= 0 {
            snapshot.adaptiveGoalPolicy.minDailyTarget = 1
        }
        if snapshot.adaptiveGoalPolicy.maxDailyTarget < snapshot.adaptiveGoalPolicy.minDailyTarget {
            snapshot.adaptiveGoalPolicy.maxDailyTarget = snapshot.adaptiveGoalPolicy.minDailyTarget
        }
        if snapshot.routineProfiles.isEmpty {
            snapshot.routineProfiles = defaultRoutineProfiles()
        }
        snapshot.schemaVersion = SnapshotSchemaVersion.v3
    }

    static func defaultRoutineProfiles() -> [RoutineProfile] {
        [
            RoutineProfile(
                kind: .weekday,
                name: "Semaine",
                weekdays: [1, 2, 3, 4, 5],
                disabledProtocolIds: [],
                disabledSupplementIds: [],
                disabledReminderIds: []
            ),
            RoutineProfile(
                kind: .weekend,
                name: "Weekend",
                weekdays: [6, 7],
                disabledProtocolIds: [],
                disabledSupplementIds: [],
                disabledReminderIds: []
            ),
            RoutineProfile(
                kind: .travel,
                name: "Voyage",
                weekdays: [1, 2, 3, 4, 5, 6, 7],
                disabledProtocolIds: [],
                disabledSupplementIds: [],
                disabledReminderIds: []
            )
        ]
    }
}


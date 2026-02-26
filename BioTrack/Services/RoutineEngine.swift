import Foundation

enum RoutineEngine {
    static func currentWeekdayMon1ToSun7(now: Date = Date()) -> Int {
        let weekday = Calendar.current.component(.weekday, from: now)
        return ((weekday + 5) % 7) + 1
    }

    static func inferredKind(now: Date = Date()) -> RoutineProfileKind {
        let weekday = currentWeekdayMon1ToSun7(now: now)
        return (weekday == 6 || weekday == 7) ? .weekend : .weekday
    }

    static func activeProfile(snapshot: BioTrackSnapshot, now: Date = Date()) -> RoutineProfile? {
        let kind = activeKind(snapshot: snapshot, now: now)
        return snapshot.routineProfiles.first(where: { $0.kind == kind })
    }

    static func activeKind(snapshot: BioTrackSnapshot, now: Date = Date()) -> RoutineProfileKind {
        if let raw = snapshot.activeRoutineProfileKindRaw,
           let explicit = RoutineProfileKind(rawValue: raw) {
            return explicit
        }
        return inferredKind(now: now)
    }

    static func applyProfileFilters(to protocols: [ProtocolItem], profile: RoutineProfile?) -> [ProtocolItem] {
        guard let profile else { return protocols }
        let excluded = Set(profile.disabledProtocolIds)
        return protocols.filter { !excluded.contains($0.id) }
    }

    static func applyProfileFilters(to supplements: [Supplement], profile: RoutineProfile?) -> [Supplement] {
        guard let profile else { return supplements }
        let excluded = Set(profile.disabledSupplementIds)
        return supplements.filter { !excluded.contains($0.id) }
    }

    static func applyProfileFilters(to reminders: [Reminder], profile: RoutineProfile?) -> [Reminder] {
        guard let profile else { return reminders }
        let excluded = Set(profile.disabledReminderIds)
        return reminders.filter { !excluded.contains($0.id) }
    }
}


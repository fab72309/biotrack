import Foundation

struct StreakSummary {
    let global: Int
    let protocolStreaks: [UUID: Int]
    let supplementStreaks: [UUID: Int]
}

enum StreakEngine {
    static func buildSummary(snapshot: BioTrackSnapshot, now: Date = Date()) -> StreakSummary {
        let protocolMap = Dictionary(uniqueKeysWithValues: snapshot.protocols.map { ($0.id, streakForProtocol($0.id, snapshot: snapshot, now: now)) })
        let supplementMap = Dictionary(uniqueKeysWithValues: snapshot.supplements.map { ($0.id, streakForSupplement($0.id, snapshot: snapshot, now: now)) })
        return StreakSummary(
            global: globalStreak(snapshot: snapshot, now: now),
            protocolStreaks: protocolMap,
            supplementStreaks: supplementMap
        )
    }

    static func globalStreak(snapshot: BioTrackSnapshot, now: Date = Date()) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var current = calendar.startOfDay(for: now)
        while true {
            let doneProtocols = Set(snapshot.protocolCompletions.filter {
                calendar.isDate($0.date, inSameDayAs: current) && $0.completed
            }.map { $0.protocolId }).count
            let doneSupplements = Set(snapshot.supplementIntakes.filter {
                calendar.isDate($0.date, inSameDayAs: current) && $0.taken
            }.map { $0.supplementId }).count
            let done = doneProtocols + doneSupplements
            if done <= 0 { break }
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: current) else { break }
            current = previous
        }
        return streak
    }

    static func perfectCompletionStreak(snapshot: BioTrackSnapshot, now: Date = Date()) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var current = calendar.startOfDay(for: now)

        while true {
            let profile = DailyPlanner.activeProfile(snapshot: snapshot, now: current)
            let protocols = DailyPlanner.applyProfileFilters(
                to: DailyPlanner.protocolsScheduledToday(from: snapshot, now: current),
                profile: profile
            )
            let supplements = DailyPlanner.applyProfileFilters(
                to: DailyPlanner.supplementsScheduledToday(from: snapshot, now: current),
                profile: profile
            )

            let protocolIds = Set(protocols.map(\.id))
            let supplementIds = Set(supplements.map(\.id))
            let total = protocolIds.count + supplementIds.count

            // A "perfect day" only counts when at least one objective was planned and all were done.
            guard total > 0 else { break }

            let doneProtocols = Set(snapshot.protocolCompletions.filter {
                protocolIds.contains($0.protocolId)
                    && Calendar.current.isDate($0.date, inSameDayAs: current)
                    && $0.completed
            }.map(\.protocolId)).count

            let doneSupplements = Set(snapshot.supplementIntakes.filter {
                supplementIds.contains($0.supplementId)
                    && Calendar.current.isDate($0.date, inSameDayAs: current)
                    && $0.taken
            }.map(\.supplementId)).count

            guard doneProtocols + doneSupplements == total else { break }

            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: current) else { break }
            current = previous
        }

        return streak
    }

    static func streakForProtocol(_ id: UUID, snapshot: BioTrackSnapshot, now: Date = Date()) -> Int {
        streakCount(now: now) { date in
            snapshot.protocolCompletions.contains {
                $0.protocolId == id && Calendar.current.isDate($0.date, inSameDayAs: date) && $0.completed
            }
        }
    }

    static func streakForSupplement(_ id: UUID, snapshot: BioTrackSnapshot, now: Date = Date()) -> Int {
        streakCount(now: now) { date in
            snapshot.supplementIntakes.contains {
                $0.supplementId == id && Calendar.current.isDate($0.date, inSameDayAs: date) && $0.taken
            }
        }
    }

    private static func streakCount(now: Date, predicate: (Date) -> Bool) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var cursor = calendar.startOfDay(for: now)
        while predicate(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }
}

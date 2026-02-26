import Foundation

enum RecommendationEngine {
    static func buildRecommendations(snapshot: BioTrackSnapshot,
                                     now: Date = Date(),
                                     limit: Int = 8) -> [RecommendationItem] {
        var items: [RecommendationItem] = []
        let todaySnapshot = DailyPlanner.buildWidgetSnapshot(from: snapshot, now: now)
        let pendingCount = max(0, todaySnapshot.progressTotal - todaySnapshot.progressDone)

        if missingCheckIn(for: .morning, on: now, checkIns: snapshot.dailyCheckIns),
           Calendar.current.component(.hour, from: now) <= 14 {
            items.append(
                RecommendationItem(
                    title: "Check-in du matin",
                    message: "Complétez votre check-in du matin pour calibrer votre journée.",
                    actionDeepLink: "biotrack://home",
                    priority: .high,
                    reason: "checkin_missing_morning"
                )
            )
        }

        if missingCheckIn(for: .evening, on: now, checkIns: snapshot.dailyCheckIns),
           Calendar.current.component(.hour, from: now) >= 18 {
            items.append(
                RecommendationItem(
                    title: "Check-in du soir",
                    message: "Terminez la journée avec votre check-in pour améliorer vos insights.",
                    actionDeepLink: "biotrack://home",
                    priority: .medium,
                    reason: "checkin_missing_evening"
                )
            )
        }

        if pendingCount > 0 {
            items.append(
                RecommendationItem(
                    title: "Priorités du jour",
                    message: "Il reste \(pendingCount) objectif(s) à compléter aujourd'hui.",
                    actionDeepLink: "biotrack://home",
                    priority: pendingCount >= 4 ? .high : .medium,
                    reason: "daily_pending"
                )
            )
        }

        let streak = StreakEngine.globalStreak(snapshot: snapshot, now: now)
        if streak >= 7 {
            items.append(
                RecommendationItem(
                    title: "Série solide",
                    message: "Vous êtes à \(streak) jours de constance. Gardez le rythme.",
                    actionDeepLink: nil,
                    priority: .low,
                    reason: "streak_positive"
                )
            )
        } else if streak <= 1 {
            items.append(
                RecommendationItem(
                    title: "Relance de constance",
                    message: "Choisissez 1 protocole clé pour reconstruire votre série.",
                    actionDeepLink: "biotrack://protocols",
                    priority: .medium,
                    reason: "streak_low"
                )
            )
        }

        if let lastEvening = lastCheckIn(period: .evening, checkIns: snapshot.dailyCheckIns),
           (lastEvening.stress ?? 0) >= 8 {
            items.append(
                RecommendationItem(
                    title: "Stress élevé détecté",
                    message: "Planifiez un protocole de récupération ce soir.",
                    actionDeepLink: "biotrack://protocols",
                    priority: .high,
                    reason: "stress_high"
                )
            )
        }

        if let topCorrelation = snapshot.correlationInsights
            .sorted(by: { abs($0.pearson) > abs($1.pearson) })
            .first, abs(topCorrelation.pearson) >= 0.45 {
            items.append(
                RecommendationItem(
                    title: "Insight de corrélation",
                    message: topCorrelation.summary,
                    actionDeepLink: "biotrack://stats",
                    priority: .medium,
                    reason: "correlation_signal"
                )
            )
        }

        let adherence = InsightsEngine.adherenceInsights(snapshot: snapshot, days: 14)
        for line in adherence.prefix(2) {
            items.append(
                RecommendationItem(
                    title: "Adhérence",
                    message: line,
                    actionDeepLink: "biotrack://home",
                    priority: .medium,
                    reason: "adherence_insight"
                )
            )
        }

        let remindersEnabled = snapshot.reminders.filter { $0.enabled }.count
        if remindersEnabled == 0 && !snapshot.reminders.isEmpty {
            items.append(
                RecommendationItem(
                    title: "Rappels désactivés",
                    message: "Réactivez au moins un rappel pour soutenir l'adhérence.",
                    actionDeepLink: "biotrack://reminders",
                    priority: .medium,
                    reason: "reminders_off"
                )
            )
        }

        return items
            .sorted(by: { priorityRank($0.priority) > priorityRank($1.priority) })
            .prefix(limit)
            .map { $0 }
    }

    private static func missingCheckIn(for period: CheckInPeriod, on date: Date, checkIns: [DailyCheckIn]) -> Bool {
        !checkIns.contains {
            $0.period == period &&
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }
    }

    private static func lastCheckIn(period: CheckInPeriod, checkIns: [DailyCheckIn]) -> DailyCheckIn? {
        checkIns
            .filter { $0.period == period }
            .sorted(by: { $0.date > $1.date })
            .first
    }

    private static func priorityRank(_ priority: RecommendationPriority) -> Int {
        switch priority {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        }
    }
}

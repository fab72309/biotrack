import Foundation

enum HealthDedupePolicy: String, CaseIterable, Identifiable {
    case replace
    case keepManual
    case separate

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .replace: return "Remplacer"
        case .keepManual: return "Garder manuel"
        case .separate: return "Créer une entrée HK"
        }
    }
}

final class AppState: ObservableObject {
    @Published var protocols: [ProtocolItem] = []
    @Published var customProtocolTemplates: [CustomProtocolTemplate] = []
    @Published var protocolCompletions: [ProtocolCompletion] = []
    @Published var supplements: [Supplement] = []
    @Published var customSupplementTemplates: [CustomSupplementTemplate] = []
    @Published var supplementIntakes: [SupplementIntake] = []
    @Published var metrics: [Metric] = []
    @Published var metricEntries: [MetricEntry] = []
    @Published var reminders: [Reminder] = []
    @Published var dailyCheckIns: [DailyCheckIn] = []
    @Published var routineProfiles: [RoutineProfile] = []
    @Published var activeRoutineProfileKindRaw: String = RoutineProfileKind.weekday.rawValue
    @Published var experiments: [NOf1Experiment] = []
    @Published var experimentObservations: [NOf1Observation] = []
    @Published var adaptiveGoalPolicy: AdaptiveGoalPolicy = AdaptiveGoalPolicy()
    @Published var correlationInsights: [CorrelationInsight] = []
    @Published var recommendations: [RecommendationItem] = []
    @Published var healthKitStatus: HealthAuthorizationState = .notAvailable
    @Published var isHealthKitSyncing: Bool = false
    @Published var storeRecoveryNoticeMessage: String?
    
    private let store = LocalStore.shared
    private var notificationObservers: [NSObjectProtocol] = []
    
    init() {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-appStoreScreenshots") {
            loadAppStoreScreenshotFixture()
            observeExternalReminderUpdates()
            return
        }
#endif
        load()
        let canRunStartupBootstraps = !SharedStore.lastLoadStatus.recoveredFromCorruption
        if canRunStartupBootstraps && protocols.isEmpty && supplements.isEmpty && metrics.isEmpty {
            seed()
            save()
        }
        if canRunStartupBootstraps {
            migrateMetricsIfNeeded()
            migrateSupplementCategoriesIfNeeded()
            ensureDefaultTrackMetricsIfNeeded()
            if syncDefaultMetricsFromDailyCheckIns() {
                save(refreshInsights: false)
            }
        }
        observeExternalReminderUpdates()
    }

    deinit {
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func load() {
        var s = store.load()
        MigrationService.migrate(&s)
        self.protocols = s.protocols
        self.customProtocolTemplates = s.customProtocolTemplates
        self.protocolCompletions = s.protocolCompletions
        self.supplements = s.supplements
        self.customSupplementTemplates = s.customSupplementTemplates
        self.supplementIntakes = s.supplementIntakes
        self.metrics = s.metrics
        self.metricEntries = s.metricEntries
        self.reminders = s.reminders
        self.dailyCheckIns = s.dailyCheckIns
        self.routineProfiles = s.routineProfiles
        self.activeRoutineProfileKindRaw = s.activeRoutineProfileKindRaw ?? RoutineProfileKind.weekday.rawValue
        self.experiments = s.experiments
        self.experimentObservations = s.experimentObservations
        self.adaptiveGoalPolicy = s.adaptiveGoalPolicy
        self.correlationInsights = s.correlationInsights
        self.recommendations = s.recommendations
        if routineProfiles.isEmpty {
            routineProfiles = MigrationService.defaultRoutineProfiles()
        }
        updateStoreRecoveryNoticeIfNeeded()
    }
    
    func save(refreshInsights: Bool = true) {
        if refreshInsights {
            let insights = InsightsEngine.generateCorrelationInsights(snapshot: buildSnapshot(), windowDays: 90)
            correlationInsights = insights
            var enriched = buildSnapshot()
            enriched.correlationInsights = insights
            recommendations = RecommendationEngine.buildRecommendations(snapshot: enriched, now: Date())
        }
        var snap = LocalStore.Snapshot(schemaVersion: SnapshotSchemaVersion.current,
                                       protocols: protocols,
                                       customProtocolTemplates: customProtocolTemplates,
                                       protocolCompletions: protocolCompletions,
                                       supplements: supplements,
                                       customSupplementTemplates: customSupplementTemplates,
                                       supplementIntakes: supplementIntakes,
                                       metrics: metrics,
                                       metricEntries: metricEntries,
                                       reminders: reminders,
                                       dailyCheckIns: dailyCheckIns,
                                       routineProfiles: routineProfiles,
                                       activeRoutineProfileKindRaw: activeRoutineProfileKindRaw,
                                       experiments: experiments,
                                       experimentObservations: experimentObservations,
                                       adaptiveGoalPolicy: adaptiveGoalPolicy,
                                       correlationInsights: correlationInsights,
                                       recommendations: recommendations)
        MigrationService.migrate(&snap)
        store.save(snap)
        WidgetRefresh.reloadAll()
    }

    @MainActor
    func refreshHealthKitStatus() {
        healthKitStatus = HealthKitService.shared.authorizationState()
    }

    func syncHealthKit(rangeDays: Int = 30, dedupePolicy: HealthDedupePolicy = .replace) async {
        let shouldSkip = await MainActor.run { () -> Bool in
            if isHealthKitSyncing { return true }
            isHealthKitSyncing = true
            return false
        }
        if shouldSkip { return }
        defer { Task { @MainActor in self.isHealthKitSyncing = false } }

        let service = HealthKitService.shared
        guard service.isAvailable() else {
            await MainActor.run { self.healthKitStatus = .notAvailable }
            return
        }

        let granted = await service.requestAuthorization()
        let status = service.authorizationState()
        await MainActor.run { self.healthKitStatus = status }
        guard granted || status == .authorized else { return }

        let cal = Calendar.current
        let end = Date()
        let start = cal.date(byAdding: .day, value: -rangeDays, to: end) ?? end
        let startDay = cal.startOfDay(for: start)

        var hasAuthorizationError = false
        func fetchSafely(_ fetcher: () async throws -> [Date: Double]) async -> [Date: Double] {
            do {
                return try await fetcher()
            } catch {
                if service.isAuthorizationError(error) {
                    hasAuthorizationError = true
                }
                return [:]
            }
        }

        let sleep = await fetchSafely { try await service.fetchSleepDurations(start: startDay, end: end) }
        let steps = await fetchSafely { try await service.fetchDailySteps(start: startDay, end: end) }
        let weight = await fetchSafely { try await service.fetchDailyBodyMass(start: startDay, end: end) }
        let restingHR = await fetchSafely { try await service.fetchDailyRestingHeartRate(start: startDay, end: end) }
        let hrv = await fetchSafely { try await service.fetchDailyHRV(start: startDay, end: end) }

        if hasAuthorizationError {
            await MainActor.run { self.healthKitStatus = .denied }
            return
        }

        await MainActor.run {
            // Do not match any generic duration metric here: HealthKit sleep sync must target
            // the dedicated sleep metric to avoid polluting user-defined duration metrics.
            let sleepId = ensureMetricId(name: "Sommeil", kind: .hoursMinutes, unit: "h")
            let stepsId = ensureMetricId(name: "Pas", kind: .number, unit: "pas")
            let weightId = ensureMetricId(name: "Poids", kind: .number, unit: "kg")
            let rhrId = ensureMetricId(name: "FC au repos", kind: .number, unit: "bpm")
            let hrvId = ensureMetricId(name: "HRV (SDNN)", kind: .number, unit: "ms")

            upsertDailyEntries(metricId: sleepId, dailyValues: sleep, dedupePolicy: dedupePolicy)
            upsertDailyEntries(metricId: stepsId, dailyValues: steps, dedupePolicy: dedupePolicy)
            upsertDailyEntries(metricId: weightId, dailyValues: weight, dedupePolicy: dedupePolicy)
            upsertDailyEntries(metricId: rhrId, dailyValues: restingHR, dedupePolicy: dedupePolicy)
            upsertDailyEntries(metricId: hrvId, dailyValues: hrv, dedupePolicy: dedupePolicy)

            save()
        }
    }

    @MainActor
    private func ensureMetricId(name: String,
                                kind: MetricKind,
                                unit: String?,
                                allowKindMatch: Bool = false) -> UUID {
        if let existingByName = metrics.first(where: { $0.name == name }) {
            if existingByName.unit == nil, let unit = unit,
               let idx = metrics.firstIndex(where: { $0.id == existingByName.id }) {
                metrics[idx].unit = unit
            }
            return existingByName.id
        }
        if allowKindMatch, kind == .hoursMinutes,
           let existingByKind = metrics.first(where: { $0.kind == .hoursMinutes }) {
            return existingByKind.id
        }
        let metric = Metric(name: name, kind: kind, unit: unit)
        metrics.append(metric)
        return metric.id
    }

    @MainActor
    private func upsertDailyEntries(metricId: UUID, dailyValues: [Date: Double], dedupePolicy: HealthDedupePolicy) {
        let cal = Calendar.current
        for (day, value) in dailyValues {
            let dayStart = cal.startOfDay(for: day)
            switch dedupePolicy {
            case .replace:
                metricEntries.removeAll { $0.metricId == metricId && cal.isDate($0.date, inSameDayAs: dayStart) }
            case .keepManual:
                if metricEntries.contains(where: { $0.metricId == metricId && cal.isDate($0.date, inSameDayAs: dayStart) }) {
                    continue
                }
            case .separate:
                metricEntries.removeAll {
                    $0.metricId == metricId &&
                    cal.isDate($0.date, inSameDayAs: dayStart) &&
                    $0.notes == "HK"
                }
            }
            let entryDate: Date
            let notes: String?
            if dedupePolicy == .separate {
                entryDate = cal.date(bySettingHour: 12, minute: 0, second: 0, of: dayStart) ?? dayStart
                notes = "HK"
            } else {
                entryDate = dayStart
                notes = nil
            }
            metricEntries.append(MetricEntry(metricId: metricId, date: entryDate, value: value, notes: notes))
        }
    }

    @MainActor
    func applySnapshot(_ snapshot: LocalStore.Snapshot) {
        var migrated = snapshot
        MigrationService.migrate(&migrated)
        protocols = migrated.protocols
        customProtocolTemplates = migrated.customProtocolTemplates
        protocolCompletions = migrated.protocolCompletions
        supplements = migrated.supplements
        customSupplementTemplates = migrated.customSupplementTemplates
        supplementIntakes = migrated.supplementIntakes
        metrics = migrated.metrics
        metricEntries = migrated.metricEntries
        reminders = migrated.reminders
        dailyCheckIns = migrated.dailyCheckIns
        routineProfiles = migrated.routineProfiles
        activeRoutineProfileKindRaw = migrated.activeRoutineProfileKindRaw ?? RoutineProfileKind.weekday.rawValue
        experiments = migrated.experiments
        experimentObservations = migrated.experimentObservations
        adaptiveGoalPolicy = migrated.adaptiveGoalPolicy
        correlationInsights = migrated.correlationInsights
        recommendations = migrated.recommendations
        save()
        migrateMetricsIfNeeded()
        migrateSupplementCategoriesIfNeeded()
    }

    // MARK: - Activation toggles
    func toggleSupplementActivation(_ id: UUID, at date: Date = Date()) {
        guard let idx = supplements.firstIndex(where: { $0.id == id }) else { return }
        var item = supplements[idx]
        let now = date
        if item.active {
            if item.activationSpans.isEmpty {
                item.activationSpans = [ActivationSpan(start: Date.distantPast, end: now)]
            } else if let last = item.activationSpans.last, last.end == nil {
                item.activationSpans[item.activationSpans.count - 1].end = now
            }
            item.active = false
        } else {
            item.activationSpans.append(ActivationSpan(start: now, end: nil))
            item.active = true
        }
        var arr = supplements
        arr[idx] = item
        supplements = arr
        save()
    }

    func toggleProtocolActivation(_ id: UUID, at date: Date = Date()) {
        guard let idx = protocols.firstIndex(where: { $0.id == id }) else { return }
        var item = protocols[idx]
        let now = date
        if item.active {
            if item.activationSpans.isEmpty {
                item.activationSpans = [ActivationSpan(start: Date.distantPast, end: now)]
            } else if let last = item.activationSpans.last, last.end == nil {
                item.activationSpans[item.activationSpans.count - 1].end = now
            }
            item.active = false
        } else {
            item.activationSpans.append(ActivationSpan(start: now, end: nil))
            item.active = true
        }
        var arr = protocols
        arr[idx] = item
        protocols = arr
        save()
    }

    var activeRoutineProfileKind: RoutineProfileKind {
        get { RoutineProfileKind(rawValue: activeRoutineProfileKindRaw) ?? .weekday }
        set { activeRoutineProfileKindRaw = newValue.rawValue }
    }

    func setRoutineProfile(kind: RoutineProfileKind) {
        activeRoutineProfileKind = kind
        save()
    }

    func currentRoutineProfile() -> RoutineProfile? {
        let snapshot = buildSnapshot()
        return RoutineEngine.activeProfile(snapshot: snapshot, now: Date())
    }

    func routineProfile(for kind: RoutineProfileKind) -> RoutineProfile {
        if let profile = routineProfiles.first(where: { $0.kind == kind }) {
            return profile
        }
        return defaultRoutineProfile(for: kind)
    }

    func isProtocolEnabled(_ id: UUID, for kind: RoutineProfileKind) -> Bool {
        !routineProfile(for: kind).disabledProtocolIds.contains(id)
    }

    func isSupplementEnabled(_ id: UUID, for kind: RoutineProfileKind) -> Bool {
        !routineProfile(for: kind).disabledSupplementIds.contains(id)
    }

    func isReminderEnabled(_ id: UUID, for kind: RoutineProfileKind) -> Bool {
        !routineProfile(for: kind).disabledReminderIds.contains(id)
    }

    func setProtocolEnabled(_ id: UUID, enabled: Bool, for kind: RoutineProfileKind) {
        var profile = routineProfile(for: kind)
        profile.disabledProtocolIds = updateDisabledList(profile.disabledProtocolIds, id: id, enabled: enabled)
        upsertRoutineProfile(profile)
        save()
    }

    func setSupplementEnabled(_ id: UUID, enabled: Bool, for kind: RoutineProfileKind) {
        var profile = routineProfile(for: kind)
        profile.disabledSupplementIds = updateDisabledList(profile.disabledSupplementIds, id: id, enabled: enabled)
        upsertRoutineProfile(profile)
        save()
    }

    func setReminderEnabled(_ id: UUID, enabled: Bool, for kind: RoutineProfileKind) {
        var profile = routineProfile(for: kind)
        profile.disabledReminderIds = updateDisabledList(profile.disabledReminderIds, id: id, enabled: enabled)
        upsertRoutineProfile(profile)
        save()
    }

    func resetRoutineProfileFilters(for kind: RoutineProfileKind) {
        var profile = routineProfile(for: kind)
        profile.disabledProtocolIds = []
        profile.disabledSupplementIds = []
        profile.disabledReminderIds = []
        upsertRoutineProfile(profile)
        save()
    }

    func upsertCheckIn(period: CheckInPeriod,
                       date: Date = Date(),
                       energy: Int,
                       mood: Int,
                       sleepQuality: Int? = nil,
                       stress: Int? = nil,
                       note: String? = nil,
                       customMetricValues: [UUID: Double] = [:]) {
        if let index = dailyCheckIns.firstIndex(where: { $0.period == period && Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            dailyCheckIns[index].energy = clampScore(energy)
            dailyCheckIns[index].mood = clampScore(mood)
            dailyCheckIns[index].sleepQuality = sleepQuality.map(clampScore)
            dailyCheckIns[index].stress = stress.map(clampScore)
            dailyCheckIns[index].note = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            dailyCheckIns.append(
                DailyCheckIn(
                    date: date,
                    period: period,
                    energy: clampScore(energy),
                    mood: clampScore(mood),
                    sleepQuality: sleepQuality.map(clampScore),
                    stress: stress.map(clampScore),
                    note: note?.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
        }
        var mergedMetricValues = customMetricValues
        for (metricId, value) in defaultCheckInMetricValues(
            period: period,
            energy: energy,
            mood: mood,
            sleepQuality: sleepQuality,
            stress: stress
        ) {
            mergedMetricValues[metricId] = value
        }
        upsertCheckInMetricEntries(period: period, date: date, values: mergedMetricValues)
        LocalAnalyticsService.track("checkin_completed", metadata: ["period": period.rawValue])
        refreshInsightsAndRecommendations()
        save()
    }

    func checkIn(for period: CheckInPeriod, on date: Date = Date()) -> DailyCheckIn? {
        dailyCheckIns.first { $0.period == period && Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    func createExperiment(input: ExperimentWizardInput) {
        let experiment = ExperimentEngine.createExperiment(from: input)
        experiments.append(experiment)
        LocalAnalyticsService.track("experiment_created", metadata: ["id": experiment.id.uuidString])
        save()
    }

    func recordObservation(experimentId: UUID, value: Double, date: Date = Date(), notes: String? = nil) {
        guard let experiment = experiments.first(where: { $0.id == experimentId }) else { return }
        let phase = ExperimentEngine.phase(for: experiment, on: date)
        if let idx = experimentObservations.firstIndex(where: { $0.experimentId == experimentId && Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            experimentObservations[idx].phase = phase
            experimentObservations[idx].value = value
            experimentObservations[idx].notes = notes
        } else {
            experimentObservations.append(
                NOf1Observation(
                    experimentId: experimentId,
                    date: date,
                    phase: phase,
                    value: value,
                    notes: notes
                )
            )
        }
        save()
    }

    func experimentSummary(experimentId: UUID) -> ExperimentSummary? {
        guard let experiment = experiments.first(where: { $0.id == experimentId }) else { return nil }
        return ExperimentEngine.buildSummary(for: experiment, observations: experimentObservations)
    }

    func refreshInsightsAndRecommendations(now: Date = Date()) {
        let snapshot = buildSnapshot()
        correlationInsights = InsightsEngine.generateCorrelationInsights(snapshot: snapshot, windowDays: 90)
        var nextSnapshot = buildSnapshot()
        nextSnapshot.correlationInsights = correlationInsights
        recommendations = RecommendationEngine.buildRecommendations(snapshot: nextSnapshot, now: now)
    }

    func applyAdaptiveGoalPolicyIfNeeded(now: Date = Date()) {
        guard adaptiveGoalPolicy.enabled else { return }
        let calendar = Calendar.current
        if let last = adaptiveGoalPolicy.lastAppliedAt, calendar.isDate(last, equalTo: now, toGranularity: .weekOfYear) {
            return
        }
        let snapshot = buildSnapshot()
        let adherence = InsightsEngine.adherenceInsights(snapshot: snapshot, days: 14)
        if adherence.contains(where: { $0.contains("faible") }) {
            adaptiveGoalPolicy.maxDailyTarget = max(adaptiveGoalPolicy.minDailyTarget, adaptiveGoalPolicy.maxDailyTarget - 1)
        } else {
            adaptiveGoalPolicy.maxDailyTarget = min(40, adaptiveGoalPolicy.maxDailyTarget + 1)
        }
        adaptiveGoalPolicy.lastAppliedAt = now
        save()
    }

    func buildSnapshot() -> BioTrackSnapshot {
        BioTrackSnapshot(schemaVersion: SnapshotSchemaVersion.current,
                         protocols: protocols,
                         customProtocolTemplates: customProtocolTemplates,
                         protocolCompletions: protocolCompletions,
                         supplements: supplements,
                         customSupplementTemplates: customSupplementTemplates,
                         supplementIntakes: supplementIntakes,
                         metrics: metrics,
                         metricEntries: metricEntries,
                         reminders: reminders,
                         dailyCheckIns: dailyCheckIns,
                         routineProfiles: routineProfiles,
                         activeRoutineProfileKindRaw: activeRoutineProfileKindRaw,
                         experiments: experiments,
                         experimentObservations: experimentObservations,
                         adaptiveGoalPolicy: adaptiveGoalPolicy,
                         correlationInsights: correlationInsights,
                         recommendations: recommendations)
    }

    func hasProtocolTemplate(named name: String) -> Bool {
        let key = normalizedTemplateKey(name)
        guard !key.isEmpty else { return false }
        return customProtocolTemplates.contains { normalizedTemplateKey($0.name) == key }
    }

    @discardableResult
    func addProtocolTemplate(from protocolItem: ProtocolItem) -> Bool {
        let key = normalizedTemplateKey(protocolItem.name)
        guard !key.isEmpty else { return false }
        guard !hasProtocolTemplate(named: protocolItem.name) else { return false }

        let hour = protocolItem.preferredHour?.hour ?? 8
        let minute = protocolItem.preferredHour?.minute ?? 0
        let template = CustomProtocolTemplate(
            name: protocolItem.name,
            detail: protocolItem.detail ?? protocolItem.notes,
            category: protocolItem.category?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? (protocolItem.category ?? "Autre")
                : "Autre",
            minutes: max(1, protocolItem.targetMinutes ?? 10),
            frequency: protocolItem.frequency,
            hour: max(0, min(hour, 23)),
            minute: max(0, min(minute, 59))
        )
        customProtocolTemplates.append(template)
        save(refreshInsights: false)
        return true
    }

    func hasSupplementTemplate(named name: String) -> Bool {
        let key = normalizedTemplateKey(name)
        guard !key.isEmpty else { return false }
        return customSupplementTemplates.contains { normalizedTemplateKey($0.name) == key }
    }

    @discardableResult
    func addSupplementTemplate(from supplement: Supplement) -> Bool {
        let key = normalizedTemplateKey(supplement.name)
        guard !key.isEmpty else { return false }
        guard !hasSupplementTemplate(named: supplement.name) else { return false }

        let template = CustomSupplementTemplate(
            name: supplement.name,
            brand: supplement.brand?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? supplement.brand : nil,
            dose: supplement.dose?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? supplement.dose : nil,
            category: supplement.category?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? (supplement.category ?? "Autre")
                : "Autre",
            timeContext: supplement.timeContext?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? supplement.timeContext : nil,
            frequency: supplement.frequency
        )
        customSupplementTemplates.append(template)
        save(refreshInsights: false)
        return true
    }

    private func normalizedTemplateKey(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func clampScore(_ value: Int) -> Int {
        min(10, max(1, value))
    }

    private func upsertCheckInMetricEntries(period: CheckInPeriod, date: Date, values: [UUID: Double]) {
        guard !values.isEmpty else { return }

        let calendar = Calendar.current
        let periodTag = "checkin:\(period.rawValue)"

        for (metricId, value) in values {
            guard metrics.contains(where: { $0.id == metricId }) else { continue }

            if let index = metricEntries.firstIndex(where: {
                $0.metricId == metricId &&
                calendar.isDate($0.date, inSameDayAs: date) &&
                ($0.notes?.hasPrefix(periodTag) ?? false)
            }) {
                metricEntries[index].value = value
                metricEntries[index].date = metricEntryDate(for: metricId, from: date)
                metricEntries[index].notes = periodTag
            } else {
                metricEntries.append(
                    MetricEntry(
                        metricId: metricId,
                        date: metricEntryDate(for: metricId, from: date),
                        value: value,
                        notes: periodTag
                    )
                )
            }
        }
    }

    private func metricEntryDate(for metricId: UUID, from date: Date) -> Date {
        guard let metric = metrics.first(where: { $0.id == metricId }) else {
            return Calendar.current.startOfDay(for: date)
        }
        if metric.kind == .hoursMinutes {
            return Calendar.current.startOfDay(for: date)
        }
        return date
    }

    private func defaultCheckInMetricValues(
        period: CheckInPeriod,
        energy: Int,
        mood: Int,
        sleepQuality: Int?,
        stress: Int?
    ) -> [UUID: Double] {
        var values: [UUID: Double] = [:]

        if let energyId = findMetricId(matchingAny: ["energie", "energy"], kind: .number) {
            values[energyId] = Double(clampScore(energy))
        }
        if let moodId = findMetricId(matchingAny: ["humeur", "mood"], kind: .number) {
            values[moodId] = Double(clampScore(mood))
        }
        if period == .morning,
           let sleepQuality,
           let sleepQualityId = findMetricId(matchingAny: ["qualitedusommeil", "sleepquality"], kind: .number) {
            values[sleepQualityId] = Double(clampScore(sleepQuality))
        }
        if period == .evening,
           let stress,
           let stressId = findMetricId(matchingAny: ["stress"], kind: .number) {
            values[stressId] = Double(clampScore(stress))
        }

        return values
    }

    private func syncDefaultMetricsFromDailyCheckIns() -> Bool {
        guard !dailyCheckIns.isEmpty else { return false }

        let previousEntries = metricEntries

        for checkIn in dailyCheckIns {
            let values = defaultCheckInMetricValues(
                period: checkIn.period,
                energy: checkIn.energy,
                mood: checkIn.mood,
                sleepQuality: checkIn.sleepQuality,
                stress: checkIn.stress
            )
            upsertCheckInMetricEntries(period: checkIn.period, date: checkIn.date, values: values)
        }

        return metricEntries != previousEntries
    }

    private func findMetricId(matchingAny normalizedNames: [String], kind: MetricKind) -> UUID? {
        let targets = Set(normalizedNames.map(normalizeMetricLabel))
        return metrics.first(where: {
            $0.kind == kind && targets.contains(normalizeMetricLabel($0.name))
        })?.id
    }

    private func upsertRoutineProfile(_ profile: RoutineProfile) {
        if let idx = routineProfiles.firstIndex(where: { $0.kind == profile.kind }) {
            routineProfiles[idx] = profile
        } else {
            routineProfiles.append(profile)
        }
    }

    private func defaultRoutineProfile(for kind: RoutineProfileKind) -> RoutineProfile {
        if let profile = MigrationService.defaultRoutineProfiles().first(where: { $0.kind == kind }) {
            return profile
        }
        let weekdays: [Int]
        switch kind {
        case .weekday:
            weekdays = [1, 2, 3, 4, 5]
        case .weekend:
            weekdays = [6, 7]
        case .travel:
            weekdays = [1, 2, 3, 4, 5, 6, 7]
        }
        return RoutineProfile(
            kind: kind,
            name: kind.displayName,
            weekdays: weekdays,
            disabledProtocolIds: [],
            disabledSupplementIds: [],
            disabledReminderIds: []
        )
    }

    private func updateDisabledList(_ current: [UUID], id: UUID, enabled: Bool) -> [UUID] {
        var set = Set(current)
        if enabled {
            set.remove(id)
        } else {
            set.insert(id)
        }
        return set.sorted { $0.uuidString < $1.uuidString }
    }
    
    func seed() {
        let meditation = ProtocolItem(name: "Méditation matinale",
                                      detail: "10 minutes",
                                      frequency: .daily,
                                      preferredHour: DateComponents(hour: 7, minute: 0),
                                      targetMinutes: 10,
                                      notes: "Respiration calme",
                                      remindersEnabled: true)
        protocols.append(meditation)

        let sleep = Metric(name: "Sommeil", kind: .hoursMinutes, unit: "h")
        let mood = Metric(name: "Humeur", kind: .number, unit: "1-10")
        metrics.append(contentsOf: [sleep, mood])
        routineProfiles = MigrationService.defaultRoutineProfiles()
    }

#if DEBUG
    private func loadAppStoreScreenshotFixture() {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())

        let meditation = ProtocolItem(
            name: "Méditation matinale",
            detail: "10 minutes",
            frequency: .daily,
            preferredHour: DateComponents(hour: 7, minute: 0),
            targetMinutes: 10,
            notes: "Respiration calme",
            remindersEnabled: true
        )
        let walk = ProtocolItem(
            name: "Marche en extérieur",
            detail: "20 minutes",
            frequency: .daily,
            preferredHour: DateComponents(hour: 12, minute: 30),
            targetMinutes: 20,
            notes: "À adapter selon votre journée",
            remindersEnabled: false
        )
        protocols = [meditation, walk]

        let magnesium = Supplement(
            name: "Magnésium — suivi personnel",
            brand: nil,
            dose: nil,
            category: "Autre",
            timeOfDay: DateComponents(hour: 20, minute: 0),
            frequency: .daily,
            durationNote: nil,
            notes: "Exemple visuel, sans recommandation de prise",
            active: true
        )
        supplements = [magnesium]

        let sleep = Metric(name: "Sommeil", kind: .hoursMinutes, unit: "h")
        let mood = Metric(name: "Humeur", kind: .number, unit: "1-10")
        let energy = Metric(name: "Énergie", kind: .number, unit: "1-10")
        let stress = Metric(name: "Stress", kind: .number, unit: "1-10")
        metrics = [sleep, mood, energy, stress]

        for offset in 0..<35 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let rhythm = sin(Double(offset) * 0.61)
            let recovery = cos(Double(offset) * 0.27) * 0.35
            let sleepMinutes = 440 + rhythm * 32 + recovery * 20
            let moodValue = min(10, max(1, 7.1 + rhythm * 1.15 + recovery))
            let energyValue = min(10, max(1, 7.4 + rhythm * 1.25 + recovery * 0.8))
            let stressValue = min(10, max(1, 4.2 - rhythm * 1.05 - recovery * 0.6))

            metricEntries.append(MetricEntry(metricId: sleep.id, date: date, value: sleepMinutes))
            metricEntries.append(MetricEntry(metricId: mood.id, date: date, value: moodValue))
            metricEntries.append(MetricEntry(metricId: energy.id, date: date, value: energyValue))
            metricEntries.append(MetricEntry(metricId: stress.id, date: date, value: stressValue))

            if offset % 5 != 0 {
                protocolCompletions.append(
                    ProtocolCompletion(protocolId: meditation.id, date: date, completed: true)
                )
            }
            if offset % 3 == 0 {
                protocolCompletions.append(
                    ProtocolCompletion(protocolId: walk.id, date: date, completed: true)
                )
            }
            if offset % 4 != 0 {
                supplementIntakes.append(
                    SupplementIntake(supplementId: magnesium.id, date: date, taken: true)
                )
            }
        }

        dailyCheckIns = [
            DailyCheckIn(
                date: today,
                period: .morning,
                energy: 8,
                mood: 8,
                sleepQuality: 8,
                stress: nil,
                note: "Bonne récupération"
            )
        ]
        routineProfiles = MigrationService.defaultRoutineProfiles()
        activeRoutineProfileKindRaw = RoutineProfileKind.weekday.rawValue
        refreshInsightsAndRecommendations(now: today)
    }
#endif

    private func observeExternalReminderUpdates() {
        let token = NotificationCenter.default.addObserver(
            forName: .bioTrackReminderMarkedDone,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard let baseId = notification.userInfo?[NotificationService.reminderBaseIdUserInfoKey] as? String,
                  !baseId.isEmpty else { return }
            self.applyReminderMarkedDoneExternally(baseId: baseId)
        }
        notificationObservers.append(token)
    }

    private func applyReminderMarkedDoneExternally(baseId: String) {
        guard let idx = reminders.firstIndex(where: { $0.notificationBaseId == baseId }) else { return }
        guard reminders[idx].enabled else { return }
        var updated = reminders
        updated[idx].enabled = false
        reminders = updated
    }

    func dismissStoreRecoveryNotice() {
        storeRecoveryNoticeMessage = nil
    }

    private func updateStoreRecoveryNoticeIfNeeded() {
        guard SharedStore.lastLoadStatus.recoveredFromCorruption else { return }
        guard storeRecoveryNoticeMessage == nil else { return }

        let backupName = SharedStore.lastRecoveredStoreBackupURL?.lastPathComponent
        if let backupName, !backupName.isEmpty {
            storeRecoveryNoticeMessage = "Une erreur de lecture des données locales a été détectée. Un fichier de secours a été conservé (\(backupName)). L'application a démarré sans réécrire automatiquement vos données. Évitez de saisir de nouvelles données avant vérification/import."
        } else {
            storeRecoveryNoticeMessage = "Une erreur de lecture des données locales a été détectée. Une copie de secours a été conservée si possible. L'application a démarré sans réécrire automatiquement vos données. Évitez de saisir de nouvelles données avant vérification/import."
        }
    }
}

// MARK: - Migrations
extension AppState {
    private func migrateMetricsIfNeeded() {
        // Objectif: unifier la métrique de sommeil (durée) sous le nom "Sommeil"
        // et fusionner d'éventuels doublons (ex.: "Durée du sommeil").
        let sleepMetrics = metrics.enumerated().filter { $0.element.kind == .hoursMinutes }
        guard !sleepMetrics.isEmpty else { return }

        // Choisir un ID canonique
        let canonicalIndex: Int
        if let idx = sleepMetrics.first(where: { $0.element.name.lowercased().contains("sommeil") })?.offset {
            canonicalIndex = idx
        } else {
            canonicalIndex = sleepMetrics.first!.offset
        }
        let canonicalId = metrics[canonicalIndex].id

        // Renommer la métrique canonique en "Sommeil"
        metrics[canonicalIndex].name = "Sommeil"
        if metrics[canonicalIndex].unit == nil { metrics[canonicalIndex].unit = "h" }

        // Rediriger les entrées vers l'ID canonique et supprimer doublons
        let duplicateIndices = sleepMetrics.map { $0.offset }.filter { $0 != canonicalIndex }.sorted(by: >)
        if !duplicateIndices.isEmpty {
            for dupIdx in duplicateIndices {
                let dupId = metrics[dupIdx].id
                for i in 0..<metricEntries.count {
                    if metricEntries[i].metricId == dupId { metricEntries[i].metricId = canonicalId }
                }
                metrics.remove(at: dupIdx)
            }
            save()
        }
    }

    // Normalise les catégories de suppléments (fusion EN -> FR, casse, accents)
    private func migrateSupplementCategoriesIfNeeded() {
        guard !supplements.isEmpty else { return }
        var changed = false
        for idx in supplements.indices {
            if let cat = supplements[idx].category {
                let canonical = canonicalCategory(from: cat)
                if canonical != cat {
                    supplements[idx].category = canonical
                    changed = true
                }
            }
        }
        if changed { save() }
    }

    private func canonicalCategory(from raw: String) -> String {
        let key = normalize(raw)
        switch key {
        case "nootropiques", "nootropics": return "Nootropiques"
        case "vitamines", "vitamins": return "Vitamines"
        case "mineraux", "minéraux", "minerals": return "Minéraux"
        case "proteines", "protéines", "protein", "proteins": return "Protéines"
        case "energie", "énergie", "performance", "energy": return "Énergie"
        case "recuperation", "récupération", "recovery": return "Récupération"
        case "sommeil", "sleep": return "Sommeil"
        case "digestif", "digestive": return "Digestif"
        case "immunite", "immunité", "immune": return "Immunité"
        case "traitement medical", "traitement", "medical": return "Traitement médical"
        default: return raw
        }
    }

    private func normalize(_ s: String) -> String {
        let lower = s.lowercased()
        let folded = lower.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return folded.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func ensureDefaultTrackMetricsIfNeeded() {
        var changed = false

        for preset in defaultTrackMetricPresets() {
            let exists = metrics.contains(where: { isEquivalentTrackMetric($0, to: preset) })
            if !exists {
                metrics.append(
                    Metric(
                        name: preset.name,
                        kind: preset.kind,
                        unit: preset.unit,
                        description: preset.description
                    )
                )
                changed = true
            }
        }

        if changed {
            save(refreshInsights: false)
        }
    }

    private func defaultTrackMetricPresets() -> [(name: String, kind: MetricKind, unit: String?, description: String?)] {
        [
            ("Durée du sommeil", .hoursMinutes, "h", "Heures de sommeil par nuit"),
            ("Qualité du sommeil", .number, "1-10", nil),
            ("Humeur", .number, "1-10", nil),
            ("Énergie", .number, "1-10", nil),
            ("Concentration", .number, "1-10", nil),
            ("Poids", .number, "kg", nil),
            ("Pas", .number, "pas", nil),
            ("FC au repos", .number, "bpm", nil),
            ("HRV (SDNN)", .number, "ms", nil),
            ("Stress", .number, "1-10", nil)
        ]
    }

    private func isEquivalentTrackMetric(
        _ metric: Metric,
        to preset: (name: String, kind: MetricKind, unit: String?, description: String?)
    ) -> Bool {
        let metricName = normalizeMetricLabel(metric.name)
        let presetName = normalizeMetricLabel(preset.name)

        if metricName == presetName { return true }

        if metric.kind == .hoursMinutes && preset.kind == .hoursMinutes {
            if metricName.contains("sommeil") && presetName.contains("sommeil") {
                return true
            }
        }

        if metric.kind == .number && preset.kind == .number {
            if metricName.contains("hrv") && presetName.contains("hrv") {
                return true
            }
        }

        return false
    }

    private func normalizeMetricLabel(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

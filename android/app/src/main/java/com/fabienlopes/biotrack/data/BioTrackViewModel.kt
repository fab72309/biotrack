package com.fabienlopes.biotrack.data

import android.app.Application
import androidx.core.content.edit
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.fabienlopes.biotrack.domain.Planner
import com.fabienlopes.biotrack.domain.Statistics
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.ZoneId

enum class HealthConnectionStatus { NOT_AVAILABLE, NOT_CONNECTED, CONNECTED, DENIED }

class BioTrackViewModel(application: Application) : AndroidViewModel(application) {
    private val store = LocalStore(application)
    private val preferences = application.getSharedPreferences("biotrack-preferences", 0)

    private val _snapshot = MutableStateFlow(loadInitialSnapshot())
    val snapshot: StateFlow<AppSnapshot> = _snapshot.asStateFlow()

    var onboardingComplete = MutableStateFlow(preferences.getBoolean("onboardingComplete", false))
        private set
    var darkMode = MutableStateFlow(preferences.getBoolean("darkMode", false))
        private set
    var showRecommendations = MutableStateFlow(preferences.getBoolean("showRecommendations", true))
        private set
    var healthStatus = MutableStateFlow(HealthConnectionStatus.NOT_AVAILABLE)
        private set
    var healthSyncing = MutableStateFlow(false)
        private set
    var lastMessage = MutableStateFlow<String?>(null)
        private set

    init {
        Planner.currentSnapshot = _snapshot.value
    }

    fun completeOnboarding() {
        preferences.edit { putBoolean("onboardingComplete", true) }
        onboardingComplete.value = true
    }

    fun reviewOnboarding() {
        preferences.edit { putBoolean("onboardingComplete", false) }
        onboardingComplete.value = false
    }

    fun setDarkMode(enabled: Boolean) {
        preferences.edit { putBoolean("darkMode", enabled) }
        darkMode.value = enabled
    }

    fun setShowRecommendations(enabled: Boolean) {
        preferences.edit { putBoolean("showRecommendations", enabled) }
        showRecommendations.value = enabled
    }

    fun clearMessage() {
        lastMessage.value = null
    }

    fun toggleProtocol(protocolId: String, now: Long = System.currentTimeMillis()) {
        val current = _snapshot.value
        val existing = current.protocolCompletions.indexOfFirst { it.protocolId == protocolId && Planner.sameDay(it.date, now) }
        val completions = if (existing >= 0) current.protocolCompletions.toMutableList().also { it.removeAt(existing) } else {
            current.protocolCompletions + ProtocolCompletion(protocolId = protocolId, date = now, completed = true)
        }
        commit(current.copy(protocolCompletions = completions))
    }

    fun toggleSupplement(supplementId: String, now: Long = System.currentTimeMillis()) {
        val current = _snapshot.value
        val existing = current.supplementIntakes.indexOfFirst { it.supplementId == supplementId && Planner.sameDay(it.date, now) }
        val intakes = if (existing >= 0) current.supplementIntakes.toMutableList().also { it.removeAt(existing) } else {
            current.supplementIntakes + SupplementIntake(supplementId = supplementId, date = now, taken = true)
        }
        commit(current.copy(supplementIntakes = intakes))
    }

    fun upsertCheckIn(
        period: CheckInPeriod,
        energy: Int,
        mood: Int,
        sleepQuality: Int? = null,
        stress: Int? = null,
        note: String? = null,
        now: Long = System.currentTimeMillis()
    ) {
        val current = _snapshot.value
        val remaining = current.dailyCheckIns.filterNot { it.period == period && Planner.sameDay(it.date, now) }
        commit(current.copy(dailyCheckIns = remaining + DailyCheckIn(
            date = now,
            period = period,
            energy = energy.coerceIn(1, 10),
            mood = mood.coerceIn(1, 10),
            sleepQuality = sleepQuality?.coerceIn(1, 10),
            stress = stress?.coerceIn(1, 10),
            note = note?.trim()?.takeIf { it.isNotEmpty() }
        )))
    }

    fun addMetric(name: String, kind: MetricKind, unit: String?) {
        if (name.isBlank()) return
        commit(_snapshot.value.copy(metrics = _snapshot.value.metrics + Metric(name = name.trim(), kind = kind, unit = unit?.trim()?.takeIf { it.isNotEmpty() })))
    }

    fun deleteMetric(id: String) {
        val current = _snapshot.value
        commit(current.copy(metrics = current.metrics.filterNot { it.id == id }, metricEntries = current.metricEntries.filterNot { it.metricId == id }))
    }

    fun addMetricEntry(metricId: String, value: Double, notes: String? = null, date: Long = System.currentTimeMillis()) {
        if (!value.isFinite()) return
        commit(_snapshot.value.copy(metricEntries = _snapshot.value.metricEntries + MetricEntry(metricId = metricId, value = value, notes = notes, date = date)))
    }

    fun addProtocol(item: ProtocolItem) {
        if (item.name.isBlank()) return
        commit(_snapshot.value.copy(protocols = _snapshot.value.protocols + item.copy(name = item.name.trim())))
    }

    fun updateProtocol(item: ProtocolItem) {
        val current = _snapshot.value
        commit(current.copy(protocols = current.protocols.map { if (it.id == item.id) item else it }))
    }

    fun deleteProtocol(id: String) {
        val current = _snapshot.value
        commit(current.copy(protocols = current.protocols.filterNot { it.id == id }, protocolCompletions = current.protocolCompletions.filterNot { it.protocolId == id }))
    }

    fun toggleProtocolActive(id: String) {
        val current = _snapshot.value
        commit(current.copy(protocols = current.protocols.map { if (it.id == id) it.copy(active = !it.active) else it }))
    }

    fun addSupplement(item: Supplement) {
        if (item.name.isBlank()) return
        commit(_snapshot.value.copy(supplements = _snapshot.value.supplements + item.copy(name = item.name.trim())))
    }

    fun updateSupplement(item: Supplement) {
        val current = _snapshot.value
        commit(current.copy(supplements = current.supplements.map { if (it.id == item.id) item else it }))
    }

    fun deleteSupplement(id: String) {
        val current = _snapshot.value
        commit(current.copy(supplements = current.supplements.filterNot { it.id == id }, supplementIntakes = current.supplementIntakes.filterNot { it.supplementId == id }))
    }

    fun toggleSupplementActive(id: String) {
        val current = _snapshot.value
        commit(current.copy(supplements = current.supplements.map { if (it.id == id) it.copy(active = !it.active) else it }))
    }

    fun addReminder(reminder: Reminder) {
        commit(_snapshot.value.copy(reminders = _snapshot.value.reminders + reminder))
    }

    fun updateReminder(reminder: Reminder) {
        val current = _snapshot.value
        commit(current.copy(reminders = current.reminders.map { if (it.id == reminder.id) reminder else it }))
    }

    fun deleteReminder(id: String) {
        commit(_snapshot.value.copy(reminders = _snapshot.value.reminders.filterNot { it.id == id }))
    }

    fun setReminderEnabled(id: String, enabled: Boolean) {
        val current = _snapshot.value
        commit(current.copy(reminders = current.reminders.map { if (it.id == id) it.copy(enabled = enabled) else it }))
    }

    fun setRoutineProfile(kind: RoutineProfileKind) {
        commit(_snapshot.value.copy(activeRoutineProfileKindRaw = kind.name))
    }

    fun createExperiment(title: String, hypothesis: String, metricId: String, durationDays: Int, phaseDays: Int) {
        val experiment = NOf1Experiment(
            title = title.trim().ifBlank { "Expérience N-of-1" },
            hypothesis = hypothesis.trim(),
            targetMetricId = metricId,
            durationDays = durationDays.coerceAtLeast(7),
            phaseDurationDays = phaseDays.coerceAtLeast(3)
        )
        commit(_snapshot.value.copy(experiments = _snapshot.value.experiments + experiment))
    }

    fun recordObservation(experimentId: String, value: Double, notes: String? = null) {
        val experiment = _snapshot.value.experiments.firstOrNull { it.id == experimentId } ?: return
        val observation = NOf1Observation(experimentId = experimentId, phase = Statistics.experimentPhase(experiment), value = value, notes = notes)
        commit(_snapshot.value.copy(experimentObservations = _snapshot.value.experimentObservations + observation))
    }

    fun applyImportedSnapshot(imported: AppSnapshot) {
        commit(normalize(imported))
        lastMessage.value = "Sauvegarde importée."
    }

    fun exportSnapshot(): String = store.encode(_snapshot.value)

    fun exportEncrypted(passphrase: CharArray): String = EncryptedBackup.encrypt(exportSnapshot(), passphrase)

    fun importEncrypted(raw: String, passphrase: CharArray) {
        val decoded = EncryptedBackup.decrypt(raw, passphrase)
        applyImportedSnapshot(store.decode(decoded))
    }

    fun setHealthStatus(status: HealthConnectionStatus) {
        healthStatus.value = status
    }

    fun setHealthSyncing(syncing: Boolean) {
        healthSyncing.value = syncing
    }

    fun syncHealthValues(valuesByMetricName: Map<String, Map<Long, Double>>) {
        if (valuesByMetricName.isEmpty()) return
        val current = _snapshot.value
        val names = listOf(
            "Sommeil" to MetricKind.HOURS_MINUTES,
            "Pas" to MetricKind.NUMBER,
            "Poids" to MetricKind.NUMBER,
            "FC au repos" to MetricKind.NUMBER,
            "HRV (RMSSD)" to MetricKind.NUMBER
        )
        var metrics = current.metrics
        var entries = current.metricEntries.toMutableList()
        valuesByMetricName.forEach { (name, values) ->
            val kind = names.firstOrNull { it.first == name }?.second ?: MetricKind.NUMBER
            val unit = when (name) {
                "Sommeil" -> "h"
                "Pas" -> "pas"
                "Poids" -> "kg"
                "FC au repos" -> "bpm"
                else -> "ms"
            }
            val existing = metrics.firstOrNull { it.name == name }
            val metric = existing ?: Metric(name = name, kind = kind, unit = unit).also { metrics += it }
            values.forEach { (date, value) ->
                entries.removeAll { it.metricId == metric.id && Planner.sameDay(it.date, date) && it.notes == "Health Connect" }
                entries += MetricEntry(metricId = metric.id, date = date, value = value, notes = "Health Connect")
            }
        }
        commit(current.copy(metrics = metrics, metricEntries = entries))
    }

    fun refreshInsights() {
        commit(_snapshot.value)
    }

    private fun commit(next: AppSnapshot) {
        val derived = next.copy(
            schemaVersion = 3,
            correlationInsights = Statistics.generateInsights(next),
        ).let { withInsights ->
            withInsights.copy(recommendations = Statistics.recommendations(withInsights))
        }
        _snapshot.value = normalize(derived)
        Planner.currentSnapshot = _snapshot.value
        viewModelScope.launch(Dispatchers.IO) { store.save(_snapshot.value) }
    }

    private fun loadInitialSnapshot(): AppSnapshot {
        val loaded = normalize(store.load())
        val seeded = if (loaded.protocols.isEmpty() && loaded.supplements.isEmpty() && loaded.metrics.isEmpty()) seed(loaded) else loaded
        val derived = seeded.copy(correlationInsights = Statistics.generateInsights(seeded)).let { it.copy(recommendations = Statistics.recommendations(it)) }
        return normalize(derived)
    }

    private fun normalize(snapshot: AppSnapshot): AppSnapshot {
        val profiles = if (snapshot.routineProfiles.isEmpty()) defaultRoutineProfiles() else snapshot.routineProfiles
        return snapshot.copy(
            schemaVersion = 3,
            routineProfiles = profiles,
            activeRoutineProfileKindRaw = snapshot.activeRoutineProfileKindRaw.ifBlank { RoutineProfileKind.WEEKDAY.name },
            adaptiveGoalPolicy = snapshot.adaptiveGoalPolicy.copy(
                minDailyTarget = snapshot.adaptiveGoalPolicy.minDailyTarget.coerceAtLeast(1),
                maxDailyTarget = snapshot.adaptiveGoalPolicy.maxDailyTarget.coerceAtLeast(snapshot.adaptiveGoalPolicy.minDailyTarget.coerceAtLeast(1))
            )
        )
    }

    private fun defaultRoutineProfiles(): List<RoutineProfile> = listOf(
        RoutineProfile(kind = RoutineProfileKind.WEEKDAY, name = "Semaine", weekdays = listOf(1, 2, 3, 4, 5)),
        RoutineProfile(kind = RoutineProfileKind.WEEKEND, name = "Weekend", weekdays = listOf(6, 7)),
        RoutineProfile(kind = RoutineProfileKind.TRAVEL, name = "Voyage", weekdays = (1..7).toList())
    )

    private fun seed(base: AppSnapshot): AppSnapshot {
        val meditation = ProtocolItem(name = "Méditation matinale", detail = "10 minutes", targetMinutes = 10, preferredHour = 7, preferredMinute = 0, notes = "Respiration calme", remindersEnabled = true, category = "Récupération")
        val sleep = Metric(name = "Sommeil", kind = MetricKind.HOURS_MINUTES, unit = "h")
        val mood = Metric(name = "Humeur", kind = MetricKind.NUMBER, unit = "1-10")
        return base.copy(protocols = listOf(meditation), metrics = listOf(sleep, mood), routineProfiles = defaultRoutineProfiles())
    }
}

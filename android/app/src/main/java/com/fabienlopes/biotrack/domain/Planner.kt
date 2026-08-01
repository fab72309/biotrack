package com.fabienlopes.biotrack.domain

import com.fabienlopes.biotrack.data.AppSnapshot
import com.fabienlopes.biotrack.data.Frequency
import com.fabienlopes.biotrack.data.FrequencyKind
import com.fabienlopes.biotrack.data.ProtocolItem
import com.fabienlopes.biotrack.data.Reminder
import com.fabienlopes.biotrack.data.RoutineProfile
import com.fabienlopes.biotrack.data.RoutineProfileKind
import com.fabienlopes.biotrack.data.Supplement
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

data class PlannedItem(
    val id: String,
    val title: String,
    val kind: PlannedItemKind,
    val done: Boolean,
    val subtitle: String? = null,
    val preferredMinutes: Int? = null
)

enum class PlannedItemKind { PROTOCOL, SUPPLEMENT }

data class DailyPlan(
    val items: List<PlannedItem>,
    val reminders: List<Reminder>,
    val profileName: String?
) {
    val done: Int get() = items.count { it.done }
    val total: Int get() = items.size
}

object Planner {
    private val zone: ZoneId get() = ZoneId.systemDefault()

    fun today(now: Long = System.currentTimeMillis()): DailyPlan {
        val snapshot = currentSnapshot ?: return DailyPlan(emptyList(), emptyList(), null)
        return plan(snapshot, now)
    }

    // Used by lightweight consumers that already have a snapshot.
    var currentSnapshot: AppSnapshot? = null

    fun plan(snapshot: AppSnapshot, now: Long = System.currentTimeMillis()): DailyPlan {
        val profile = activeProfile(snapshot, now)
        val protocols = protocolsScheduledToday(snapshot, now)
            .filter { profile?.disabledProtocolIds?.contains(it.id) != true }
            .map {
                PlannedItem(
                    id = it.id,
                    title = it.name,
                    kind = PlannedItemKind.PROTOCOL,
                    done = isProtocolDoneToday(it.id, snapshot, now),
                    subtitle = frequencyLabel(it.frequency),
                    preferredMinutes = preferredMinutes(it.preferredHour, it.preferredMinute)
                )
            }
        val supplements = supplementsScheduledToday(snapshot, now)
            .filter { profile?.disabledSupplementIds?.contains(it.id) != true }
            .map {
                PlannedItem(
                    id = it.id,
                    title = it.name,
                    kind = PlannedItemKind.SUPPLEMENT,
                    done = isSupplementTakenToday(it.id, snapshot, now),
                    subtitle = it.dose ?: it.timeContext,
                    preferredMinutes = it.timeOfDay
                )
            }

        val items = (protocols + supplements).sortedWith(
            compareBy<PlannedItem> { it.done }
                .thenBy { preferredDistance(it.preferredMinutes, now) }
                .thenBy(String.CASE_INSENSITIVE_ORDER) { it.title }
        )
        val reminders = upcomingRemindersToday(snapshot, now)
            .filter { profile?.disabledReminderIds?.contains(it.id) != true }
        return DailyPlan(items, reminders, profile?.name)
    }

    fun activeProfile(snapshot: AppSnapshot, now: Long = System.currentTimeMillis()): RoutineProfile? {
        val kind = activeKind(snapshot, now)
        return snapshot.routineProfiles.firstOrNull { it.kind == kind }
    }

    fun activeKind(snapshot: AppSnapshot, now: Long = System.currentTimeMillis()): RoutineProfileKind {
        snapshot.activeRoutineProfileKindRaw.let { raw ->
            RoutineProfileKind.entries.firstOrNull { it.name == raw }?.let { return it }
        }
        val weekday = localDate(now).dayOfWeek.value
        return if (weekday >= 6) RoutineProfileKind.WEEKEND else RoutineProfileKind.WEEKDAY
    }

    fun protocolsScheduledToday(snapshot: AppSnapshot, now: Long = System.currentTimeMillis()): List<ProtocolItem> =
        snapshot.protocols.filter { protocol ->
            isActive(protocol.active, protocol.activationSpans.map { it.start to it.end }, protocol.startDate, protocol.endDate, now) &&
                isScheduledToday(protocol.frequency, emptyList(), now)
        }

    fun supplementsScheduledToday(snapshot: AppSnapshot, now: Long = System.currentTimeMillis()): List<Supplement> =
        snapshot.supplements.filter { supplement ->
            isActive(supplement.active, supplement.activationSpans.map { it.start to it.end }, null, null, now) &&
                isScheduledToday(supplement.frequency, supplement.daysOfWeek ?: emptyList(), now)
        }

    fun upcomingRemindersToday(snapshot: AppSnapshot, now: Long = System.currentTimeMillis()): List<Reminder> {
        val current = java.time.ZonedDateTime.ofInstant(Instant.ofEpochMilli(now), zone).let { it.hour * 60 + it.minute }
        return snapshot.reminders.filter { reminder ->
            reminder.enabled &&
                (reminder.weekdays.isEmpty() || reminder.weekdays.contains(localDate(now).dayOfWeek.value)) &&
                (reminder.hour * 60 + reminder.minute >= current)
        }.sortedWith(compareBy<Reminder> { it.hour * 60 + it.minute }.thenBy(String.CASE_INSENSITIVE_ORDER) { it.title })
    }

    fun isProtocolDoneToday(id: String, snapshot: AppSnapshot, now: Long = System.currentTimeMillis()): Boolean =
        snapshot.protocolCompletions.any { it.protocolId == id && it.completed && sameDay(it.date, now) }

    fun isSupplementTakenToday(id: String, snapshot: AppSnapshot, now: Long = System.currentTimeMillis()): Boolean =
        snapshot.supplementIntakes.any { it.supplementId == id && it.taken && sameDay(it.date, now) }

    fun isScheduledToday(frequency: Frequency, fallbackDays: List<Int>, now: Long): Boolean {
        return when (frequency.kind) {
            FrequencyKind.DAILY, FrequencyKind.TIMES_PER_DAY -> true
            FrequencyKind.WEEKLY -> {
                val days = if (frequency.days.isNotEmpty()) frequency.days else fallbackDays
                days.isEmpty() || days.contains(localDate(now).dayOfWeek.value)
            }
        }
    }

    fun isActive(
        active: Boolean,
        spans: List<Pair<Long, Long?>>,
        startDate: Long?,
        endDate: Long?,
        now: Long
    ): Boolean {
        if (spans.isNotEmpty()) return spans.any { (start, end) -> start <= now && (end == null || now < end) }
        if (!active) return false
        if (startDate != null && now < startDate) return false
        if (endDate != null && now >= endDate) return false
        return true
    }

    fun frequencyLabel(frequency: Frequency): String = when (frequency.kind) {
        FrequencyKind.DAILY -> "Quotidien"
        FrequencyKind.TIMES_PER_DAY -> if (frequency.timesPerDay <= 1) "Quotidien" else "${frequency.timesPerDay}x / jour"
        FrequencyKind.WEEKLY -> {
            val labels = mapOf(1 to "Lun", 2 to "Mar", 3 to "Mer", 4 to "Jeu", 5 to "Ven", 6 to "Sam", 7 to "Dim")
            frequency.days.mapNotNull { labels[it] }.joinToString(", ").ifBlank { "Hebdomadaire" }
        }
    }

    fun preferredMinutes(hour: Int?, minute: Int?): Int? =
        if (hour == null || minute == null) null else hour * 60 + minute

    private fun preferredDistance(preferred: Int?, now: Long): Int {
        val current = java.time.ZonedDateTime.ofInstant(Instant.ofEpochMilli(now), zone).let { it.hour * 60 + it.minute }
        return preferred?.let { kotlin.math.abs(it - current) } ?: Int.MAX_VALUE - 1
    }

    fun localDate(timestamp: Long): LocalDate = Instant.ofEpochMilli(timestamp).atZone(zone).toLocalDate()

    fun sameDay(left: Long, right: Long): Boolean = localDate(left) == localDate(right)
}

package com.fabienlopes.biotrack

import com.fabienlopes.biotrack.domain.Statistics
import com.fabienlopes.biotrack.data.AppSnapshot
import com.fabienlopes.biotrack.data.Metric
import com.fabienlopes.biotrack.data.MetricEntry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId

class StatisticsTest {
    @Test
    fun pearsonAndSpearmanAgreeForMonotonicSeries() {
        val x = listOf(1.0, 2.0, 3.0, 4.0, 5.0)
        val y = listOf(2.0, 4.0, 6.0, 8.0, 10.0)
        assertEquals(1.0, Statistics.pearson(x, y)!!, 1e-9)
        assertEquals(1.0, Statistics.spearman(x, y)!!, 1e-9)
    }

    @Test
    fun robustScoresLimitOutlierInfluence() {
        val scores = Statistics.robustStandardScores(listOf(10.0, 11.0, 12.0, 1000.0))
        assertEquals(4, scores.size)
        assertTrue(scores.all { it in -3.0..3.0 })
    }

    @Test
    fun chartSeriesAggregatesEntriesByDayAndKeepsGaps() {
        val zone = ZoneId.systemDefault()
        val end = LocalDate.of(2026, 8, 2)
        val metric = Metric(id = "metric", name = "Énergie")
        val entries = listOf(
            MetricEntry(metricId = metric.id, date = end.minusDays(2).atStartOfDay(zone).toInstant().toEpochMilli(), value = 1.0),
            MetricEntry(metricId = metric.id, date = end.minusDays(2).atTime(12, 0).atZone(zone).toInstant().toEpochMilli(), value = 3.0),
            MetricEntry(metricId = metric.id, date = end.atStartOfDay(zone).toInstant().toEpochMilli(), value = 5.0)
        )
        val points = Statistics.chartSeries(AppSnapshot(metrics = listOf(metric), metricEntries = entries), metric.id, days = 7, now = end.atStartOfDay(zone).toInstant().toEpochMilli())

        assertEquals(2, points.size)
        assertEquals(2.0, points.first().value, 1e-9)
        assertTrue(points.last().day - points.first().day > 24 * 60 * 60 * 1000L)
    }

    @Test
    fun correlationRequiresTwelveAlignedDaysByDefault() {
        val zone = ZoneId.systemDefault()
        val end = LocalDate.of(2026, 8, 2)
        val metricA = Metric(id = "a", name = "A")
        val metricB = Metric(id = "b", name = "B")
        val values = listOf(95.0, 30.0, 81.0, 23.0, 79.0, 70.0, 69.0, 87.0, 88.0, 37.0, 18.0, 6.0)
        val entries = (0 until 12).flatMap { index ->
            val date = end.minusDays((11 - index).toLong()).atStartOfDay(zone).toInstant().toEpochMilli()
            val value = values[index]
            listOf(
                MetricEntry(metricId = metricA.id, date = date, value = value),
                MetricEntry(metricId = metricB.id, date = date, value = value)
            )
        }
        val snapshot = AppSnapshot(metrics = listOf(metricA, metricB), metricEntries = entries)
        val now = end.atStartOfDay(zone).toInstant().toEpochMilli()

        val insights = Statistics.generateInsights(snapshot, lags = listOf(0), now = now)
        assertEquals(1, insights.size)
        assertEquals(12, insights.single().sampleSize)

        val shortSnapshot = snapshot.copy(metricEntries = entries.filter { it.date != end.minusDays(1).atStartOfDay(zone).toInstant().toEpochMilli() })
        assertTrue(Statistics.generateInsights(shortSnapshot, lags = listOf(0), now = now).isEmpty())
    }
}

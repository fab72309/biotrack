package com.fabienlopes.biotrack

import com.fabienlopes.biotrack.domain.Statistics
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

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
}

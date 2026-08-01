package com.fabienlopes.biotrack

import com.fabienlopes.biotrack.data.AppSnapshot
import com.fabienlopes.biotrack.data.ProtocolItem
import com.fabienlopes.biotrack.data.Supplement
import com.fabienlopes.biotrack.domain.Planner
import org.junit.Assert.assertEquals
import org.junit.Test

class PlannerTest {
    @Test
    fun dailyPlanIncludesActiveProtocolAndSupplement() {
        val protocol = ProtocolItem(name = "Routine")
        val supplement = Supplement(name = "Suivi")
        val plan = Planner.plan(AppSnapshot(protocols = listOf(protocol), supplements = listOf(supplement)))
        assertEquals(2, plan.total)
        assertEquals(0, plan.done)
    }
}

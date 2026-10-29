package com.example.kidguard

import org.junit.Assert.*
import org.junit.Test

class GuardRulesTest {
    private val day = "2026-10-29"
    @Test fun totalLimitBlocksAtExactBoundary() {
        val rule = GuardRule("TOTAL", null, 2, 0, day)
        assertFalse(GuardRules.exceeded(rule, day, mapOf("app" to 119L)))
        assertTrue(GuardRules.exceeded(rule, day, mapOf("app" to 120L)))
    }
    @Test fun appLimitOnlyCountsThatApp() {
        val rule = GuardRule("APP", "video", 1, 0, day)
        assertFalse(GuardRules.exceeded(rule, day, mapOf("video" to 59L, "browser" to 600L)))
        assertTrue(GuardRules.exceeded(rule, day, mapOf("video" to 60L)))
    }
    @Test fun approvedExtraTimeUnlocksUntilItsNewBoundary() {
        val rule = GuardRule("TOTAL", null, 1, 2, day)
        assertFalse(GuardRules.exceeded(rule, day, mapOf("app" to 60L)))
        assertTrue(GuardRules.exceeded(rule, day, mapOf("app" to 180L)))
        assertTrue(GuardRules.exceeded(rule, "2026-10-30", mapOf("app" to 60L)))
    }
    @Test fun timelineClipsMidnightAndDoesNotCountScreenOffTime() {
        val events = listOf(ForegroundEvent(-1000, "video", 1), ForegroundEvent(10000, "video", 2),
            ForegroundEvent(10000, "browser", 1), ForegroundEvent(25000, "android", 16))
        assertEquals(mapOf("video" to 10L, "browser" to 15L), UsageTimeline.aggregate(events, 0, 60000, emptySet()))
    }
    @Test fun resumedAppSwitchNeverDoubleCountsAndIgnoresOwnScreen() {
        val events = listOf(ForegroundEvent(0, "video", 1), ForegroundEvent(10000, "browser", 1),
            ForegroundEvent(11000, "video", 2), ForegroundEvent(20000, "kidguard", 1))
        assertEquals(mapOf("video" to 10L, "browser" to 10L), UsageTimeline.aggregate(events, 0, 60000, setOf("kidguard")))
    }
}

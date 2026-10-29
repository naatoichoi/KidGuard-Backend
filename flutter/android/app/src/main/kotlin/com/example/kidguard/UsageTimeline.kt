package com.example.kidguard

data class ForegroundEvent(val time: Long, val packageName: String, val type: Int)

/** Single foreground timeline, clipped to the reporting day. No overlapping usage buckets. */
object UsageTimeline {
    fun aggregate(events: List<ForegroundEvent>, start: Long, end: Long,
                  excluded: Set<String>): Map<String, Long> {
        val millis = mutableMapOf<String, Long>()
        var foreground: String? = null
        var since = start
        fun finish(at: Long) {
            val pkg = foreground ?: return
            if (pkg !in excluded && at > start) {
                val duration = (at.coerceAtMost(end) - since.coerceAtLeast(start)).coerceAtLeast(0)
                millis[pkg] = (millis[pkg] ?: 0) + duration
            }
        }
        for (event in events.sortedBy { it.time }) {
            if (event.time > end) break
            when (event.type) {
                1 -> if (foreground != event.packageName) {
                    finish(event.time); foreground = event.packageName; since = event.time
                }
                2 -> if (foreground == event.packageName) { finish(event.time); foreground = null }
                16, 26 -> { finish(event.time); foreground = null }
            }
        }
        finish(end)
        return millis.mapValues { it.value / 1000 }.filterValues { it > 0 }
    }
}

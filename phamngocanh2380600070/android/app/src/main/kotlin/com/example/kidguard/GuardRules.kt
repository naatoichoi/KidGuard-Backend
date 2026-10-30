package com.example.kidguard

data class GuardRule(val type: String, val packageName: String?, val baseMinutes: Long,
                     val extraMinutes: Long, val date: String)

object GuardRules {
    /** Equality must block too. Extra time expires at UTC midnight. */
    fun exceeded(rule: GuardRule, day: String, usage: Map<String, Long>): Boolean {
        val extra = if (rule.date == day) rule.extraMinutes else 0
        val allowance = (rule.baseMinutes + extra).coerceAtLeast(0) * 60
        val used = if (rule.type == "TOTAL") usage.values.sum() else usage[rule.packageName] ?: 0
        return used >= allowance
    }
}

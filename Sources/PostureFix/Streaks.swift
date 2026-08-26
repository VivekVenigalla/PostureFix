import Foundation

enum StreakQualifier {
    ///A day only counts toward a streak if there's enough tracked time to be meaningful.
    static let minTrackedSeconds: TimeInterval = 10 * 60
    static let minGoodFraction: Double = 0.7

    static func qualifies(_ stats: DailyStats) -> Bool {
        stats.totalSeconds >= minTrackedSeconds && stats.goodFraction >= minGoodFraction
    }
}

enum StreakCalculator {
    ///`today` is passed in live (rather than read from disk) since it may not be saved yet.
    static func currentStreak(today: DailyStats, asOf: Date = Date()) -> Int {
        let calendar = Calendar.current
        var streak = StreakQualifier.qualifies(today) ? 1 : 0
        var day = calendar.date(byAdding: .day, value: -1, to: asOf) ?? asOf

        while true {
            let stats = StatsStore.load(for: day)
            guard StreakQualifier.qualifies(stats) else { break }
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    static func longestStreak(today: DailyStats, lookbackDays: Int = 90, asOf: Date = Date()) -> Int {
        let history = StatsStore.loadLastDays(lookbackDays, endingAt: asOf)
        var longest = 0
        var running = 0
        for (index, entry) in history.enumerated() {
            let stats = (index == history.count - 1) ? today : entry.stats
            if StreakQualifier.qualifies(stats) {
                running += 1
                longest = max(longest, running)
            } else {
                running = 0
            }
        }
        return longest
    }
}

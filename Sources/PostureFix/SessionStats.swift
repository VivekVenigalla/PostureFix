import Foundation

struct DailyStats: Codable {
    var goodSeconds: TimeInterval = 0
    var badSeconds: TimeInterval = 0

    var totalSeconds: TimeInterval { goodSeconds + badSeconds }

    var goodFraction: Double {
        guard totalSeconds > 0 else { return 0 }
        return goodSeconds / totalSeconds
    }
}

enum StatsStore {
    private static let keyPrefix = "com.posturefix.stats."

    private static func key(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return keyPrefix + formatter.string(from: date)
    }

    static func load(for date: Date) -> DailyStats {
        guard let data = UserDefaults.standard.data(forKey: key(for: date)),
              let stats = try? JSONDecoder().decode(DailyStats.self, from: data) else {
            return DailyStats()
        }
        return stats
    }

    static func save(_ stats: DailyStats, for date: Date) {
        guard let data = try? JSONEncoder().encode(stats) else { return }
        UserDefaults.standard.set(data, forKey: key(for: date))
    }

    ///Oldest day first.
    static func loadLastDays(_ count: Int, endingAt endDate: Date = Date()) -> [(date: Date, stats: DailyStats)] {
        let calendar = Calendar.current
        return (0..<count).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: endDate) else { return nil }
            return (day, load(for: day))
        }
    }
}

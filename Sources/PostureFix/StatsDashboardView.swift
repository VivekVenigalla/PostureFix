import SwiftUI
import Charts

private struct DayBar: Identifiable {
    let id: Date
    let label: String
    let goodMinutes: Double
    let badMinutes: Double
}

struct StatsDashboardView: View {
    @EnvironmentObject private var appState: AppState

    private var days: [DayBar] {
        StatsStore.loadLastDays(7).map { entry in
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return DayBar(
                id: entry.date,
                label: formatter.string(from: entry.date),
                goodMinutes: entry.stats.goodSeconds / 60,
                badMinutes: entry.stats.badSeconds / 60
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Posture")
                .font(.title2.bold())

            streakRow

            Chart {
                ForEach(days) { day in
                    BarMark(
                        x: .value("Day", day.label),
                        y: .value("Minutes", day.goodMinutes)
                    )
                    .foregroundStyle(.green)
                    .position(by: .value("Kind", "Good"))

                    BarMark(
                        x: .value("Day", day.label),
                        y: .value("Minutes", day.badMinutes)
                    )
                    .foregroundStyle(.orange)
                    .position(by: .value("Kind", "Slouching"))
                }
            }
            .frame(height: 220)

            HStack(spacing: 16) {
                Label("Good", systemImage: "circle.fill")
                    .foregroundStyle(.green)
                Label("Slouching", systemImage: "circle.fill")
                    .foregroundStyle(.orange)
            }
            .font(.caption)

            Divider()

            let today = days.last
            if let today, today.goodMinutes + today.badMinutes > 0 {
                let pct = Int(100 * today.goodMinutes / (today.goodMinutes + today.badMinutes))
                Text("Today: \(pct)% good posture")
                    .font(.headline)
            } else {
                Text("No data recorded today yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Text("Last 28 Days")
                .font(.headline)
            historyGrid

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 420, minHeight: 520)
    }

    private var streakRow: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading) {
                Text("\(appState.currentStreak)")
                    .font(.system(size: 28, weight: .bold))
                Text("day streak")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading) {
                Text("\(appState.longestStreak)")
                    .font(.system(size: 28, weight: .bold))
                Text("best streak")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var historyGrid: some View {
        let history = StatsStore.loadLastDays(28)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(history, id: \.date) { entry in
                RoundedRectangle(cornerRadius: 4)
                    .fill(historyColor(for: entry.stats))
                    .frame(height: 24)
                    .help(entry.date.formatted(date: .abbreviated, time: .omitted))
            }
        }
    }

    private func historyColor(for stats: DailyStats) -> Color {
        guard stats.totalSeconds > 0 else { return Color.gray.opacity(0.15) }
        return StreakQualifier.qualifies(stats)
            ? Color.green.opacity(0.7 + 0.3 * stats.goodFraction)
            : Color.orange.opacity(0.5 + 0.5 * (1 - stats.goodFraction))
    }
}

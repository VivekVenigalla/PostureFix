import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var camera: CameraManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PostureFix")
                .font(.headline)

            statusRow

            Toggle("Monitoring", isOn: $appState.isMonitoring)
                .toggleStyle(.switch)

            Text("⌥⇧P stops monitoring instantly, anytime")
                .font(.caption2)
                .foregroundStyle(.secondary)

            cameraStatusRow
            detectionDebugRow

            Divider()

            calibrationSection

            Divider()

            todayStatsRow

            Button("View weekly stats…") {
                openWindow(id: "stats")
                NSApp.activate(ignoringOtherApps: true)
            }

            snoozeSection

            Divider()

            Button("Settings…") {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }

            Button("Show Welcome Tour…") {
                openWindow(id: "onboarding")
                NSApp.activate(ignoringOtherApps: true)
            }

            Button("Quit PostureFix") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(16)
        .frame(width: 240)
    }

    private var statusRow: some View {
        HStack {
            Circle()
                .fill(color(for: appState.postureStatus))
                .frame(width: 10, height: 10)
            Text(label(for: appState.postureStatus))
                .foregroundStyle(.secondary)
        }
    }

    private func label(for status: PostureStatus) -> String {
        switch status {
        case .unknown: return "Not monitoring"
        case .good: return "Good posture"
        case .slouching: return "Slouching"
        }
    }

    private var cameraStatusRow: some View {
        Group {
            switch camera.authState {
            case .notDetermined:
                Text("Camera access not yet requested")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .denied:
                VStack(alignment: .leading, spacing: 4) {
                    Label("Camera access denied", systemImage: "video.slash.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Button("Open System Settings…") {
                        SystemSettings.openCameraPrivacy()
                    }
                    .font(.caption)
                }
            case .authorized:
                Text(camera.isRunning ? "Camera running · \(camera.frameCount) frames" : "Camera idle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var detectionDebugRow: some View {
        if camera.isRunning {
            if appState.faceDetected, let sample = appState.latestSample {
                Text(String(format: "face y=%.2f h=%.2f roll=%.2f", sample.faceCenterY, sample.faceHeight, sample.roll))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("No face detected")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var calibrationSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if appState.isCalibrating {
                ProgressView(value: appState.calibrationProgress)
                Text("Hold your normal sitting posture…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Cancel") { appState.cancelCalibration() }
            } else {
                Text(appState.baseline == nil ? "No baseline set" : "Baseline calibrated")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(appState.baseline == nil ? "Calibrate good posture" : "Recalibrate") {
                    appState.beginCalibration()
                }
                .disabled(!camera.isRunning)
                if appState.baseline != nil {
                    Button("Reset baseline") { appState.resetCalibration() }
                }
            }
        }
    }

    private var todayStatsRow: some View {
        let stats = appState.todayStats
        return VStack(alignment: .leading, spacing: 2) {
            Text("Today")
                .font(.caption.bold())
            if stats.totalSeconds > 0 {
                Text("\(formatted(stats.goodSeconds)) good · \(formatted(stats.badSeconds)) slouching")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(Int(stats.goodFraction * 100))% good posture")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No data yet today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var snoozeSection: some View {
        if let until = appState.snoozedUntil, until > Date() {
            HStack {
                Text("Snoozed until \(until.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Cancel") { appState.cancelSnooze() }
            }
        } else if appState.isMonitoring {
            Menu("Snooze alerts") {
                Button("15 minutes") { appState.snooze(minutes: 15) }
                Button("30 minutes") { appState.snooze(minutes: 30) }
                Button("1 hour") { appState.snooze(minutes: 60) }
            }
        }
    }

    private func formatted(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return minutes > 0 ? "\(minutes)m \(secs)s" : "\(secs)s"
    }

    private func color(for status: PostureStatus) -> Color {
        switch status {
        case .unknown: return .gray
        case .good: return .green
        case .slouching: return .orange
        }
    }
}

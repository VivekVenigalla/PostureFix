import Foundation
import Combine
import AppKit

enum PostureStatus {
    case unknown
    case good
    case slouching

    var menuBarSymbolName: String {
        switch self {
        case .unknown: return "figure.stand"
        case .good: return "figure.stand"
        case .slouching: return "exclamationmark.triangle.fill"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var postureStatus: PostureStatus = .unknown
    @Published var isMonitoring: Bool = false {
        didSet {
            guard isMonitoring != oldValue else { return }
            if isMonitoring {
                camera.start()
                NotificationManager.requestAuthorization()
            } else {
                camera.stop()
                slouchStartedAt = nil
                lastSampleAt = nil
                todayStats = todayStatsAccumulator
                StatsStore.save(todayStatsAccumulator, for: Date())
            }
        }
    }

    @Published var latestSample: PostureSample?
    @Published var faceDetected: Bool = false
    @Published private(set) var baseline: PostureBaseline?
    @Published private(set) var isCalibrating: Bool = false
    @Published private(set) var calibrationProgress: Double = 0

    let camera = CameraManager()
    private let detector = PostureDetector()

    private var calibrationSamples: [PostureSample] = []
    private var calibrationTask: Task<Void, Never>?
    private static let calibrationDuration: TimeInterval = 2.0

    private var slouchStartedAt: Date?
    private var lastAlertAt: Date?
    private static let slouchGracePeriod: TimeInterval = 8

    @Published private(set) var todayStats: DailyStats = StatsStore.load(for: Date())
    private var todayStatsAccumulator: DailyStats = StatsStore.load(for: Date())
    private var lastSampleAt: Date?
    private var statsSaveCounter: Int = 0
    private var lastUIRefreshAt: Date = .distantPast
    private static let uiRefreshInterval: TimeInterval = 0.3

    @Published var settings: AppSettings = SettingsStore.load() {
        didSet {
            guard settings != oldValue else { return }
            SettingsStore.save(settings)
            LaunchAtLogin.set(settings.launchAtLogin)
        }
    }
    @Published private(set) var snoozedUntil: Date?

    @Published var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "com.posturefix.onboarded") {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "com.posturefix.onboarded")
        }
    }

    var menuBarSymbolName: String {
        postureStatus.menuBarSymbolName
    }

    var currentStreak: Int {
        StreakCalculator.currentStreak(today: todayStats)
    }

    var longestStreak: Int {
        StreakCalculator.longestStreak(today: todayStats)
    }

    init() {
        baseline = BaselineStore.load()

        camera.onFrame = { [weak self] pixelBuffer in
            guard let self else { return }
            let result = self.detector.process(pixelBuffer)
            Task { @MainActor in
                self.handle(result)
            }
        }

        EmergencyHotkey.install { [weak self] in
            Task { @MainActor in
                self?.emergencyStop()
            }
        }
    }

    ///Option+Shift+P. Guaranteed way to kill the camera even if the menu bar
    ///icon is unreachable (macOS can push it into the overflow area when it
    ///inserts its own Video Effects item for an active camera).
    func emergencyStop() {
        isMonitoring = false
        NSSound.beep()
    }

    private func handle(_ result: PostureDetectionResult) {
        //Vision runs on every camera frame, but SwiftUI/AppKit churn hard if we
        //republish @Published state at that rate (it was flooding the menu bar
        //item's scene updates and making the icon flicker/vanish). Everything
        //that only feeds debug UI is throttled to a fixed cadence below; state
        //that actually drives behavior (classification, alerts) still runs
        //every frame but only publishes when the value changes.
        let now = Date()
        let shouldRefreshUI = now.timeIntervalSince(lastUIRefreshAt) >= Self.uiRefreshInterval

        switch result {
        case .noFaceDetected:
            if shouldRefreshUI {
                lastUIRefreshAt = now
                if faceDetected != false { faceDetected = false }
            }
        case .sample(let sample):
            if shouldRefreshUI {
                lastUIRefreshAt = now
                if faceDetected != true { faceDetected = true }
                latestSample = sample
                todayStats = todayStatsAccumulator
            }

            if isCalibrating {
                calibrationSamples.append(sample)
            } else if let baseline {
                if let snoozedUntil, snoozedUntil > Date() {
                    return
                } else if snoozedUntil != nil {
                    self.snoozedUntil = nil
                }
                let raw = PostureThreshold.classify(sample, against: baseline, sensitivity: settings.sensitivity)
                trackTime(for: raw)
                applyClassification(raw)
            }
        }
    }

    private func trackTime(for raw: PostureStatus) {
        defer { lastSampleAt = Date() }
        guard let last = lastSampleAt else { return }

        let elapsed = min(Date().timeIntervalSince(last), 2.0)
        switch raw {
        case .good: todayStatsAccumulator.goodSeconds += elapsed
        case .slouching: todayStatsAccumulator.badSeconds += elapsed
        case .unknown: break
        }

        statsSaveCounter += 1
        if statsSaveCounter >= 20 {
            statsSaveCounter = 0
            StatsStore.save(todayStatsAccumulator, for: Date())
        }
    }

    private func applyClassification(_ raw: PostureStatus) {
        guard raw == .slouching else {
            slouchStartedAt = nil
            if postureStatus != .good { postureStatus = .good }
            return
        }

        let startedAt = slouchStartedAt ?? Date()
        slouchStartedAt = startedAt

        guard Date().timeIntervalSince(startedAt) >= Self.slouchGracePeriod else {
            //Still within the grace period — don't flip the UI yet, avoids
            //flagging brief reaches/turns as slouching.
            return
        }

        if postureStatus != .slouching { postureStatus = .slouching }

        let now = Date()
        let cooldown = max(settings.alertCooldownMinutes, 0) * 60
        if lastAlertAt == nil || now.timeIntervalSince(lastAlertAt!) >= cooldown {
            lastAlertAt = now
            NotificationManager.sendSlouchAlert()
        }
    }

    func snooze(minutes: Double) {
        snoozedUntil = Date().addingTimeInterval(minutes * 60)
        slouchStartedAt = nil
        postureStatus = .good
    }

    func cancelSnooze() {
        snoozedUntil = nil
    }

    func beginCalibration() {
        guard camera.isRunning, !isCalibrating else { return }
        isCalibrating = true
        calibrationSamples = []
        calibrationProgress = 0

        calibrationTask?.cancel()
        calibrationTask = Task { @MainActor in
            let steps = 20
            for step in 1...steps {
                try? await Task.sleep(for: .seconds(Self.calibrationDuration / Double(steps)))
                if Task.isCancelled { return }
                self.calibrationProgress = Double(step) / Double(steps)
            }
            self.finishCalibration()
        }
    }

    func cancelCalibration() {
        calibrationTask?.cancel()
        isCalibrating = false
        calibrationProgress = 0
    }

    func resetCalibration() {
        baseline = nil
        BaselineStore.clear()
        postureStatus = .unknown
    }

    private func finishCalibration() {
        isCalibrating = false
        defer { calibrationSamples = [] }

        guard !calibrationSamples.isEmpty else { return }
        let count = CGFloat(calibrationSamples.count)
        let avgY = calibrationSamples.map(\.faceCenterY).reduce(0, +) / count
        let avgH = calibrationSamples.map(\.faceHeight).reduce(0, +) / count
        let avgRoll = calibrationSamples.map(\.roll).reduce(0, +) / count

        let newBaseline = PostureBaseline(faceCenterY: avgY, faceHeight: avgH, roll: avgRoll)
        baseline = newBaseline
        BaselineStore.save(newBaseline)
        postureStatus = .good
        slouchStartedAt = nil
        lastAlertAt = nil
    }
}

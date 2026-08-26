import SwiftUI

private enum OnboardingStep: Int, CaseIterable {
    case welcome
    case cameraPermission
    case calibration
    case done
}

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var camera: CameraManager
    @Environment(\.dismiss) private var dismiss
    @State private var step: OnboardingStep = .welcome

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            content

            Spacer()

            HStack {
                ForEach(OnboardingStep.allCases, id: \.self) { s in
                    Circle()
                        .fill(s == step ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .padding(32)
        .frame(minWidth: 460, minHeight: 400)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            welcomeStep
        case .cameraPermission:
            cameraStep
        case .calibration:
            calibrationStep
        case .done:
            doneStep
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.stand")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Welcome to PostureFix")
                .font(.title.bold())
            Text("PostureFix watches your posture through your webcam and gently nudges you when you slouch. Nothing is recorded or sent anywhere — all processing happens on your Mac.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 360)
            Button("Get Started") { step = .cameraPermission }
                .buttonStyle(.borderedProminent)
        }
    }

    private var cameraStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
            Text("Enable Camera Access")
                .font(.title2.bold())
            Text("PostureFix needs your camera to see your posture. You'll get a system prompt — click Allow.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 360)
            Text("Remember: ⌥⇧P stops monitoring and turns off the camera instantly, from anywhere.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            switch camera.authState {
            case .notDetermined:
                Button("Enable Camera") {
                    appState.isMonitoring = true
                }
                .buttonStyle(.borderedProminent)
            case .denied:
                Label("Camera access denied", systemImage: "video.slash.fill")
                    .foregroundStyle(.red)
                Text("PostureFix can't see your posture without camera access. Enable it in System Settings, then come back here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
                HStack {
                    Button("Open System Settings…") {
                        SystemSettings.openCameraPrivacy()
                    }
                    .buttonStyle(.borderedProminent)
                    Button("I've enabled it") {
                        camera.refreshAuthState()
                    }
                }
            case .authorized:
                Label("Camera enabled", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Button("Continue") { step = .calibration }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var calibrationStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.rectangle")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
            Text("Calibrate Your Good Posture")
                .font(.title2.bold())
            Text("Sit the way you normally would with good posture, then hold still for a couple of seconds.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 360)

            if appState.isCalibrating {
                ProgressView(value: appState.calibrationProgress)
                    .frame(width: 220)
            } else if appState.baseline != nil {
                Label("Baseline captured", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Button("Continue") { step = .done }
                    .buttonStyle(.borderedProminent)
                Button("Recalibrate") { appState.beginCalibration() }
            } else {
                Button("Start Calibration") { appState.beginCalibration() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!camera.isRunning)
            }
        }
    }

    private var doneStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("You're all set")
                .font(.title.bold())
            Text("PostureFix is running in your menu bar. Click the icon anytime to check your stats, calibrate again, or change settings.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 360)
            Button("Finish") {
                appState.hasCompletedOnboarding = true
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

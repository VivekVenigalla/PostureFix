import Foundation
import CoreGraphics

struct PostureBaseline: Codable {
    let faceCenterY: CGFloat
    let faceHeight: CGFloat
    let roll: CGFloat
}

enum PostureThreshold {
    ///How far the face can drop (normalized frame height) before it counts as slouching.
    static let centerYDrop: CGFloat = 0.05
    ///How much closer the face can get (normalized) before it counts as leaning in.
    static let heightGrow: CGFloat = 0.025
    ///How much head tilt (radians) before it counts as slouching.
    static let rollDeviation: CGFloat = 0.25

    ///Scales thresholds by sensitivity: 0 = 1.5x as tolerant, 1 = 0.5x as tolerant.
    static func multiplier(forSensitivity sensitivity: Double) -> CGFloat {
        CGFloat(1.5 - sensitivity)
    }

    static func classify(_ sample: PostureSample, against baseline: PostureBaseline, sensitivity: Double = 0.5) -> PostureStatus {
        let scale = multiplier(forSensitivity: sensitivity)
        let centerYDelta = sample.faceCenterY - baseline.faceCenterY
        let heightDelta = sample.faceHeight - baseline.faceHeight
        let rollDelta = abs(sample.roll - baseline.roll)

        if centerYDelta > centerYDrop * scale || heightDelta > heightGrow * scale || rollDelta > rollDeviation * scale {
            return .slouching
        }
        return .good
    }
}

enum BaselineStore {
    private static let key = "com.posturefix.baseline"

    static func load() -> PostureBaseline? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PostureBaseline.self, from: data)
    }

    static func save(_ baseline: PostureBaseline) {
        guard let data = try? JSONEncoder().encode(baseline) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

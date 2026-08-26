import Vision
import CoreGraphics

struct PostureSample {
    ///Normalized vertical position of the face center in the frame (0 = top, 1 = bottom).
    let faceCenterY: CGFloat
    ///Normalized face height (a proxy for how close/forward the head is).
    let faceHeight: CGFloat
    ///Roll of the head, radians (tilt).
    let roll: CGFloat
}

enum PostureDetectionResult {
    case noFaceDetected
    case sample(PostureSample)
}

///Runs Vision face-landmark detection on camera frames and reduces it to a small
///posture-relevant signal. Calibration (Phase 4) turns this into a good/bad judgment.
final class PostureDetector {
    private let sequenceHandler = VNSequenceRequestHandler()

    func process(_ pixelBuffer: CVPixelBuffer) -> PostureDetectionResult {
        let request = VNDetectFaceRectanglesRequest()
        do {
            try sequenceHandler.perform([request], on: pixelBuffer, orientation: .up)
        } catch {
            return .noFaceDetected
        }

        guard let face = request.results?.first as? VNFaceObservation else {
            return .noFaceDetected
        }

        let box = face.boundingBox //normalized, origin bottom-left
        let centerY = 1 - (box.origin.y + box.height / 2) //flip so 0 = top of frame
        let roll = CGFloat(truncating: face.roll ?? 0)

        let sample = PostureSample(
            faceCenterY: centerY,
            faceHeight: box.height,
            roll: roll
        )
        return .sample(sample)
    }
}

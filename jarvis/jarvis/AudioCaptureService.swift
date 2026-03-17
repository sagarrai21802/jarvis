import AVFoundation
import Foundation

final class AudioCaptureService {
    enum CaptureError: Error {
        case microphonePermissionDenied
        case alreadyCapturing
    }

    private let audioEngine = AVAudioEngine()
    private var capturedData = Data()
    private(set) var isCapturing = false

    func startCapture() throws {
        guard !isCapturing else { throw CaptureError.alreadyCapturing }

        let micPermission = AVCaptureDevice.authorizationStatus(for: .audio)
        guard micPermission != .denied && micPermission != .restricted else {
            throw CaptureError.microphonePermissionDenied
        }

        capturedData.removeAll(keepingCapacity: true)

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            self.appendBufferData(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isCapturing = true
    }

    func stopCapture() -> Data {
        guard isCapturing else { return Data() }

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)

        audioEngine.stop()
        isCapturing = false

        return capturedData
    }

    private func appendBufferData(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let frameCount = Int(buffer.frameLength)
        let channel = channelData[0]
        let samples = UnsafeBufferPointer(start: channel, count: frameCount)

        // Temporary float32 PCM payload. We can normalize to 16kHz int16 in the integration step.
        let bytes = Data(buffer: samples)
        capturedData.append(bytes)
    }
}

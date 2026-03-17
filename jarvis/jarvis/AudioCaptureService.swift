import AVFoundation
import Foundation

final class AudioCaptureService {
    enum CaptureError: Error {
        case microphonePermissionDenied
        case alreadyCapturing
        case audioFormatUnavailable
    }

    struct CapturedAudio {
        let pcm16Mono16k: Data
        let wavData: Data
    }

    private let audioEngine = AVAudioEngine()
    private var capturedPCM16Data = Data()
    private var converter: AVAudioConverter?
    private var targetFormat: AVAudioFormat?
    private(set) var isCapturing = false

    func ensureMicrophonePermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    func startCapture() throws {
        guard !isCapturing else { throw CaptureError.alreadyCapturing }

        let micPermission = AVCaptureDevice.authorizationStatus(for: .audio)
        guard micPermission != .denied && micPermission != .restricted else {
            throw CaptureError.microphonePermissionDenied
        }

        capturedPCM16Data.removeAll(keepingCapacity: true)

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true)

        guard let outputFormat else {
            throw CaptureError.audioFormatUnavailable
        }

        converter = AVAudioConverter(from: inputFormat, to: outputFormat)
        targetFormat = outputFormat

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            self.appendConvertedPCM16(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isCapturing = true
    }

    func stopCapture() -> CapturedAudio {
        guard isCapturing else {
            return CapturedAudio(pcm16Mono16k: Data(), wavData: Data())
        }

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)

        audioEngine.stop()
        isCapturing = false
        converter = nil

        let wavData = buildWAVData(fromPCM16: capturedPCM16Data, sampleRate: 16_000, channels: 1)
        return CapturedAudio(pcm16Mono16k: capturedPCM16Data, wavData: wavData)
    }

    private func appendConvertedPCM16(_ buffer: AVAudioPCMBuffer) {
        guard let converter, let targetFormat else { return }

        let outputFrameCapacity = AVAudioFrameCount((Double(buffer.frameLength) * targetFormat.sampleRate / buffer.format.sampleRate) + 1)
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCapacity) else {
            return
        }

        var hasProvidedInput = false
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if hasProvidedInput {
                outStatus.pointee = .noDataNow
                return nil
            }

            hasProvidedInput = true
            outStatus.pointee = .haveData
            return buffer
        }

        var conversionError: NSError?
        converter.convert(to: convertedBuffer, error: &conversionError, withInputFrom: inputBlock)

        if conversionError != nil {
            return
        }

        guard let channelData = convertedBuffer.int16ChannelData else { return }
        let frameCount = Int(convertedBuffer.frameLength)
        let samples = UnsafeBufferPointer(start: channelData[0], count: frameCount)

        capturedPCM16Data.append(Data(buffer: samples))
    }

    private func buildWAVData(fromPCM16 pcmData: Data, sampleRate: Int, channels: Int) -> Data {
        let bitsPerSample = 16
        let byteRate = sampleRate * channels * bitsPerSample / 8
        let blockAlign = channels * bitsPerSample / 8
        let dataSize = pcmData.count
        let riffChunkSize = 36 + dataSize

        var header = Data()
        header.append("RIFF".data(using: .ascii)!)
        header.append(UInt32(riffChunkSize).littleEndianData)
        header.append("WAVE".data(using: .ascii)!)
        header.append("fmt ".data(using: .ascii)!)
        header.append(UInt32(16).littleEndianData)
        header.append(UInt16(1).littleEndianData)
        header.append(UInt16(channels).littleEndianData)
        header.append(UInt32(sampleRate).littleEndianData)
        header.append(UInt32(byteRate).littleEndianData)
        header.append(UInt16(blockAlign).littleEndianData)
        header.append(UInt16(bitsPerSample).littleEndianData)
        header.append("data".data(using: .ascii)!)
        header.append(UInt32(dataSize).littleEndianData)

        return header + pcmData
    }
}

extension AudioCaptureService.CaptureError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone permission is denied."
        case .alreadyCapturing:
            return "Audio capture is already active."
        case .audioFormatUnavailable:
            return "Audio format setup failed."
        }
    }
}

private extension FixedWidthInteger {
    var littleEndianData: Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<Self>.size)
    }
}

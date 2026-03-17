import Foundation
import WhisperKit

final class WhisperService {
    enum WhisperServiceError: Error {
        case modelNotReady
        case transcriptionFailed
    }

    private(set) var isModelReady = false
    private var whisperKit: WhisperKit?

    func prepareModelIfNeeded() async throws {
        if isModelReady {
            return
        }

        // First launch may download the default on-device model.
        whisperKit = try await WhisperKit()
        isModelReady = true
    }

    func transcribe(audioData: Data) async throws -> String {
        guard isModelReady, let whisperKit else {
            throw WhisperServiceError.modelNotReady
        }

        if audioData.isEmpty {
            return ""
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("jarvis_dictation_\(UUID().uuidString).wav")

        try audioData.write(to: tempURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let results = try await whisperKit.transcribe(audioPath: tempURL.path)
        let mergedText = results
            .map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        guard !mergedText.isEmpty else {
            throw WhisperServiceError.transcriptionFailed
        }

        return mergedText
    }
}

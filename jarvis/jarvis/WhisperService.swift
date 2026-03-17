import Foundation

final class WhisperService {
    enum WhisperServiceError: Error {
        case modelNotReady
    }

    private(set) var isModelReady = false

    func prepareModelIfNeeded() async throws {
        if isModelReady {
            return
        }

        // Placeholder hook for WhisperKit first-launch model download and warm-up.
        isModelReady = true
    }

    func transcribe(audioData: Data) async throws -> String {
        guard isModelReady else {
            throw WhisperServiceError.modelNotReady
        }

        if audioData.isEmpty {
            return ""
        }

        // Placeholder output until WhisperKit pipeline is connected in Step 2.
        return ""
    }
}

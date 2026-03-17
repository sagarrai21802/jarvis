import Foundation

final class GeminiLiveService {
    enum GeminiLiveError: Error {
        case missingAPIKey
        case invalidWebSocketURL
        case requestBuildFailed
        case invalidResponse
        case httpError(Int)
    }

    private struct ValidationResponse: Decodable {
        let candidates: [Candidate]?

        struct Candidate: Decodable {
            let content: Content?
        }

        struct Content: Decodable {
            let parts: [Part]?
        }

        struct Part: Decodable {
            let text: String?
        }
    }

    private struct GenerateContentResponse: Decodable {
        let candidates: [Candidate]?

        struct Candidate: Decodable {
            let content: Content?
        }

        struct Content: Decodable {
            let parts: [Part]?
        }

        struct Part: Decodable {
            let text: String?
        }
    }

    private struct TTSResponse: Decodable {
        let candidates: [Candidate]?

        struct Candidate: Decodable {
            let content: Content?
        }

        struct Content: Decodable {
            let parts: [Part]?
        }

        struct Part: Decodable {
            let inlineData: InlineData?
        }

        struct InlineData: Decodable {
            let mimeType: String?
            let data: String?
        }
    }

    private var apiKey: String = ""
    private var webSocketTask: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)

    func configure(apiKey: String) {
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func connectIfNeeded() async throws {
        if webSocketTask != nil {
            return
        }

        guard !apiKey.isEmpty else {
            throw GeminiLiveError.missingAPIKey
        }

        let urlString = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw GeminiLiveError.invalidWebSocketURL
        }

        let task = session.webSocketTask(with: url)
        task.resume()
        webSocketTask = task

        receiveLoop()
    }

    func validateAPIKey() async throws {
        guard !apiKey.isEmpty else {
            throw GeminiLiveError.missingAPIKey
        }

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)") else {
            throw GeminiLiveError.requestBuildFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": "reply with one word: ok"]
                    ]
                ]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiLiveError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw GeminiLiveError.httpError(httpResponse.statusCode)
        }

        _ = try JSONDecoder().decode(ValidationResponse.self, from: data)
    }

    func generateQuickTextResponse(prompt: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw GeminiLiveError.missingAPIKey
        }

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)") else {
            throw GeminiLiveError.requestBuildFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiLiveError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw GeminiLiveError.httpError(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(GenerateContentResponse.self, from: data)
        let firstText = decoded.candidates?.first?.content?.parts?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        return firstText ?? ""
    }

    func generateTalkReplyText(fromWavData wavData: Data) async throws -> String {
        guard !apiKey.isEmpty else {
            throw GeminiLiveError.missingAPIKey
        }

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)") else {
            throw GeminiLiveError.requestBuildFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": "You are Jarvis voice assistant. Listen to this user audio and reply conversationally in 1-3 concise sentences."],
                        [
                            "inline_data": [
                                "mime_type": "audio/wav",
                                "data": wavData.base64EncodedString()
                            ]
                        ]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiLiveError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw GeminiLiveError.httpError(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(GenerateContentResponse.self, from: data)
        let firstText = decoded.candidates?.first?.content?.parts?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        return firstText ?? ""
    }

    func synthesizeSpeechWAV(fromText text: String, voiceName: String = "Kore") async throws -> Data {
        guard !apiKey.isEmpty else {
            throw GeminiLiveError.missingAPIKey
        }

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-tts:generateContent?key=\(apiKey)") else {
            throw GeminiLiveError.requestBuildFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": text]
                    ]
                ]
            ],
            "generationConfig": [
                "responseModalities": ["AUDIO"],
                "speechConfig": [
                    "voiceConfig": [
                        "prebuiltVoiceConfig": [
                            "voiceName": voiceName
                        ]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiLiveError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw GeminiLiveError.httpError(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(TTSResponse.self, from: data)
        let base64PCM = decoded.candidates?.first?.content?.parts?.first?.inlineData?.data ?? ""
        let pcmData = Data(base64Encoded: base64PCM) ?? Data()

        return wrapPCM16AsWAV(pcmData: pcmData, sampleRate: 24_000, channels: 1)
    }

    private func wrapPCM16AsWAV(pcmData: Data, sampleRate: Int, channels: Int) -> Data {
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

    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
    }

    func sendAudioChunk(_ audioData: Data) async throws {
        guard let webSocketTask else {
            return
        }

        if audioData.isEmpty {
            return
        }

        let payload: [String: Any] = [
            "realtimeInput": [
                "mediaChunks": [
                    [
                        "mimeType": "audio/pcm",
                        "data": audioData.base64EncodedString()
                    ]
                ]
            ]
        ]

        let messageData = try JSONSerialization.data(withJSONObject: payload)
        if let messageText = String(data: messageData, encoding: .utf8) {
            try await webSocketTask.send(.string(messageText))
        }
    }

    private func receiveLoop() {
        guard let webSocketTask else { return }

        webSocketTask.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .success:
                self.receiveLoop()
            case .failure:
                self.disconnect()
            }
        }
    }
}

extension GeminiLiveService.GeminiLiveError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Gemini API key is missing."
        case .invalidWebSocketURL:
            return "Gemini websocket URL is invalid."
        case .requestBuildFailed:
            return "Gemini request could not be built."
        case .invalidResponse:
            return "Gemini returned an invalid response."
        case let .httpError(statusCode):
            return "Gemini HTTP error: \(statusCode)."
        }
    }
}

private extension FixedWidthInteger {
    var littleEndianData: Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<Self>.size)
    }
}

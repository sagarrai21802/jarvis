import Foundation
import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    enum AssistantMode: String {
        case idle = "Idle"
        case listening = "Listening"
        case processing = "Processing"
        case speaking = "Speaking"
        case dictating = "Dictating"
        case error = "Error"
    }

    @Published var mode: AssistantMode = .idle
    @Published var statusText: String = "Ready"
    @Published var isHotkeysEnabled: Bool = true {
        didSet {
            hotkeyManager.isEnabled = isHotkeysEnabled
        }
    }
    @Published var apiKey: String = ""
    @Published var isValidatingAPIKey = false
    @Published var isTestingGemini = false
    @Published var settingsMessage = ""

    let hotkeyManager = HotkeyManager()
    let audioCaptureService = AudioCaptureService()
    let geminiLiveService = GeminiLiveService()
    let whisperService = WhisperService()
    let textInjectionService = TextInjectionService()
    private let keychainService = KeychainService()

    private var isTalkCaptureActive = false
    private var isDictationCaptureActive = false

    init() {
        if let persistedAPIKey = try? keychainService.loadAPIKey() {
            apiKey = persistedAPIKey
            geminiLiveService.configure(apiKey: persistedAPIKey)
        }

        configureHotkeys()
        hotkeyManager.start()
    }

    func applyAndValidateGeminiKey() {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            settingsMessage = "Please enter an API key."
            return
        }

        apiKey = trimmedKey
        geminiLiveService.configure(apiKey: trimmedKey)
        isValidatingAPIKey = true
        settingsMessage = "Validating API key..."

        Task {
            do {
                try await geminiLiveService.validateAPIKey()
                try keychainService.saveAPIKey(trimmedKey)
                settingsMessage = "API key saved and validated."
                statusText = "Gemini API key ready"
            } catch {
                settingsMessage = "API key invalid or network error: \(error.localizedDescription)"
            }

            isValidatingAPIKey = false
        }
    }

    func testGeminiTextRequest() {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            settingsMessage = "Please add and validate an API key first."
            return
        }

        geminiLiveService.configure(apiKey: trimmedKey)
        isTestingGemini = true
        settingsMessage = "Sending Gemini test request..."

        Task {
            do {
                let response = try await geminiLiveService.generateQuickTextResponse(prompt: "Reply in 6 words: Jarvis Gemini connection check")
                settingsMessage = response.isEmpty ? "Gemini responded with empty text." : "Gemini test success: \(response)"
                statusText = "Gemini test complete"
            } catch {
                settingsMessage = "Gemini test failed: \(error.localizedDescription)"
            }

            isTestingGemini = false
        }
    }

    func startTalkCapture() {
        guard !isTalkCaptureActive, !isDictationCaptureActive else { return }

        do {
            try audioCaptureService.startCapture()
            isTalkCaptureActive = true
            mode = .listening
            statusText = "Listening for Gemini"
        } catch {
            mode = .error
            statusText = "Mic error: \(error.localizedDescription)"
        }
    }

    func stopTalkCaptureAndSend() {
        guard isTalkCaptureActive else { return }
        isTalkCaptureActive = false

        let capturedAudio = audioCaptureService.stopCapture()
        mode = .processing
        statusText = "Sending to Gemini Live"

        Task {
            do {
                try await geminiLiveService.connectIfNeeded()
                try await geminiLiveService.sendAudioChunk(capturedAudio)
                mode = .speaking
                statusText = "Gemini response incoming"
            } catch {
                mode = .error
                statusText = "Gemini error: \(error.localizedDescription)"
            }

            // Keep UX clear while backend streaming hooks are being added.
            if mode != .error {
                mode = .idle
                statusText = "Ready"
            }
        }
    }

    func startDictationCapture() {
        guard !isTalkCaptureActive, !isDictationCaptureActive else { return }

        do {
            try audioCaptureService.startCapture()
            isDictationCaptureActive = true
            mode = .dictating
            statusText = "Listening for dictation"
        } catch {
            mode = .error
            statusText = "Mic error: \(error.localizedDescription)"
        }
    }

    func stopDictationCaptureAndType() {
        guard isDictationCaptureActive else { return }
        isDictationCaptureActive = false

        let capturedAudio = audioCaptureService.stopCapture()
        mode = .processing
        statusText = "Transcribing locally"

        Task {
            do {
                try await whisperService.prepareModelIfNeeded()
                let text = try await whisperService.transcribe(audioData: capturedAudio)

                if !text.isEmpty {
                    try textInjectionService.typeText(text)
                }

                mode = .idle
                statusText = text.isEmpty ? "No speech detected" : "Typed dictation"
            } catch {
                if case TextInjectionService.TextInjectionError.accessibilityPermissionMissing = error {
                    textInjectionService.requestAccessibilityPermissionPrompt()
                }
                mode = .error
                statusText = "Dictation error: \(error.localizedDescription)"
            }
        }
    }

    private func configureHotkeys() {
        hotkeyManager.onTalkPressDown = { [weak self] in
            Task { @MainActor in
                self?.startTalkCapture()
            }
        }

        hotkeyManager.onTalkPressUp = { [weak self] in
            Task { @MainActor in
                self?.stopTalkCaptureAndSend()
            }
        }

        hotkeyManager.onDictatePressDown = { [weak self] in
            Task { @MainActor in
                self?.startDictationCapture()
            }
        }

        hotkeyManager.onDictatePressUp = { [weak self] in
            Task { @MainActor in
                self?.stopDictationCaptureAndType()
            }
        }
    }
}

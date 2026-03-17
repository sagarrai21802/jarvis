import Foundation
import SwiftUI
import Combine
import AVFoundation
import AppKit

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
    let audioPlaybackService = AudioPlaybackService()
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

    func requestMicrophoneAccess() {
        Task {
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            print("[Jarvis] Current mic permission status: \(status.rawValue) (\(describeMicStatus(status)))")
            
            if status == .authorized {
                settingsMessage = "Microphone permission already granted."
                statusText = "Microphone ready"
                return
            }
            
            if status == .notDetermined {
                print("[Jarvis] Requesting microphone permission...")
                let allowed = await AVCaptureDevice.requestAccess(for: .audio)
                print("[Jarvis] Permission result: \(allowed)")
                
                if allowed {
                    settingsMessage = "Microphone permission granted. Relaunch app to take effect."
                    statusText = "Microphone granted"
                } else {
                    settingsMessage = "Permission request was denied."
                    statusText = "Permission denied"
                }
            } else if status == .denied || status == .restricted {
                settingsMessage = "Microphone access is blocked in System Settings. Enable Jarvis under Privacy & Security > Microphone."
                statusText = "Permission blocked"
                openMicrophonePrivacySettings()
            }
        }
    }

    private func openMicrophonePrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private func describeMicStatus(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "notDetermined"
        case .restricted:
            return "restricted"
        case .denied:
            return "denied"
        case .authorized:
            return "authorized"
        @unknown default:
            return "unknown"
        }
    }

    func startTalkCapture() {
        guard !isTalkCaptureActive, !isDictationCaptureActive else { return }

        Task {
            let isAllowed = await audioCaptureService.ensureMicrophonePermission()
            guard isAllowed else {
                mode = .error
                statusText = "Microphone permission not granted"
                return
            }

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
    }

    func stopTalkCaptureAndSend() {
        guard isTalkCaptureActive else { return }
        isTalkCaptureActive = false

        let capturedAudio = audioCaptureService.stopCapture()
        mode = .processing
        statusText = "Generating Gemini reply"

        Task {
            do {
                let replyText = try await geminiLiveService.generateTalkReplyText(fromWavData: capturedAudio.wavData)
                guard !replyText.isEmpty else {
                    mode = .idle
                    statusText = "Gemini returned empty reply"
                    return
                }

                statusText = "Synthesizing voice reply"
                do {
                    let ttsWavData = try await geminiLiveService.synthesizeSpeechWAV(fromText: replyText)

                    statusText = "Playing Gemini voice"
                    try audioPlaybackService.playWAVData(ttsWavData)
                    mode = .speaking
                    statusText = "Gemini replied"
                } catch {
                    mode = .idle
                    statusText = "Reply ready (voice rate-limited)"
                    settingsMessage = "Gemini reply: \(replyText)"
                }
            } catch {
                mode = .error
                statusText = "Gemini error: \(error.localizedDescription)"
            }
        }
    }

    func startDictationCapture() {
        guard !isTalkCaptureActive, !isDictationCaptureActive else { return }

        Task {
            let isAllowed = await audioCaptureService.ensureMicrophonePermission()
            guard isAllowed else {
                mode = .error
                statusText = "Microphone permission not granted"
                return
            }

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
    }

    func playVoiceSanityCheck() {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            settingsMessage = "Add API key before voice test."
            return
        }

        geminiLiveService.configure(apiKey: trimmedKey)
        mode = .processing
        statusText = "Running voice sanity check"

        Task {
            do {
                let wav = try await geminiLiveService.synthesizeSpeechWAV(fromText: "Jarvis voice check complete.")
                try audioPlaybackService.playWAVData(wav)
                mode = .speaking
                statusText = "Voice test played"
            } catch {
                mode = .error
                statusText = "Voice test failed: \(error.localizedDescription)"
            }
        }
    }

    func stopDictationCaptureAndType() {
        guard isDictationCaptureActive else { return }
        isDictationCaptureActive = false

        let capturedAudio = audioCaptureService.stopCapture()
        mode = .processing
        statusText = "Transcribing with Gemini"

        Task {
            do {
                let text = try await geminiLiveService.generateTranscriptText(fromWavData: capturedAudio.wavData)

                if !text.isEmpty {
                    try textInjectionService.typeText(text)
                }

                mode = .idle
                statusText = text.isEmpty ? "No speech detected" : "Typed dictation"
            } catch {
                if case TextInjectionService.TextInjectionError.accessibilityPermissionMissing = error {
                    textInjectionService.requestAccessibilityPermissionPrompt()
                    settingsMessage = "Accessibility permission is required to paste text. If already enabled, fully quit Jarvis and relaunch from Xcode once."
                    statusText = "Accessibility permission required"
                    mode = .error
                    return
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

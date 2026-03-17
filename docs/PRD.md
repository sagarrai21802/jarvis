This is a structured plan to build your "Gemini Voice Assistant" as a native macOS menu bar app with two global hotkey features: push-to-talk with Gemini Live (audio in/out) and push-to-dictate (voice-to-text pasted into any app). It leverages your Swift/iOS experience, runs locally/offline where possible, and phases delivery for quick wins. [github](https://github.com/jatinkrmalik/vocamac)

## Feature Goals

- **Core app**: Menu bar icon with settings (hotkeys, API key), status indicator (connected/disconnected).
- **Button A (Talk to Gemini)**: Hold hotkey → record mic → on release send audio to Gemini Live → Gemini responds with spoken audio via speakers. [ai.google](https://ai.google.dev/gemini-api/docs/live-api/capabilities)
- **Button B (Voice to Prompt)**: Hold hotkey → record mic → on release transcribe locally with Whisper → optional Gemini prompt-shaper → paste cleaned text into focused app textbox. [github](https://github.com/jatinkrmalik/vocamac)
- **End result**: Wispr Flow + Gemini Live in one lightweight, always-running macOS app. Private (local STT), real-time, works system-wide. [github](https://github.com/nickustinov/typester-macos)

## Tech Stack

| Component | Tech | Why it fits you |
|-----------|------|-----------------|
| **Frontend/Shell** | SwiftUI + AppKit (menu bar app) | Native macOS, your SwiftUI/iOS background, global hotkeys via `NSEvent.addGlobalMonitorForEventsMatchingMask`. [github](https://github.com/jatinkrmalik/vocamac) |
| **Audio Recording** | AVAudioEngine (16kHz PCM mono) | Standard for push-to-talk mic capture on macOS, low-latency. [developer.apple](https://developer.apple.com/forums/thread/804385) |
| **Gemini Live** | Google Generative AI Swift SDK (or REST WebSocket) + persistent Live session | Real-time audio streaming in/out; use `gemini-2.5-flash-exp` model with `responseModalities: [AUDIO]`. [ai.google](https://ai.google.dev/gemini-api/docs/live-api/capabilities) |
| **Speech-to-Text** | WhisperKit/SwiftWhisper (whisper.cpp CoreML wrapper) | Offline, fast on Apple Silicon (M1+), push-to-talk ready—fork "Vocamac" or "Handy" as base. [github](https://github.com/jatinkrmalik/vocamac) |
| **Text Pasting** | NSPasteboard + CGEvent (simulate Cmd+V) | Pastes into any focused app without permissions issues. [exchangetuts](https://www.exchangetuts.com/swift-macos-how-to-paste-into-another-application-1640927284279580) |
| **Audio Playback** | AVAudioPlayer or AVAudioEngine | Plays Gemini's returned PCM/WAV directly to speakers. [stackoverflow](https://stackoverflow.com/questions/31994693/using-the-default-audio-ouput-for-avaudioengine-in-ios) |
| **Backend** | None (all local/client-side) | No FastAPI needed—keeps it simple/single-binary. [swiftanytime](https://www.swiftanytime.com/blog/implement-gemini-ai-sdk-with-swiftui) |
| **Deployment** | Xcode → .app in /Applications; optional notarization for distribution | Runs as menu bar utility, no sandbox conflicts for hotkeys/audio. [github](https://github.com/nickustinov/typester-macos) |

**App type**: Native macOS menu bar app (not iOS/web). Background service with global hotkeys, no main window needed.

## Phase-by-Phase Execution

### Phase 1: Setup & Hotkeys (1-2 hours)
- Create new macOS SwiftUI project (Menu Bar only: `NSStatusBar` + `NSStatusItem`).
- Add global hotkeys: `NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged])` for Right Option (Gemini) / Right Cmd (Dictate).
- Test: Log "Key down/up" to console; show menu bar status.
- Permissions: Add `NSMicrophoneUsageDescription` to Info.plist.

### Phase 2: Audio Recording (2-3 hours)
- Implement `AVAudioEngine` for push-to-talk: On key down, install `AVAudioInputNode` tap at 16000Hz/mono/PCM; buffer audio in `Data` on key up. [developer.apple](https://developer.apple.com/forums/thread/804385)
- Save buffer to temp WAV file for testing.
- Test: Hold hotkey → speak → play back recording via `AVAudioPlayer`.

### Phase 3: Gemini Live (Talk Button A) (3-4 hours)
- Add GoogleGenerativeAI via Swift Package Manager (or HTTP client for WebSocket).
- Get API key from Google AI Studio; init `GenerativeLiveModel` with `responseModalities: ["AUDIO"]`.
- On key up: `liveSession.sendRealtimeInput(audioData: buffer, mimeType: "audio/pcm;rate=16000")`; stream response audio to `AVAudioPlayer`. [swiftanytime](https://www.swiftanytime.com/blog/implement-gemini-ai-sdk-with-swiftui)
- Test: Full round-trip; persistent session across holds.

### Phase 4: Local STT + Paste (Dictate Button B) (2-3 hours)
- Add SwiftWhisper/WhisperKit SPM dependency; download base.en model.
- On key up: Transcribe buffer → get text.
- Optional: Send text to Gemini text model ("Rewrite as concise AI prompt").
- Paste: `NSPasteboard.general.setString(text, forType: .string)` → `CGEvent(keyboard: .v, down: true/false with Cmd flag)`. [exchangetuts](https://www.exchangetuts.com/swift-macos-how-to-paste-into-another-application-1640927284279580)
- Test: Dictate → text appears in Notes/TextEdit.

### Phase 5: Polish & Settings (1-2 hours)
- Menu bar UI: Toggle hotkeys, API key input, model selector, "Prompt shaper" toggle.
- Error handling: Mic busy, API errors, offline fallback (STT only).
- Indicators: Speaking/processing spinner; volume feedback.
- Test edge cases: Multiple holds, background apps.

### Phase 6: Deploy & Iterate (30 min)
- Build/archive in Xcode; run from Applications.
- Optional: GitHub repo, Homebrew formula, or Mac App Store (needs entitlements review for CGEvent). [github](https://github.com/nickustinov/typester-macos)
- Metrics: ~30s latency end-to-end, <100MB app size.

Total estimate: 9-14 hours over 2-3 days. Start with Phase 1-2 for a working prototype. If you hit snags (e.g., AVAudioEngine setup), share error logs for exact code fixes. [ai.google](https://ai.google.dev/gemini-api/docs/live-api/capabilities)
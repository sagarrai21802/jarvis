# Jarvis

A native macOS menu bar AI assistant that combines voice conversation with Gemini AI and voice-to-text dictation in one lightweight app.

## Features

- **Voice Conversation with Gemini**: Hold a hotkey to talk to Google's Gemini AI and receive spoken audio responses
- **Voice Dictation**: Hold a hotkey to transcribe speech to text and automatically paste it into any app
- **Menu Bar App**: Runs quietly in your menu bar, always ready when you need it
- **Local Speech-to-Text**: Uses Whisper for offline, fast transcription on Apple Silicon

## Requirements

- macOS 13.0 or later
- Apple Silicon (M1+) Mac recommended for best performance
- Google Gemini API key (get one at [Google AI Studio](https://aistudio.google.com/app/apikey))

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/your-repo/jarvis.git
   ```

2. Open the project in Xcode:
   ```bash
   open jarvis/jarvis.xcodeproj
   ```

3. Build and run the project (Cmd+R)

4. Grant microphone access when prompted

## User Manual

### Setting Up Your API Key

1. Click the Jarvis icon in your menu bar
2. Click "Settings"
3. Enter your Google Gemini API key
4. Click "Save"

### Using Voice Conversation (Talk to Gemini)

**Hotkey**: Hold `Fn` key (or `Right Option` as fallback)

1. Hold down the hotkey
2. Speak your question or message
3. Release the hotkey to send
4. Gemini will respond with spoken audio

### Using Voice Dictation

**Hotkey**: Hold `Fn + Space` (or `Right Command` as fallback)

1. Hold down the hotkey
2. Speak what you want to type
3. Release the hotkey
4. Your transcribed text will be automatically pasted into the currently focused text field

### Troubleshooting

- **Microphone not working**: Click "Request Microphone Access" in the menu
- **API key issues**: Ensure your Gemini API key is valid and has sufficient quota
- **Hotkeys not responding**: Make sure "Enable global hotkeys" is toggled on in the menu

## Tech Stack

- SwiftUI + AppKit (menu bar app)
- AVAudioEngine (audio recording)
- Google Gemini Live API (voice conversation)
- WhisperKit/SwiftWhisper (local speech-to-text)
- NSPasteboard + CGEvent (text injection)

## License

MIT License

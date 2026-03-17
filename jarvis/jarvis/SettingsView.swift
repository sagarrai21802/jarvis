import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section("Gemini") {
                SecureField("API Key", text: $appState.apiKey)
                    .textFieldStyle(.roundedBorder)

                Button(appState.isValidatingAPIKey ? "Validating..." : "Apply API Key") {
                    appState.applyAndValidateGeminiKey()
                }
                .disabled(appState.isValidatingAPIKey)

                Button(appState.isTestingGemini ? "Testing Gemini..." : "Test Gemini") {
                    appState.testGeminiTextRequest()
                }
                .disabled(appState.isValidatingAPIKey || appState.isTestingGemini)

                if !appState.settingsMessage.isEmpty {
                    Text(appState.settingsMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Hotkeys") {
                Text("Primary Talk: Fn")
                Text("Primary Dictate: Fn + Space")
                Text("Fallback Talk: Right Option")
                Text("Fallback Dictate: Right Command")
            }

            Section("Permissions") {
                Text("Microphone and Accessibility permissions are required.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(16)
        .frame(width: 520)
    }
}

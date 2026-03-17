import SwiftUI

struct MenuBarController: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Jarvis")
                .font(.headline)

            Label(appState.mode.rawValue, systemImage: "waveform")
                .font(.subheadline)

            Text(appState.statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            Toggle("Enable global hotkeys", isOn: $appState.isHotkeysEnabled)

            Text("Talk: Fn (fallback Right Option)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("Dictate: Fn + Space (fallback Right Command)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Divider()

            HStack(spacing: 8) {
                SettingsLink {
                    Text("Settings")
                }

                Button("Quit") {
                    NSApp.terminate(nil)
                }
            }
        }
        .padding(12)
        .frame(width: 300)
    }
}

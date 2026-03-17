//
//  jarvisApp.swift
//  jarvis
//
//  Created by Apple on 17/03/26.
//

import SwiftUI

@main
struct jarvisApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("Jarvis", systemImage: "waveform.circle.fill") {
            MenuBarController()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

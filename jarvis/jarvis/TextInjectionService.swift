import AppKit
import ApplicationServices
import Foundation

final class TextInjectionService {
    enum TextInjectionError: Error {
        case accessibilityPermissionMissing
        case eventCreationFailed
    }

    private var lastPromptTime: Date?
    private let promptCooldown: TimeInterval = 30

    func hasAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibilityPermissionPrompt() {
        if let lastPromptTime, Date().timeIntervalSince(lastPromptTime) < promptCooldown {
            return
        }

        self.lastPromptTime = Date()
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func typeText(_ text: String) throws {
        guard !text.isEmpty else { return }

        guard hasAccessibilityPermission() else {
            throw TextInjectionError.accessibilityPermissionMissing
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false) else {
            throw TextInjectionError.eventCreationFailed
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}

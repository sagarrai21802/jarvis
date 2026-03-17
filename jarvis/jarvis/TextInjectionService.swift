import ApplicationServices
import Foundation

final class TextInjectionService {
    enum TextInjectionError: Error {
        case accessibilityPermissionMissing
        case eventCreationFailed
    }

    func requestAccessibilityPermissionPrompt() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func typeText(_ text: String) throws {
        guard !text.isEmpty else { return }

        guard AXIsProcessTrusted() else {
            throw TextInjectionError.accessibilityPermissionMissing
        }

        for scalar in text.unicodeScalars {
            var value = UInt16(scalar.value)

            guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else {
                throw TextInjectionError.eventCreationFailed
            }

            keyDown.keyboardSetUnicodeString(stringLength: 1, unicodeString: &value)
            keyUp.keyboardSetUnicodeString(stringLength: 1, unicodeString: &value)

            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }
    }
}

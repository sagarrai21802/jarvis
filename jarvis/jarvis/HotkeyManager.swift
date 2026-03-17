import AppKit

final class HotkeyManager {
    enum TriggerSource {
        case fn
        case fnSpace
        case rightOption
        case rightCommand
    }

    enum ActiveMode {
        case idle
        case talk(TriggerSource)
        case dictate(TriggerSource)
    }

    var onTalkPressDown: (() -> Void)?
    var onTalkPressUp: (() -> Void)?
    var onDictatePressDown: (() -> Void)?
    var onDictatePressUp: (() -> Void)?

    var isEnabled: Bool = true

    private var globalFlagsMonitor: Any?
    private var globalKeyDownMonitor: Any?
    private var globalKeyUpMonitor: Any?

    private var fnIsPressed = false
    private var fnSpaceIsPressed = false
    private var activeMode: ActiveMode = .idle

    private let keyCodeSpace: UInt16 = 49
    private let keyCodeRightOption: UInt16 = 61
    private let keyCodeRightCommand: UInt16 = 54

    func start() {
        stop()

        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handleFlagsChanged(event)
        }

        globalKeyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.handleKeyDown(event)
        }

        globalKeyUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyUp]) { [weak self] event in
            self?.handleKeyUp(event)
        }
    }

    func stop() {
        if let globalFlagsMonitor {
            NSEvent.removeMonitor(globalFlagsMonitor)
            self.globalFlagsMonitor = nil
        }

        if let globalKeyDownMonitor {
            NSEvent.removeMonitor(globalKeyDownMonitor)
            self.globalKeyDownMonitor = nil
        }

        if let globalKeyUpMonitor {
            NSEvent.removeMonitor(globalKeyUpMonitor)
            self.globalKeyUpMonitor = nil
        }

        activeMode = .idle
        fnIsPressed = false
        fnSpaceIsPressed = false
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        guard isEnabled else { return }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if event.keyCode == keyCodeRightOption {
            let isPressed = flags.contains(.option)
            handleRightOptionChange(isPressed: isPressed)
            return
        }

        if event.keyCode == keyCodeRightCommand {
            let isPressed = flags.contains(.command)
            handleRightCommandChange(isPressed: isPressed)
            return
        }

        let fnPressedNow = flags.contains(.function)
        if fnPressedNow != fnIsPressed {
            fnIsPressed = fnPressedNow
            handleFunctionChange(isPressed: fnPressedNow)
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        guard isEnabled else { return }

        if event.keyCode == keyCodeSpace, event.modifierFlags.contains(.function), !fnSpaceIsPressed {
            fnSpaceIsPressed = true

            if case .talk(.fn) = activeMode {
                onTalkPressUp?()
            }

            startDictate(source: .fnSpace)
        }
    }

    private func handleKeyUp(_ event: NSEvent) {
        guard isEnabled else { return }

        if event.keyCode == keyCodeSpace, fnSpaceIsPressed {
            fnSpaceIsPressed = false

            if case .dictate(.fnSpace) = activeMode {
                endDictate()
            }
        }
    }

    private func handleFunctionChange(isPressed: Bool) {
        if isPressed {
            startTalk(source: .fn)
        } else {
            if case .talk(.fn) = activeMode {
                endTalk()
            }
        }
    }

    private func handleRightOptionChange(isPressed: Bool) {
        if isPressed {
            startTalk(source: .rightOption)
        } else {
            if case .talk(.rightOption) = activeMode {
                endTalk()
            }
        }
    }

    private func handleRightCommandChange(isPressed: Bool) {
        if isPressed {
            startDictate(source: .rightCommand)
        } else {
            if case .dictate(.rightCommand) = activeMode {
                endDictate()
            }
        }
    }

    private func startTalk(source: TriggerSource) {
        guard case .idle = activeMode else { return }
        activeMode = .talk(source)
        onTalkPressDown?()
    }

    private func endTalk() {
        onTalkPressUp?()
        activeMode = .idle
    }

    private func startDictate(source: TriggerSource) {
        guard case .idle = activeMode else { return }
        activeMode = .dictate(source)
        onDictatePressDown?()
    }

    private func endDictate() {
        onDictatePressUp?()
        activeMode = .idle
    }
}

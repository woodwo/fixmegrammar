import Foundation
import Cocoa

final class ClipboardMonitor {
    private var previousContent: String = ""
    private var timer: Timer?
    private var skipNextChange: Bool = false

    private let isEnabledProvider: () -> Bool
    private let shouldSkipCodeProvider: () -> Bool
    private let onProcessText: (String, String?) -> Void
    private let isCodeDetector: (String) -> Bool

    init(
        isEnabledProvider: @escaping () -> Bool,
        shouldSkipCodeProvider: @escaping () -> Bool,
        onProcessText: @escaping (String, String?) -> Void,
        isCodeDetector: @escaping (String) -> Bool
    ) {
        self.isEnabledProvider = isEnabledProvider
        self.shouldSkipCodeProvider = shouldSkipCodeProvider
        self.onProcessText = onProcessText
        self.isCodeDetector = isCodeDetector
    }

    func start() {
        print("[ClipboardMonitor] start")
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func ignoreNextChange() {
        skipNextChange = true
    }

    private func tick() {
        guard isEnabledProvider() else { return }
        guard let content = NSPasteboard.general.string(forType: .string) else { return }

        if skipNextChange {
            skipNextChange = false
            previousContent = content
            return
        }

        guard content != previousContent else { return }
        previousContent = content

        let sourceBundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        if shouldSkipCodeProvider() && isCodeDetector(content) {
            print("Detected code, skipping grammar check")
            return
        }

        onProcessText(content, sourceBundleId)
    }
}

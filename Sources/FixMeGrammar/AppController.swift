import Foundation
import Cocoa

final class AppController {
    private let statusBarController: StatusBarController
    private lazy var clipboardMonitor: ClipboardMonitor = {
        ClipboardMonitor(
            isEnabledProvider: { AppSettings.shared.enabled },
            shouldSkipCodeProvider: { AppSettings.shared.skipCode },
            onProcessText: { [weak self] text, sourceBundleId in
                guard let self else { return }
                Task {
                    do {
                        try await self.maybeProcessClipboardText(text: text, sourceBundleId: sourceBundleId, force: false)
                    } catch {
                        print("Error fixing grammar: \(error.localizedDescription)")
                    }
                }
            },
            isCodeDetector: { [weak self] text in
                guard let self else { return false }
                return self.languageDetector.isLikelyCode(text: text)
            }
        )
    }()
    private let gptClient: GPTClient
    private let languageDetector: LanguageDetector
    private var settings: AppSettings

    init() {
        self.settings = AppSettings.load()
        self.statusBarController = StatusBarController(
            settings: settings,
            onToggleEnabled: { isEnabled in
                AppSettings.shared.enabled = isEnabled
                AppSettings.save()
            },
            onToggleTranslateToEnglish: { translate in
                AppSettings.shared.translateToEnglish = translate
                AppSettings.save()
            },
            onToggleSkipCode: { skip in
                AppSettings.shared.skipCode = skip
                AppSettings.save()
            },
            onFixClipboardNow: {
                AppController.fixClipboardOnce()
            },
            onQuit: {
                NSApplication.shared.terminate(nil)
            }
        )
        self.gptClient = GPTClient()
        self.languageDetector = LanguageDetector()
        Self.shared = self
        // Start after setup
        self.clipboardMonitor.start()
    }

    private static func replaceClipboard(with text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if !pasteboard.setString(text, forType: .string) {
            print("Failed to update clipboard with fixed text")
        } else {
            print("Successfully updated clipboard with fixed text")
        }
    }

    private static func fixClipboardOnce() {
        guard let content = NSPasteboard.general.string(forType: .string) else { return }
        Task {
            await AppController.shared?.processNow(text: content)
        }
    }

    // Allowlist and processing
    private static let allowedBundleIds: Set<String> = [
        // Slack
        "com.tinyspeck.slackmacgap", // legacy
        "com.tinyspeck.slackmacgap.helper",
        "com.SlackTechnologies.Slack",
        // Google Chrome
        "com.google.Chrome",
        "com.google.Chrome.canary",
        // Zoom
        "us.zoom.xos",
    ]

    private static var shared: AppController?

    @discardableResult
    private func maybeProcessClipboardText(text: String, sourceBundleId: String?, force: Bool) async throws -> Bool {
        let isAllowedSource = sourceBundleId.map { Self.allowedBundleIds.contains($0) } ?? false
        guard force || isAllowedSource else {
            print("Skipping auto-fix for source: \(sourceBundleId ?? "unknown")")
            return false
        }

        let fixed = try await self.gptClient.fixGrammar(
            text: text,
            translateToEnglish: AppSettings.shared.translateToEnglish
        )
        if fixed != text {
            AppController.replaceClipboard(with: fixed)
            self.statusBarController.flash()
            print("Fixed text: \(fixed)")
            return true
        } else {
            print("No grammar issues found")
            return false
        }
    }

    private func processNow(text: String) async {
        do {
            _ = try await maybeProcessClipboardText(text: text, sourceBundleId: nil, force: true)
        } catch {
            print("Manual fix failed: \(error.localizedDescription)")
        }
    }
}

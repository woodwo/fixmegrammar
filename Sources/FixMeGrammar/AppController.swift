import Foundation
import Cocoa

final class AppController {
    private let statusBarController: StatusBarController
    private lazy var clipboardMonitor: ClipboardMonitor = {
        ClipboardMonitor(
            isEnabledProvider: { AppSettings.shared.enabled },
            shouldSkipCodeProvider: { AppSettings.shared.skipCode },
            onProcessText: { [weak self] text in
                guard let self else { return }
                Task {
                    do {
                        let fixed = try await self.gptClient.fixGrammar(
                            text: text,
                            translateToEnglish: AppSettings.shared.translateToEnglish
                        )
                        if fixed != text {
                            AppController.replaceClipboard(with: fixed)
                            self.statusBarController.flash()
                            print("Fixed text: \(fixed)")
                        } else {
                            print("No grammar issues found")
                        }
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
        // Trigger change by re-setting processed content via monitor pipeline
        NSPasteboard.general.clearContents()
        _ = NSPasteboard.general.setString(content + "\n", forType: .string)
        // Add a tiny change to force monitor without altering content meaningfully
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NSPasteboard.general.clearContents()
            _ = NSPasteboard.general.setString(content, forType: .string)
        }
    }
}

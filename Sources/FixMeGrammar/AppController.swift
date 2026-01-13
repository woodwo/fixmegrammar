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
        print("[AppController] init entered")
        self.settings = AppSettings.load()
        print("[AppController] settings loaded: enabled=\(self.settings.enabled), translate=\(self.settings.translateToEnglish), skipCode=\(self.settings.skipCode)")
        fflush(stdout)
        print("[AppController] init start")
        print("[AppController] creating StatusBarController")
        self.statusBarController = StatusBarController(
            settings: settings,
            onToggleEnabled: { isEnabled in
                AppSettings.shared.enabled = isEnabled
                AppSettings.save()
                print("[AppController] toggled enabled: \(isEnabled)")
            },
            onToggleTranslateToEnglish: { translate in
                AppSettings.shared.translateToEnglish = translate
                AppSettings.save()
                print("[AppController] toggled translate: \(translate)")
            },
            onToggleSkipCode: { skip in
                AppSettings.shared.skipCode = skip
                AppSettings.save()
                print("[AppController] toggled skipCode: \(skip)")
            },
            onTogglePresentationMode: { presentationMode in
                AppSettings.shared.presentationMode = presentationMode
                AppSettings.save()
                print("[AppController] toggled presentationMode: \(presentationMode)")
            },
            onToggleFilterApps: { filterApps in
                AppSettings.shared.filterAppsEnabled = filterApps
                AppSettings.save()
                print("[AppController] toggled filterAppsEnabled: \(filterApps)")
            },
            onFixClipboardNow: {
                AppController.fixClipboardOnce()
            },
            onQuit: {
                NSApplication.shared.terminate(nil)
            }
        )
        print("[AppController] creating GPTClient")
        self.gptClient = GPTClient()
        print("[AppController] creating LanguageDetector")
        self.languageDetector = LanguageDetector()
        Self.shared = self
        print("[AppController] starting clipboard monitor")
        self.clipboardMonitor.start()
        print("[AppController] init finished")
    }

    private func replaceClipboard(with text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if !pasteboard.setString(text, forType: .string) {
            print("Failed to update clipboard with fixed text")
        } else {
            print("Successfully updated clipboard with fixed text")
            self.clipboardMonitor.ignoreNextChange()
            if let sound = NSSound(named: "Pop") {
                sound.play()
            }
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
        // VS Code
        "com.microsoft.VSCode",
        "com.microsoft.VSCode.insiders",
        // Cursor
        "com.todesktop.240320152205d6f5",
    ]

    private static var shared: AppController?

    @discardableResult
    private func maybeProcessClipboardText(text: String, sourceBundleId: String?, force: Bool) async throws -> Bool {
        if !force && AppSettings.shared.filterAppsEnabled {
            let isAllowedSource = sourceBundleId.map { Self.allowedBundleIds.contains($0) } ?? false
            guard isAllowedSource else {
                print("Skipping auto-fix for source: \(sourceBundleId ?? "unknown")")
                return false
            }
        }

        let fixed = try await self.gptClient.fixGrammar(
            text: text,
            translateToEnglish: AppSettings.shared.translateToEnglish,
            presentationMode: AppSettings.shared.presentationMode
        )
        if fixed != text {
            self.replaceClipboard(with: fixed)
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

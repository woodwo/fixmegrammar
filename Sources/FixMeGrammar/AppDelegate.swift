import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appController: AppController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[AppDelegate] applicationDidFinishLaunching")
        NSApp.setActivationPolicy(.accessory)
        appController = AppController()
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("[AppDelegate] applicationWillTerminate")
    }
}

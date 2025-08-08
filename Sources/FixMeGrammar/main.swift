import Cocoa

print("[main] Starting application")
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
print("[main] Running app runloop")
app.run()

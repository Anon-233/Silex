import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            NSApp.windows.first { $0.title == "Silex" }?.close()
        }
    }
}

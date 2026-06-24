import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.windows.first { $0.title == "Silex" }?.orderOut(nil)
    }
}

import SwiftUI

struct SilexApplication: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("Silex", id: "main") {
            LocalizedAppContent(model: model) {
                MainWindowView(model: model)
            }
        }
        .defaultSize(width: 900, height: 675)

        MenuBarExtra {
            LocalizedAppContent(model: model) {
                MenuBarView(model: model)
            }
        } label: {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 17, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.blue)
        }
        .menuBarExtraStyle(.window)
    }
}

SilexApplication.main()

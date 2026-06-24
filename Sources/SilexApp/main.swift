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
            Image("logo")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 18, height: 18)
        }
        .menuBarExtraStyle(.window)
    }
}

SilexApplication.main()

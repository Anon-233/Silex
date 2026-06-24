import SwiftUI

struct SilexApplication: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("Silex", id: "main") {
            MainWindowView(model: model)
                .environment(\.locale, model.locale)
        }
        .defaultSize(width: 900, height: 675)

        MenuBarExtra {
            MenuBarView(model: model)
                .environment(\.locale, model.locale)
        } label: {
            AppMark()
                .frame(width: 17, height: 17)
        }
        .menuBarExtraStyle(.window)
    }
}

SilexApplication.main()

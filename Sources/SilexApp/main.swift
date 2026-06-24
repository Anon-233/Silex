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
            menuBarIconView()
                .frame(width: 18, height: 18)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarIcon: View {
    var body: some View {
        if let nsImage = loadLogo() {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "internaldrive")
                .font(.system(size: 14, weight: .medium))
        }
    }

    private func loadLogo() -> NSImage? {
        for bundle in [Bundle.main, Bundle.module] {
            if let path = bundle.path(forResource: "logo", ofType: "png"),
               let image = NSImage(contentsOfFile: path) {
                image.isTemplate = false
                return image
            }
        }
        return nil
    }
}

private func menuBarIconView() -> some View {
    MenuBarIcon()
}

SilexApplication.main()

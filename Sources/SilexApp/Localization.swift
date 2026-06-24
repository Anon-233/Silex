import SwiftUI

struct LocalizedLabel: View {
    @Environment(\.locale) private var locale
    let key: String

    init(_ key: String) {
        self.key = key
    }

    var body: some View {
        Text(localized(key, locale: locale))
    }
}

func localized(_ key: String, locale: Locale) -> String {
    let bundle: Bundle = Bundle.main.bundleURL.pathExtension == "app"
        ? .main
        : .module
    return String(
        localized: String.LocalizationValue(key),
        bundle: bundle,
        locale: locale
    )
}

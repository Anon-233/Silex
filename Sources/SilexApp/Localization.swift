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
    String(
        localized: String.LocalizationValue(key),
        bundle: .module,
        locale: locale
    )
}


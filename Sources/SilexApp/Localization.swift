import SwiftUI
import SilexCore

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

struct LocalizedAppContent<Content: View>: View {
    @ObservedObject var model: AppModel
    private let content: () -> Content

    init(
        model: AppModel,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.model = model
        self.content = content
    }

    var body: some View {
        content()
            .environment(\.locale, model.locale)
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

func localizedAggregationLabel(
    _ aggregation: RuleAggregation,
    locale: Locale
) -> String {
    localized("aggregation.\(aggregation.rawValue)", locale: locale)
}

func localizedComparisonLabel(
    _ comparison: RuleComparison,
    locale: Locale
) -> String {
    localized("comparison.\(comparison.rawValue)", locale: locale)
}

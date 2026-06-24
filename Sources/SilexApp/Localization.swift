import SwiftUI
import SilexCore

// MARK: - Localization table loader

private var cachedTable: [String: String]?
private var cachedLocaleID: String?

private func table(for locale: Locale, bundle: Bundle) -> [String: String] {
    let identifier: String
    switch locale.identifier {
    case "en", "en-US":
        identifier = "en"
    case "zh-Hans", "zh":
        identifier = "zh-Hans"
    default:
        if locale == .autoupdatingCurrent {
            let preferred = bundle.preferredLocalizations.first ?? "en"
            identifier = preferred == "zh-Hans" ? "zh-Hans" : "en"
        } else {
            identifier = "en"
        }
    }
    if cachedLocaleID != identifier {
        if let path = bundle.path(
            forResource: "Localizable",
            ofType: "strings",
            inDirectory: "\(identifier).lproj"
        ),
        let dict = NSDictionary(contentsOfFile: path) as? [String: String] {
            cachedTable = dict
        } else {
            cachedTable = [:]
        }
        cachedLocaleID = identifier
    }
    return cachedTable ?? [:]
}

func localized(_ key: String, locale: Locale) -> String {
    let bundle: Bundle = Bundle.main.bundleURL.pathExtension == "app"
        ? .main
        : .module
    return table(for: locale, bundle: bundle)[key] ?? key
}

// MARK: - Views

struct LocalizedLabel: View {
    @Environment(\.locale) private var environmentLocale
    let key: String

    init(_ key: String) {
        self.key = key
    }

    var body: some View {
        Text(localized(key, locale: environmentLocale))
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

// MARK: - Helpers

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

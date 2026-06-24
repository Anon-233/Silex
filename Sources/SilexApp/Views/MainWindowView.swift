import SwiftUI
import SilexCore

struct MainWindowView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ZStack {
            VStack(spacing: 10) {
                header

                Group {
                    switch model.currentPage {
                    case 0:
                        SettingsView(model: model)
                    case 1:
                        OverviewView(model: model)
                    case 2:
                        TrendPageView(model: model, group: .readWrite)
                    case 3:
                        TrendPageView(model: model, group: .temperature)
                    case 4:
                        TrendPageView(model: model, group: .wear)
                    default:
                        TrendPageView(model: model, group: .events)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.quaternary)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            var navigation = PageNavigationState(
                                page: model.currentPage,
                                pageCount: model.pageCount
                            )
                            model.currentPage = navigation.finishDrag(
                                width: value.translation.width,
                                height: value.translation.height,
                                isBlocked: model.isRuleOverlayPresented
                            )
                        }
                )

                navigation
            }
            .padding(14)

            if model.isRuleOverlayPresented {
                RuleOverlay(model: model)
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .background(WindowConfigurator())
        .background(
            WindowInputAdapter(
                isBlocked: { model.isRuleOverlayPresented },
                move: navigate
            )
        )
        .alert(item: $model.presentedAlert) { alert in
            appAlert(alert)
        }
        .alert(item: $model.ruleTestPresentation) { result in
            Alert(
                title: Text(localized("result.ruleTest.title", locale: model.locale)),
                message: Text(ruleTestMessage(result)),
                dismissButton: .default(
                    Text(localized("action.dismiss", locale: model.locale))
                )
            )
        }
        .animation(.easeInOut(duration: 0.18), value: model.isRuleOverlayPresented)
    }

    private var header: some View {
        HStack(spacing: 10) {
            AppMark()
                .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                LocalizedLabel("app.name")
                    .font(.headline)
                Text(model.latestSample?.modelName ?? localized("app.subtitle", locale: model.locale))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if model.currentPage >= 2 {
                Button {
                    model.isRuleOverlayPresented = true
                } label: {
                    LocalizedLabel("action.rules")
                }
            }
            Button {
                model.collectNow()
            } label: {
                if model.isCollecting {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    LocalizedLabel("action.collect")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isCollecting)
        }
    }

    private var navigation: some View {
        HStack(spacing: 7) {
            ForEach(0..<model.pageCount, id: \.self) { index in
                Button {
                    model.currentPage = index
                } label: {
                    Capsule()
                        .fill(index == model.currentPage ? Color.green : Color.secondary.opacity(0.3))
                        .frame(width: index == model.currentPage ? 20 : 7, height: 7)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    localized("navigation.page.\(index)", locale: model.locale)
                )
                .accessibilityAddTraits(
                    index == model.currentPage ? .isSelected : []
                )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 12)
    }

    private func navigate(_ direction: PageDirection) {
        var navigation = PageNavigationState(
            page: model.currentPage,
            pageCount: model.pageCount
        )
        navigation.move(direction, isBlocked: model.isRuleOverlayPresented)
        model.currentPage = navigation.page
    }

    private func appAlert(_ alert: AppAlert) -> Alert {
        let title = Text(localized(alert.titleKey, locale: model.locale))
        let message = Text(alert.message)
        if alert.kind == .serviceUnavailable {
            return Alert(
                title: title,
                message: message,
                primaryButton: .default(
                    Text(localized("action.openSettings", locale: model.locale)),
                    action: model.openBackgroundItemsSettings
                ),
                secondaryButton: .cancel(
                    Text(localized("action.cancel", locale: model.locale))
                )
            )
        }
        return Alert(
            title: title,
            message: message,
            dismissButton: .default(
                Text(localized("action.dismiss", locale: model.locale))
            )
        )
    }

    private func ruleTestMessage(_ result: RuleTestPresentation) -> String {
        let metric = localized(
            "metric.\(result.metric.rawValue)",
            locale: model.locale
        )
        let comparison = localizedComparisonLabel(
            result.comparison,
            locale: model.locale
        )
        let summary = "\(result.ruleName)\n\(metric): "
            + "\(result.observedValue.formatted(.number.precision(.fractionLength(0...2)))) "
            + "\(comparison) "
            + result.threshold.formatted(.number.precision(.fractionLength(0...2)))
        let notification: String
        switch result.notificationStatus {
        case .disabled:
            notification = localized(
                "result.ruleTest.notificationDisabled",
                locale: model.locale
            )
        case .delivered:
            notification = localized(
                "result.ruleTest.notificationDelivered",
                locale: model.locale
            )
        case let .failed(message):
            notification = localized(
                "result.ruleTest.notificationFailed",
                locale: model.locale
            ) + "\n" + message
        }
        return summary + "\n\n" + notification
    }
}

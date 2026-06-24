import SwiftUI
import SilexCore

struct RuleOverlay: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.22)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    model.isRuleOverlayPresented = false
                }

            VStack(spacing: 12) {
                HStack {
                    LocalizedLabel("action.rules")
                        .font(.title2.bold())
                    Spacer()
                    Button {
                        model.addRule()
                    } label: {
                        Label {
                            LocalizedLabel("rule.add")
                        } icon: {
                            Image(systemName: "plus")
                        }
                    }
                    Button {
                        model.isRuleOverlayPresented = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(localized("action.close", locale: model.locale))
                }

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach($model.rules) { $rule in
                            RuleEditorRow(
                                rule: $rule,
                                locale: model.locale,
                                save: { model.saveRule(rule) },
                                test: { model.testRule(rule) },
                                delete: { model.deleteRule(rule) }
                            )
                        }
                    }
                }
            }
            .padding(16)
            .frame(width: 720, height: 500)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(radius: 30)
        }
    }
}

private struct RuleEditorRow: View {
    @Binding var rule: AlertRule
    let locale: Locale
    let save: () -> Void
    let test: () -> Void
    let delete: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                TextField(localized("rule.name", locale: locale), text: $rule.name)
                    .textFieldStyle(.plain)
                    .font(.headline)
                Toggle("", isOn: $rule.isEnabled)
                    .labelsHidden()
            }

            HStack(spacing: 8) {
                field("rule.metric") {
                    Picker("", selection: $rule.metric) {
                        ForEach(Metric.allCases, id: \.self) { metric in
                            Text(localized("metric.\(metric.rawValue)", locale: locale))
                                .tag(metric)
                        }
                    }
                    .labelsHidden()
                    .onChange(of: rule.metric) {
                        if !rule.metric.allowedAggregations.contains(rule.aggregation) {
                            rule.aggregation = rule.metric.allowedAggregations[0]
                        }
                    }
                }
                field("rule.aggregation") {
                    Picker("", selection: $rule.aggregation) {
                        ForEach(rule.metric.allowedAggregations, id: \.self) { aggregation in
                            Text(aggregationLabel(aggregation))
                                .tag(aggregation)
                        }
                    }
                    .labelsHidden()
                }
                field("rule.comparison") {
                    Picker("", selection: $rule.comparison) {
                        Text(">").tag(RuleComparison.greaterThan)
                        Text("≥").tag(RuleComparison.greaterThanOrEqual)
                        Text("<").tag(RuleComparison.lessThan)
                        Text("≤").tag(RuleComparison.lessThanOrEqual)
                    }
                    .labelsHidden()
                }
                field("rule.threshold") {
                    HStack(spacing: 4) {
                        TextField("", value: $rule.threshold, format: .number)
                            .frame(width: 72)
                        Text(rule.metric.unit)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 8) {
                field("rule.window") {
                    TextField("", value: $rule.windowHours, format: .number)
                        .frame(width: 72)
                }
                field("rule.cooldown") {
                    TextField("", value: $rule.cooldownHours, format: .number)
                        .frame(width: 72)
                }
                Spacer()
                Button(action: test) {
                    LocalizedLabel("rule.test")
                }
                Button(role: .destructive, action: delete) {
                    LocalizedLabel("rule.delete")
                }
                Button(action: save) {
                    LocalizedLabel("rule.save")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func field<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            LocalizedLabel(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func aggregationLabel(_ aggregation: RuleAggregation) -> String {
        switch aggregation {
        case .current: "Current"
        case .increase: "Increase"
        case .ratePerHour: "Rate/h"
        case .average: "Average"
        case .minimum: "Minimum"
        case .maximum: "Maximum"
        }
    }
}


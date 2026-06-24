import SwiftUI
import SilexCore

struct RuleOverlay: View {
    @ObservedObject var model: AppModel

    @State private var drafts: [RuleDraft] = []
    @State private var baselineRules: [AlertRule] = []
    @State private var validationErrors: [UUID: [RuleDraftValidationError]] = [:]
    @State private var pendingDeleteID: UUID?
    @State private var confirmsRuleDeletion = false
    @State private var confirmsUnsavedChanges = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.22)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    requestClose()
                }

            VStack(spacing: 10) {
                HStack {
                    LocalizedLabel("action.rules")
                        .font(.title2.bold())
                    Spacer()
                    Button {
                        addDraft()
                    } label: {
                        Label {
                            LocalizedLabel("rule.add")
                        } icon: {
                            Image(systemName: "plus")
                        }
                    }
                    Button {
                        requestClose()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        localized("action.close", locale: model.locale)
                    )
                }

                if drafts.isEmpty {
                    ContentUnavailableView(
                        localized("rule.empty.title", locale: model.locale),
                        systemImage: "bell.badge",
                        description: Text(
                            localized("rule.empty.message", locale: model.locale)
                        )
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach($drafts) { $draft in
                                RuleEditorRow(
                                    draft: $draft,
                                    locale: model.locale,
                                    errors: validationErrors[draft.id] ?? [],
                                    save: { saveDraft(draft) },
                                    test: { testDraft(draft) },
                                    delete: {
                                        pendingDeleteID = draft.id
                                        confirmsRuleDeletion = true
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .padding(14)
            .frame(width: 720, height: 490)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(radius: 30)
        }
        .onAppear {
            reloadDrafts()
        }
        .confirmationDialog(
            localized("dialog.deleteRule.title", locale: model.locale),
            isPresented: $confirmsRuleDeletion,
            titleVisibility: .visible
        ) {
            Button(
                localized("rule.delete", locale: model.locale),
                role: .destructive
            ) {
                deleteConfirmedDraft()
            }
            Button(
                localized("action.cancel", locale: model.locale),
                role: .cancel
            ) {}
        } message: {
            Text(localized("dialog.deleteRule.message", locale: model.locale))
        }
        .confirmationDialog(
            localized("dialog.unsavedRules.title", locale: model.locale),
            isPresented: $confirmsUnsavedChanges,
            titleVisibility: .visible
        ) {
            Button(localized("action.saveAll", locale: model.locale)) {
                saveAllAndClose()
            }
            Button(
                localized("action.discard", locale: model.locale),
                role: .destructive
            ) {
                model.isRuleOverlayPresented = false
            }
            Button(
                localized("action.cancel", locale: model.locale),
                role: .cancel
            ) {}
        } message: {
            Text(localized("dialog.unsavedRules.message", locale: model.locale))
        }
    }

    private var hasUnsavedChanges: Bool {
        guard drafts.count == baselineRules.count else {
            return true
        }
        return drafts.contains { draft in
            guard let rule = baselineRules.first(where: { $0.id == draft.id }) else {
                return true
            }
            return draft.isDirty(comparedTo: rule)
        }
    }

    private func reloadDrafts() {
        baselineRules = model.rules
        drafts = model.rules.map(RuleDraft.init)
        validationErrors = [:]
    }

    private func requestClose() {
        if hasUnsavedChanges {
            confirmsUnsavedChanges = true
        } else {
            model.isRuleOverlayPresented = false
        }
    }

    private func addDraft() {
        let rule = AlertRule(
            name: localized("rule.defaultName", locale: model.locale),
            metric: .temperature,
            aggregation: .maximum,
            windowHours: 24,
            comparison: .greaterThan,
            threshold: 60,
            cooldownHours: 8,
            isEnabled: true
        )
        drafts.insert(RuleDraft(rule: rule), at: 0)
    }

    private func saveDraft(_ draft: RuleDraft) {
        let errors = draft.validationErrors()
        validationErrors[draft.id] = errors
        guard errors.isEmpty, let rule = try? draft.makeRule() else {
            return
        }
        guard model.saveRule(rule) else {
            return
        }
        if let index = baselineRules.firstIndex(where: { $0.id == rule.id }) {
            baselineRules[index] = rule
        } else {
            baselineRules.append(rule)
        }
        if let index = drafts.firstIndex(where: { $0.id == rule.id }) {
            drafts[index] = RuleDraft(rule: rule)
        }
        validationErrors[rule.id] = nil
    }

    private func testDraft(_ draft: RuleDraft) {
        let errors = draft.validationErrors()
        validationErrors[draft.id] = errors
        guard errors.isEmpty, let rule = try? draft.makeRule() else {
            return
        }
        model.testRule(rule)
    }

    private func saveAllAndClose() {
        var rulesToSave: [AlertRule] = []
        var errorsByID: [UUID: [RuleDraftValidationError]] = [:]

        for draft in drafts {
            let errors = draft.validationErrors()
            if errors.isEmpty, let rule = try? draft.makeRule() {
                rulesToSave.append(rule)
            } else {
                errorsByID[draft.id] = errors
            }
        }

        validationErrors = errorsByID
        guard errorsByID.isEmpty else {
            return
        }
        var allSaved = true
        for rule in rulesToSave {
            allSaved = model.saveRule(rule) && allSaved
        }
        guard allSaved else {
            return
        }
        model.isRuleOverlayPresented = false
    }

    private func deleteConfirmedDraft() {
        guard
            let pendingDeleteID,
            let index = drafts.firstIndex(where: { $0.id == pendingDeleteID })
        else {
            return
        }
        if let rule = model.rules.first(where: { $0.id == pendingDeleteID }) {
            model.deleteRule(rule)
        }
        drafts.remove(at: index)
        baselineRules.removeAll { $0.id == pendingDeleteID }
        validationErrors[pendingDeleteID] = nil
        self.pendingDeleteID = nil
    }
}

private struct RuleEditorRow: View {
    @Binding var draft: RuleDraft
    let locale: Locale
    let errors: [RuleDraftValidationError]
    let save: () -> Void
    let test: () -> Void
    let delete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                TextField(localized("rule.name", locale: locale), text: $draft.name)
                    .font(.headline)
                Toggle("", isOn: $draft.isEnabled)
                    .labelsHidden()
            }

            HStack(alignment: .bottom, spacing: 8) {
                field("rule.metric") {
                    Picker("", selection: $draft.metric) {
                        ForEach(Metric.allCases, id: \.self) { metric in
                            Text(localized(metric.titleKey, locale: locale))
                                .tag(metric)
                        }
                    }
                    .labelsHidden()
                    .onChange(of: draft.metric) {
                        if !draft.metric.allowedAggregations.contains(draft.aggregation) {
                            draft.aggregation = draft.metric.allowedAggregations[0]
                        }
                    }
                }

                field("rule.aggregation") {
                    Picker("", selection: $draft.aggregation) {
                        ForEach(draft.metric.allowedAggregations, id: \.self) { aggregation in
                            Text(localizedAggregationLabel(aggregation, locale: locale))
                                .tag(aggregation)
                        }
                    }
                    .labelsHidden()
                }

                field("rule.comparison") {
                    Picker("", selection: $draft.comparison) {
                        ForEach(RuleComparison.allCases, id: \.self) { comparison in
                            Text(localizedComparisonLabel(comparison, locale: locale))
                                .tag(comparison)
                        }
                    }
                    .labelsHidden()
                }

                field("rule.threshold") {
                    HStack(spacing: 4) {
                        TextField("", value: $draft.threshold, format: .number)
                            .frame(width: 72)
                        Text(draft.metric.unit)
                            .foregroundStyle(SilexTheme.muted)
                    }
                }
            }

            HStack(alignment: .bottom, spacing: 8) {
                field("rule.window") {
                    TextField("", value: $draft.windowHours, format: .number)
                        .frame(width: 78)
                }
                field("rule.cooldown") {
                    TextField("", value: $draft.cooldownHours, format: .number)
                        .frame(width: 78)
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

            ForEach(errors, id: \.localizationKey) { error in
                Text(localized(error.localizationKey, locale: locale))
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .padding(11)
        .background(SilexTheme.soft)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(SilexTheme.tileLine, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func field<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            LocalizedLabel(label)
                .font(.caption2)
                .foregroundStyle(SilexTheme.muted)
            content()
        }
    }
}

private extension RuleDraftValidationError {
    var localizationKey: String {
        switch self {
        case .emptyName:
            "rule.validation.emptyName"
        case .invalidAggregation:
            "rule.validation.invalidAggregation"
        case .invalidThreshold:
            "rule.validation.invalidThreshold"
        case .invalidWindow:
            "rule.validation.invalidWindow"
        case .invalidCooldown:
            "rule.validation.invalidCooldown"
        }
    }
}

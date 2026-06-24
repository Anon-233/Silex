import AppKit
import Combine
import Foundation
import OSLog
import ServiceManagement
import SilexCore
import UserNotifications

@MainActor
final class AppModel: ObservableObject {
    @Published var samples: [DriveSample] = []
    @Published var rules: [AlertRule] = []
    @Published var settings = AppSettings()
    @Published var currentPage = 1
    @Published var range: HistoryRange = .days30
    @Published var isCollecting = false
    @Published var lastError: String?
    @Published var serviceStatus: BackgroundServiceStatus = .unavailable
    @Published var isRuleOverlayPresented = false
    @Published var presentedAlert: AppAlert?
    @Published var ruleTestPresentation: RuleTestPresentation?
    @Published private(set) var nextCollectionAt: Date?

    let pageCount = 6

    private var database: Database?
    private var sampleRepository: SampleRepository?
    private var ruleRepository: RuleRepository?
    private var settingsRepository: SettingsRepository?
    private let serviceController = ServiceController()
    private let scheduler = CollectionScheduler()
    private var wakeObserver: NSObjectProtocol?

    var locale: Locale {
        switch settings.language {
        case .system:
            .autoupdatingCurrent
        case .english:
            Locale(identifier: "en")
        case .simplifiedChinese:
            Locale(identifier: "zh-Hans")
        }
    }

    var latestSample: DriveSample? {
        samples.last
    }

    init() {
        bootstrap()
    }

    deinit {
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }

    func collectNow() {
        Task {
            await collect(source: .manual)
        }
    }

    func saveSettings() {
        do {
            settings.collectionIntervalHours =
                CollectionSchedulePlanner.normalizedIntervalHours(
                    settings.collectionIntervalHours
                )
            try settingsRepository?.save(settings)
            applyLaunchAtLoginSetting()
            scheduleNextCollection()
        } catch {
            SilexLog.app.error("Saving settings failed: \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
        }
    }

    @discardableResult
    func saveRule(_ rule: AlertRule) -> Bool {
        do {
            try ruleRepository?.save(rule)
            rules = try ruleRepository?.all() ?? []
            presentedAlert = AppAlert(
                kind: .success,
                titleKey: "result.ruleSaved.title",
                message: localized("result.ruleSaved.message", locale: locale)
            )
            return true
        } catch {
            SilexLog.app.error("Saving rule failed: \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
            presentError(error)
            return false
        }
    }

    func addRule() {
        let rule = AlertRule(
            name: localizedDefaultRuleName(),
            metric: .temperature,
            aggregation: .maximum,
            comparison: .greaterThan,
            threshold: 60,
            isEnabled: true
        )
        saveRule(rule)
    }

    func deleteRule(_ rule: AlertRule) {
        do {
            try ruleRepository?.delete(id: rule.id)
            rules = try ruleRepository?.all() ?? []
            presentedAlert = AppAlert(
                kind: .success,
                titleKey: "result.ruleDeleted.title",
                message: localized("result.ruleDeleted.message", locale: locale)
            )
        } catch {
            SilexLog.app.error("Deleting rule failed: \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
            presentError(error)
        }
    }

    func testRule(_ rule: AlertRule) {
        Task {
            let match = AlertEngine().simulatedMatch(for: rule, now: .now)
            let status: RuleTestPresentation.NotificationStatus
            if settings.notificationsEnabled {
                do {
                    try await SystemNotificationClient().post(match)
                    status = .delivered
                } catch {
                    SilexLog.app.error(
                        "Testing rule notification failed: \(error.localizedDescription, privacy: .public)"
                    )
                    status = .failed(error.localizedDescription)
                }
            } else {
                status = .disabled
            }
            ruleTestPresentation = RuleTestPresentation(
                ruleName: match.ruleName,
                metric: match.metric,
                observedValue: match.observedValue,
                comparison: rule.comparison,
                threshold: match.threshold,
                notificationStatus: status
            )
        }
    }

    func refreshServiceStatus() async {
        serviceStatus = await serviceController.status()
        scheduleNextCollection()
    }

    func openBackgroundItemsSettings() {
        guard let url = URL(
            string:
                "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"
        ) else {
            presentedAlert = AppAlert(
                kind: .error,
                titleKey: "error.generic.title",
                message: localized("error.settingsURL.message", locale: locale)
            )
            return
        }
        NSWorkspace.shared.open(url)
    }

    func showStorageInFinder() {
        do {
            NSWorkspace.shared.activateFileViewerSelecting([
                try ApplicationPaths.applicationSupport()
            ])
        } catch {
            SilexLog.app.error("Opening storage failed: \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
            presentError(error)
        }
    }

    func exportJSON() {
        export(
            suggestedName: "Silex-history.json",
            data: try? HistoryExporter().json(samples: samples)
        )
    }

    func exportCSV() {
        export(
            suggestedName: "Silex-history.csv",
            data: HistoryExporter().csv(samples: samples)
        )
    }

    func deleteHistory() {
        do {
            try sampleRepository?.deleteAll()
            samples = []
            scheduleNextCollection(allowImmediate: false)
            presentedAlert = AppAlert(
                kind: .success,
                titleKey: "result.historyDeleted.title",
                message: localized("result.historyDeleted.message", locale: locale)
            )
        } catch {
            SilexLog.database.error("Deleting history failed: \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
            presentError(error)
        }
    }

    func navigate(by offset: Int) {
        currentPage = min(max(currentPage + offset, 0), pageCount - 1)
    }

    private func bootstrap() {
        do {
            let database = try Database(url: ApplicationPaths.databaseURL())
            let sampleRepository = SampleRepository(database: database)
            let ruleRepository = RuleRepository(database: database)
            let settingsRepository = SettingsRepository(database: database)
            self.database = database
            self.sampleRepository = sampleRepository
            self.ruleRepository = ruleRepository
            self.settingsRepository = settingsRepository
            samples = try sampleRepository.all()
            rules = try ruleRepository.all()
            settings = try settingsRepository.load()
            syncLaunchAtLoginWithSystem()
            observeWake()
            Task { [weak self] in
                await self?.refreshServiceStatus()
                await self?.syncNotificationSetting()
            }
        } catch {
            SilexLog.app.error("Application bootstrap failed: \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
            presentedAlert = AppAlert(
                kind: .error,
                titleKey: "error.database.title",
                message: error.localizedDescription
            )
        }
    }

    private func collect(source: CollectionSource) async {
        guard let sampleRepository, let ruleRepository, !isCollecting else {
            return
        }
        isCollecting = true
        defer { isCollecting = false }

        let coordinator = CollectionCoordinator(
            collector: SMARTServiceClient(),
            samples: sampleRepository,
            rules: ruleRepository,
            notifier: ConditionalAlertNotifier(
                isEnabled: settings.notificationsEnabled,
                notifier: SystemNotificationClient()
            )
        )
        do {
            let outcome = try await coordinator.collect(source: source)
            samples = try sampleRepository.all()
            rules = try ruleRepository.all()
            lastError = nil
            SilexLog.collection.info("Collected SMART sample from \(source.rawValue, privacy: .public)")
            scheduleNextCollection()
            if let failure = outcome.notificationFailures.first {
                presentedAlert = AppAlert(
                    kind: .error,
                    titleKey: "error.notification.title",
                    message: failure.message
                )
            }
        } catch {
            SilexLog.collection.error("Collection failed: \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
            presentError(error)
            await refreshServiceStatus()
        }
    }

    private func scheduleNextCollection(allowImmediate: Bool = true) {
        guard serviceStatus == .available else {
            scheduler.cancel()
            nextCollectionAt = nil
            return
        }

        let plan = CollectionSchedulePlanner.plan(
            lastCollectedAt: latestSample?.collectedAt,
            intervalHours: settings.collectionIntervalHours,
            now: .now
        )

        if allowImmediate, plan.isDueNow {
            scheduler.cancel()
            nextCollectionAt = plan.scheduledAt
            guard !isCollecting else {
                return
            }
            Task { @MainActor [weak self] in
                await self?.collect(source: .scheduled)
            }
            return
        }

        let fireAt: Date
        if !allowImmediate, latestSample == nil {
            let intervalSeconds = CollectionSchedulePlanner
                .normalizedIntervalHours(settings.collectionIntervalHours) * 3_600
            fireAt = Date.now.addingTimeInterval(intervalSeconds)
        } else {
            fireAt = plan.scheduledAt
        }

        nextCollectionAt = fireAt
        scheduler.schedule(at: fireAt) { [weak self] in
            Task { @MainActor [weak self] in
                await self?.collect(source: .scheduled)
            }
        }
    }

    private func observeWake() {
        guard wakeObserver == nil else {
            return
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleNextCollection()
            }
        }
    }

    private func syncLaunchAtLoginWithSystem() {
        applyLaunchAtLoginSetting()
    }

    private func syncNotificationSetting() async {
        let center = UNUserNotificationCenter.current()
        let notifSettings = await center.notificationSettings()
        let systemGranted = notifSettings.authorizationStatus == .authorized
            || notifSettings.authorizationStatus == .provisional
        if settings.notificationsEnabled != systemGranted {
            settings.notificationsEnabled = systemGranted
            try? settingsRepository?.save(settings)
        }
    }

    private func applyLaunchAtLoginSetting() {
        do {
            if settings.launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            SilexLog.app.error("Login item update failed: \(error.localizedDescription, privacy: .public)")
            // If unregister fails, try again
        }
    }

    private func export(suggestedName: String, data: Data?) {
        guard let data else {
            return
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        do {
            try data.write(to: url, options: .atomic)
            presentedAlert = AppAlert(
                kind: .success,
                titleKey: "result.export.title",
                message: localized("result.export.message", locale: locale)
            )
        } catch {
            SilexLog.app.error("Export failed: \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
            presentError(error)
        }
    }

    private func presentError(_ error: Error) {
        presentedAlert = AppAlert(
            kind: .error,
            titleKey: "error.generic.title",
            message: error.localizedDescription
        )
    }

    private func localizedDefaultRuleName() -> String {
        switch settings.language {
        case .simplifiedChinese:
            "新规则"
        case .system where Locale.current.language.languageCode?.identifier == "zh":
            "新规则"
        default:
            "New rule"
        }
    }
}

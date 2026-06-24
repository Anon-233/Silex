import AppKit
import Combine
import Foundation
import ServiceManagement
import SilexCore

@MainActor
final class AppModel: ObservableObject {
    @Published var samples: [DriveSample] = []
    @Published var rules: [AlertRule] = []
    @Published var settings = AppSettings()
    @Published var currentPage = 1
    @Published var range: HistoryRange = .days30
    @Published var isCollecting = false
    @Published var lastError: String?
    @Published var serviceStatus: BackgroundServiceStatus = .notRegistered
    @Published var isRuleOverlayPresented = false
    @Published var isInstallSheetPresented = false

    let pageCount = 6

    private var database: Database?
    private var sampleRepository: SampleRepository?
    private var ruleRepository: RuleRepository?
    private var settingsRepository: SettingsRepository?
    private let serviceController = ServiceController()
    private let scheduler = CollectionScheduler()

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

    func collectNow() {
        Task {
            await collect(source: .manual)
        }
    }

    func saveSettings() {
        do {
            try settingsRepository?.save(settings)
            applyLaunchAtLoginSetting()
            scheduleNextCollection()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func saveRule(_ rule: AlertRule) {
        do {
            try ruleRepository?.save(rule)
            rules = try ruleRepository?.all() ?? []
        } catch {
            lastError = error.localizedDescription
        }
    }

    func addRule() {
        let rule = AlertRule(
            name: localizedDefaultRuleName(),
            metric: .temperature,
            aggregation: .maximum,
            windowHours: 24,
            comparison: .greaterThan,
            threshold: 60,
            cooldownHours: 8,
            isEnabled: true
        )
        saveRule(rule)
    }

    func deleteRule(_ rule: AlertRule) {
        do {
            try ruleRepository?.delete(id: rule.id)
            rules = try ruleRepository?.all() ?? []
        } catch {
            lastError = error.localizedDescription
        }
    }

    func testRule(_ rule: AlertRule) {
        guard let sampleRepository, let ruleRepository else {
            return
        }
        let coordinator = CollectionCoordinator(
            collector: SMARTServiceClient(),
            samples: sampleRepository,
            rules: ruleRepository,
            notifier: SystemNotificationClient()
        )
        Task {
            do {
                _ = try await coordinator.test(rule: rule)
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func autoFillSmartctlPath() {
        settings.smartctlPath = SmartctlLocator().locate(configuredPath: settings.smartctlPath)
        saveSettings()
    }

    func enablePrivilegedService() {
        do {
            try serviceController.enable()
            refreshServiceStatus()
            if serviceStatus == .requiresApproval {
                openLoginItemsSettings()
            }
            scheduleNextCollection()
        } catch {
            lastError = error.localizedDescription
            refreshServiceStatus()
        }
    }

    func showStorageInFinder() {
        do {
            NSWorkspace.shared.activateFileViewerSelecting([
                try ApplicationPaths.applicationSupport()
            ])
        } catch {
            lastError = error.localizedDescription
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
            scheduleNextCollection()
        } catch {
            lastError = error.localizedDescription
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
            refreshServiceStatus()
            scheduleNextCollection()
        } catch {
            lastError = error.localizedDescription
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
            notifier: SystemNotificationClient()
        )
        do {
            _ = try await coordinator.collect(source: source)
            samples = try sampleRepository.all()
            rules = try ruleRepository.all()
            lastError = nil
            scheduleNextCollection()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func scheduleNextCollection() {
        guard serviceStatus == .enabled else {
            scheduler.cancel()
            return
        }
        let date = CollectionScheduler.nextCollectionDate(
            lastCollectedAt: latestSample?.collectedAt,
            intervalHours: settings.collectionIntervalHours,
            now: .now
        )
        scheduler.schedule(at: date) { [weak self] in
            Task { @MainActor [weak self] in
                await self?.collect(source: .scheduled)
            }
        }
    }

    private func refreshServiceStatus() {
        serviceStatus = serviceController.status
    }

    private func applyLaunchAtLoginSetting() {
        do {
            if settings.launchAtLogin {
                if SMAppService.mainApp.status == .notRegistered {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func openLoginItemsSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
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
        } catch {
            lastError = error.localizedDescription
        }
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


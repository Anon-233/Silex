import SwiftUI
import SilexCore

struct SettingsView: View {
    @ObservedObject var model: AppModel

    @FocusState private var intervalIsFocused: Bool
    @State private var confirmsHistoryDeletion = false
    @State private var smartctlPathText: String = ""
    @State private var showInstallSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LocalizedLabel("page.settings")
                .font(.title2.bold())
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                SettingRow(labelKey: "settings.language") {
                    Picker("", selection: $model.settings.language) {
                        LocalizedLabel("settings.followSystem")
                            .tag(LanguagePreference.system)
                        LocalizedLabel("settings.english")
                            .tag(LanguagePreference.english)
                        LocalizedLabel("settings.chinese")
                            .tag(LanguagePreference.simplifiedChinese)
                    }
                    .labelsHidden()
                    .onChange(of: model.settings.language) {
                        model.saveSettings()
                    }
                }

                SettingRow(labelKey: "settings.interval") {
                    HStack(spacing: 4) {
                        TextField(
                            "",
                            value: $model.settings.collectionIntervalHours,
                            format: .number
                        )
                        .focused($intervalIsFocused)
                        .frame(width: 56)
                        .onSubmit { model.saveSettings() }
                        LocalizedLabel("settings.intervalUnit")
                            .foregroundStyle(SilexTheme.muted)
                    }
                }

                SettingRow(labelKey: "settings.notifications") {
                    Toggle("", isOn: $model.settings.notificationsEnabled)
                        .labelsHidden()
                        .onChange(of: model.settings.notificationsEnabled) {
                            model.saveSettings()
                        }
                }

                SettingRow(labelKey: "settings.launchAtLogin") {
                    Toggle("", isOn: $model.settings.launchAtLogin)
                        .labelsHidden()
                        .onChange(of: model.settings.launchAtLogin) {
                            model.saveSettings()
                        }
                }

                SettingRow(labelKey: "settings.service") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(
                                model.serviceStatus == .available
                                    ? Color.green
                                    : Color.secondary
                            )
                            .frame(width: 7, height: 7)
                        Text(serviceStatus)
                            .font(.system(size: 13))
                        Button {
                            Task { await model.refreshServiceStatus() }
                        } label: {
                            LocalizedLabel("action.refresh")
                        }
                        .buttonStyle(SilexSecondaryButtonStyle())
                        Button {
                            model.openBackgroundItemsSettings()
                        } label: {
                            LocalizedLabel("action.backgroundItems")
                        }
                        .buttonStyle(SilexSecondaryButtonStyle())
                    }
                }

                SettingRow(labelKey: "settings.smartctl") {
                    HStack(spacing: 6) {
                        TextField(
                            localized("settings.smartctlPlaceholder", locale: model.locale),
                            text: $smartctlPathText
                        )
                        .font(.system(size: 12).monospaced())
                        .onAppear {
                            smartctlPathText = model.settings.smartctlPath ?? ""
                        }
                        .onSubmit {
                            model.settings.smartctlPath = smartctlPathText.isEmpty
                                ? nil : smartctlPathText
                            model.saveSettings()
                        }
                        Button {
                            autoDetectSmartctl()
                        } label: {
                            LocalizedLabel("action.autoDetect")
                        }
                        .buttonStyle(SilexSecondaryButtonStyle())
                        Button {
                            showInstallSheet = true
                        } label: {
                            LocalizedLabel("action.install")
                        }
                        .buttonStyle(SilexSecondaryButtonStyle())
                    }
                }

                SettingRow(labelKey: "settings.storage") {
                    HStack(spacing: 6) {
                        Text("~/Library/Application Support/Silex")
                            .font(.system(size: 12).monospaced())
                            .foregroundStyle(SilexTheme.muted)
                            .lineLimit(1)
                        Button {
                            model.showStorageInFinder()
                        } label: {
                            LocalizedLabel("action.showInFinder")
                        }
                        .buttonStyle(SilexSecondaryButtonStyle())
                    }
                }

                SettingRow(labelKey: "settings.export") {
                    HStack(spacing: 6) {
                        Button {
                            model.exportJSON()
                        } label: {
                            LocalizedLabel("settings.exportJSON")
                        }
                        .buttonStyle(SilexSecondaryButtonStyle())
                        Button {
                            model.exportCSV()
                        } label: {
                            LocalizedLabel("settings.exportCSV")
                        }
                        .buttonStyle(SilexSecondaryButtonStyle())
                        Button(role: .destructive) {
                            confirmsHistoryDeletion = true
                        } label: {
                            LocalizedLabel("settings.deleteHistory")
                        }
                        .buttonStyle(SilexSecondaryButtonStyle())
                    }
                }
            }
            .background(SilexTheme.soft)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(SilexTheme.tileLine, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Spacer(minLength: 12)

            VStack(spacing: 4) {
                Text("Silex \(appVersion)  ·  \(buildDate)")
                    .font(.system(size: 11).monospaced())
                    .foregroundStyle(SilexTheme.muted)
                Text("github.com/Anon-233/Silex")
                    .font(.system(size: 10).monospaced())
                    .foregroundStyle(SilexTheme.muted)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(12)
        .onChange(of: intervalIsFocused) {
            if !intervalIsFocused { model.saveSettings() }
        }
        .confirmationDialog(
            localized("dialog.deleteHistory.title", locale: model.locale),
            isPresented: $confirmsHistoryDeletion,
            titleVisibility: .visible
        ) {
            Button(
                localized("settings.deleteHistory", locale: model.locale),
                role: .destructive
            ) { model.deleteHistory() }
            Button(
                localized("action.cancel", locale: model.locale),
                role: .cancel
            ) {}
        } message: {
            Text(localized("dialog.deleteHistory.message", locale: model.locale))
        }
        .sheet(isPresented: $showInstallSheet) {
            InstallSmartctlView {
                showInstallSheet = false
                autoDetectSmartctl()
            }
        }
    }

    private func autoDetectSmartctl() {
        if let path = SmartctlLocator().locate(configuredPath: nil) {
            smartctlPathText = path
            model.settings.smartctlPath = path
            model.saveSettings()
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    private var buildDate: String {
        Bundle.main.object(forInfoDictionaryKey: "SilexBuildDate") as? String
            ?? localized("settings.buildDateUnknown", locale: model.locale)
    }

    private var serviceStatus: String {
        switch model.serviceStatus {
        case .available:
            localized("status.service.available", locale: model.locale)
        case .unavailable:
            localized("status.service.unavailable", locale: model.locale)
        }
    }
}

private struct SettingRow<Content: View>: View {
    let labelKey: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 10) {
            LocalizedLabel(labelKey)
                .font(.system(size: 12))
                .foregroundStyle(SilexTheme.muted)
                .frame(width: 110, alignment: .leading)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(SilexTheme.tileLine)
                .frame(height: 1)
        }
    }
}

// MARK: - Smartctl Install Sheet

private struct InstallSmartctlView: View {
    let onDone: () -> Void

    @State private var output: String = ""
    @State private var isRunning = false
    @State private var exitCode: Int32 = 0
    @State private var didComplete = false
    @State private var process: Process?

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("brew install smartmontools")
                    .font(.headline)
                Spacer()
                if !isRunning {
                    Button {
                        onDone()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                }
            }

            if didComplete {
                HStack {
                    Circle()
                        .fill(exitCode == 0 ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(exitCode == 0
                         ? "Installation complete"
                         : "Installation failed (exit \(exitCode))")
                        .font(.system(size: 13))
                    Spacer()
                }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    Text(output.isEmpty ? "$ brew install smartmontools\nWaiting…" : output)
                        .font(.system(size: 12).monospaced())
                        .foregroundStyle(Color(.displayP3, white: 0.85, opacity: 1))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .id("bottom")
                }
                .onChange(of: output) {
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            .frame(height: 220)
            .padding(12)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack {
                if !didComplete {
                    if isRunning {
                        Button {
                            process?.terminate()
                        } label: {
                            Label("Stop", systemImage: "stop.fill")
                                .frame(minWidth: 80)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    } else {
                        Button {
                            startInstall()
                        } label: {
                            Label("Run", systemImage: "play.fill")
                                .frame(minWidth: 80)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                Spacer()
                if didComplete {
                    Button {
                        onDone()
                    } label: {
                        Text("Done")
                            .frame(minWidth: 80)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(16)
        .frame(width: 600)
    }

    private func startInstall() {
        isRunning = true
        output = "$ brew install smartmontools\n"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")
        process.arguments = ["install", "smartmontools"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                output += text
            }
        }
        process.terminationHandler = { proc in
            DispatchQueue.main.async {
                isRunning = false
                didComplete = true
                exitCode = proc.terminationStatus
                if exitCode != 0 {
                    output += "\nProcess exited with code \(exitCode)"
                }
            }
        }
        self.process = process
        try? process.run()
    }
}

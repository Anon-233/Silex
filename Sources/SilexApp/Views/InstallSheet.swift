import Foundation
import SwiftUI

struct InstallSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var installer = BrewInstaller()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                LocalizedLabel("install.title")
                    .font(.title2.bold())
                Spacer()
                Button {
                    dismiss()
                } label: {
                    LocalizedLabel("action.close")
                }
                .disabled(installer.isRunning)
            }

            HStack {
                LocalizedLabel("install.command")
                    .foregroundStyle(.secondary)
                Text("brew install smartmontools")
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }

            LocalizedLabel("install.output")
                .font(.headline)

            ScrollView {
                Text(installer.output)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.green)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(10)
            }
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            HStack {
                Spacer()
                Button {
                    installer.run()
                } label: {
                    LocalizedLabel("action.run")
                }
                .buttonStyle(.borderedProminent)
                .disabled(installer.isRunning)
            }
        }
        .padding(18)
        .frame(width: 650, height: 430)
    }
}

@MainActor
private final class BrewInstaller: ObservableObject {
    @Published var output = "$ brew install smartmontools\n"
    @Published var isRunning = false
    private var process: Process?

    func run() {
        guard !isRunning else {
            return
        }
        guard let brew = brewPath() else {
            output += "brew was not found in /opt/homebrew/bin or /usr/local/bin.\n"
            return
        }

        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: brew)
        process.arguments = ["install", "smartmontools"]
        process.standardOutput = pipe
        process.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                return
            }
            Task { @MainActor [weak self] in
                self?.output += String(decoding: data, as: UTF8.self)
            }
        }
        process.terminationHandler = { [weak self] _ in
            pipe.fileHandleForReading.readabilityHandler = nil
            Task { @MainActor [weak self] in
                self?.isRunning = false
                self?.output += "\nProcess finished.\n"
            }
        }

        do {
            isRunning = true
            output = "$ brew install smartmontools\n"
            self.process = process
            try process.run()
        } catch {
            isRunning = false
            output += "\(error.localizedDescription)\n"
        }
    }

    private func brewPath() -> String? {
        ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
            .first(where: FileManager.default.isExecutableFile)
    }
}


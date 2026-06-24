import SwiftUI

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
                            if value.translation.width < -60 {
                                model.navigate(by: 1)
                            } else if value.translation.width > 60 {
                                model.navigate(by: -1)
                            }
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
        .sheet(isPresented: $model.isInstallSheetPresented) {
            InstallSheet()
                .environment(\.locale, model.locale)
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
        HStack {
            Button {
                model.navigate(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            .disabled(model.currentPage == 0)
            .accessibilityLabel(localized("action.previous", locale: model.locale))

            Spacer()
            HStack(spacing: 7) {
                ForEach(0..<model.pageCount, id: \.self) { index in
                    Capsule()
                        .fill(index == model.currentPage ? Color.green : Color.secondary.opacity(0.3))
                        .frame(width: index == model.currentPage ? 20 : 7, height: 7)
                        .onTapGesture {
                            model.currentPage = index
                        }
                }
            }
            Spacer()

            Button {
                model.navigate(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .disabled(model.currentPage == model.pageCount - 1)
            .accessibilityLabel(localized("action.next", locale: model.locale))
        }
        .padding(.horizontal, 4)
    }
}


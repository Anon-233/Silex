import SwiftUI

struct SettingsCard<Content: View>: View {
    let titleKey: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LocalizedLabel(titleKey)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.62))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(.quaternary)
        }
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

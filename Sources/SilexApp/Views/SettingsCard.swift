import SwiftUI

struct SettingsCard<Content: View>: View {
    let titleKey: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LocalizedLabel(titleKey)
                .font(.caption)
                .foregroundStyle(SilexTheme.muted)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .background(SilexTheme.soft)
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(SilexTheme.tileLine, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

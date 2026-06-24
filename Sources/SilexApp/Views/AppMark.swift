import SwiftUI

struct AppMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(SilexTheme.card)
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(SilexTheme.controlText, lineWidth: 2)
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(SilexTheme.controlText)
                .padding(5)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

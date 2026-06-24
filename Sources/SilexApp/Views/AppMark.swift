import SwiftUI

struct AppMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(Color.secondary, lineWidth: 2)
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(Color.secondary)
                .padding(5)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}


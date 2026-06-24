import SwiftUI

struct OverviewMetricCard: View {
    let titleKey: String
    let value: String
    let usesMonospacedDigits: Bool

    init(
        _ titleKey: String,
        value: String,
        usesMonospacedDigits: Bool = true
    ) {
        self.titleKey = titleKey
        self.value = value
        self.usesMonospacedDigits = usesMonospacedDigits
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LocalizedLabel(titleKey)
                .font(.system(size: 12))
                .foregroundStyle(SilexTheme.muted)
                .lineLimit(1)
            Group {
                if usesMonospacedDigits {
                    Text(value).monospacedDigit()
                } else {
                    Text(value)
                }
            }
            .font(.system(size: 22, weight: .heavy))
            .foregroundStyle(SilexTheme.text)
            .lineLimit(1)
            .minimumScaleFactor(0.58)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(SilexTheme.soft)
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(SilexTheme.tileLine, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

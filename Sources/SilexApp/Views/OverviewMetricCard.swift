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
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Group {
                if usesMonospacedDigits {
                    Text(value).monospacedDigit()
                } else {
                    Text(value)
                }
            }
            .font(.title3.bold())
            .lineLimit(1)
            .minimumScaleFactor(0.58)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.62))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(.quaternary)
        }
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

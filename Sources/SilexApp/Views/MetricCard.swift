import SwiftUI

struct MetricCard: View {
    let titleKey: String
    let value: String
    let firstLabelKey: String
    let firstValue: String
    let secondLabelKey: String
    let secondValue: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Circle()
                        .fill(color)
                        .frame(width: 9, height: 9)
                    LocalizedLabel(titleKey)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Text(value)
                    .font(.title2.bold().monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                HStack {
                    statistic(firstLabelKey, firstValue)
                    Spacer()
                    statistic(secondLabelKey, secondValue)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
            .background(isSelected ? color.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? color : .clear, lineWidth: 1.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func statistic(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            LocalizedLabel(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.bold().monospacedDigit())
                .lineLimit(1)
        }
    }
}


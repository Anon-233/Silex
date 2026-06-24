import AppKit
import SwiftUI

enum SilexTheme {
    static let background = adaptive(light: 0xEEF2F6, dark: 0x0F172A)
    static let card = adaptive(light: 0xFFFFFF, dark: 0x111827)
    static let soft = adaptive(light: 0xF8FAFC, dark: 0x182235)
    static let line = adaptive(light: 0xD6DEE9, dark: 0x334155)
    static let tileLine = adaptive(light: 0xE2E8F0, dark: 0x334155)
    static let text = adaptive(light: 0x142033, dark: 0xE5EDF8)
    static let muted = adaptive(light: 0x64748B, dark: 0x94A3B8)
    static let controlText = adaptive(light: 0x334155, dark: 0xCBD5E1)

    static let blue = Color(nsColor: color(0x2563EB))
    static let green = Color(nsColor: color(0x16A34A))
    static let amber = Color(nsColor: color(0xD97706))
    static let red = Color(nsColor: color(0xDC2626))
    static let cyan = Color(nsColor: color(0x0891B2))
    static let purple = Color(nsColor: color(0x7C3AED))
    static let healthyPill = adaptive(light: 0xDCFCE7, dark: 0x14532D)
    static let healthyPillText = adaptive(light: 0x166534, dark: 0xBBF7D0)
    static let failedPill = adaptive(light: 0xFEE2E2, dark: 0x7F1D1D)
    static let failedPillText = adaptive(light: 0x991B1B, dark: 0xFECACA)

    private static func adaptive(light: Int, dark: Int) -> Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                let match = appearance.bestMatch(from: [.darkAqua, .aqua])
                return color(match == .darkAqua ? dark : light)
            }
        )
    }

    private static func color(_ hex: Int) -> NSColor {
        NSColor(
            calibratedRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

struct SilexSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .foregroundStyle(SilexTheme.controlText)
            .padding(.horizontal, 11)
            .frame(height: 29)
            .background(SilexTheme.card)
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(SilexTheme.line, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

struct SilexPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 11)
            .frame(height: 29)
            .background(SilexTheme.blue)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .opacity(configuration.isPressed ? 0.76 : 1)
    }
}

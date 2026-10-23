import AppKit
import SwiftUI
import TimeTrackerCore

extension StateColor {
    /// SwiftUI color for a palette entry.
    var swatch: Color {
        switch self {
        case .green: return .green
        case .grey: return .gray
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .blue: return .blue
        case .purple: return .purple
        }
    }

    /// AppKit color for menubar icon tinting.
    var nsColor: NSColor {
        switch self {
        case .green: return .systemGreen
        case .grey: return .systemGray
        case .red: return .systemRed
        case .orange: return .systemOrange
        case .yellow: return .systemYellow
        case .blue: return .systemBlue
        case .purple: return .systemPurple
        }
    }
}

/// Capsule chip showing a state's label tinted with its palette color.
struct StateChip: View {
    let style: StateStyle
    var compact = false

    var body: some View {
        Text(style.label)
            .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
            .padding(.horizontal, compact ? 6 : 8)
            .padding(.vertical, compact ? 1 : 2)
            .foregroundStyle(style.color.swatch)
            .background(style.color.swatch.opacity(0.18), in: Capsule())
    }
}

extension Check {
    /// States with v1 defaults applied: "In range" green / "Out" grey.
    var displayStates: CheckStates {
        states ?? CheckStates(
            active: StateStyle(label: "In range", color: .green),
            inactive: StateStyle(label: "Out", color: .grey)
        )
    }
}

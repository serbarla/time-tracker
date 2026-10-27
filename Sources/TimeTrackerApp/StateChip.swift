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

    /// Filled-circle swatch for menu rows. Menu-style pickers render through
    /// NSMenu: template images are tinted with the label color (flattening
    /// every entry to grey) and SwiftUI shapes don't render at all, so the
    /// circle must be drawn into a non-template NSImage.
    var swatchImage: NSImage {
        let side: CGFloat = 12
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()
        nsColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: 0, y: 0, width: side, height: side)).fill()
        image.unlockFocus()
        image.isTemplate = false
        return image
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
            .background(Color.white, in: Capsule())
            .overlay(Capsule().stroke(style.color.swatch, lineWidth: 1))
    }
}

extension Check {
    /// States with v1 defaults applied: catalog "In range" green / "Out" grey,
    /// resolved at display time so a language switch re-renders them.
    @MainActor
    var displayStates: CheckStates {
        states ?? CheckStates(
            active: StateStyle(label: Localization.shared.t("state.active"), color: .green),
            inactive: StateStyle(label: Localization.shared.t("state.inactive"), color: .grey)
        )
    }
}

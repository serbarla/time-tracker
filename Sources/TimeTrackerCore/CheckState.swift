import Foundation

/// Palette for check states (store version 2, display-only).
public enum StateColor: String, Codable, Hashable, Sendable, CaseIterable {
    case green, grey, red, orange, yellow, blue, purple
}

/// One named state's display style: label, palette color, optional note.
public struct StateStyle: Codable, Hashable, Sendable {
    public var label: String
    public var color: StateColor
    public var note: String?

    public init(label: String, color: StateColor, note: String? = nil) {
        self.label = label
        self.color = color
        self.note = note
    }
}

/// The two states of the window machine. `nil` on a check = the v1 defaults
/// ("In range" green / "Out" grey), so v1 files look and behave as today.
public struct CheckStates: Codable, Hashable, Sendable {
    public var active: StateStyle
    public var inactive: StateStyle

    public init(active: StateStyle, inactive: StateStyle) {
        self.active = active
        self.inactive = inactive
    }
}

/// Display-only detail row (e.g. a rate table); shown in the status UI.
public struct DetailRow: Codable, Hashable, Sendable {
    public var name: String
    public var active: String
    public var inactive: String

    public init(name: String, active: String, inactive: String) {
        self.name = name
        self.active = active
        self.inactive = inactive
    }
}

/// A day-level override: an inclusive date range (in the check's zone) that
/// forces the check's state regardless of the schedule.
public struct DayOverride: Codable, Hashable, Sendable {
    public enum Mode: String, Codable, Hashable, Sendable {
        case forceActive
        case forceInactive
    }

    /// Inclusive start date, "yyyy-MM-dd" in the check's zone.
    public var from: String
    /// Inclusive end date, "yyyy-MM-dd" in the check's zone.
    public var to: String
    public var mode: Mode
    public var label: String

    public init(from: String, to: String, mode: Mode, label: String) {
        self.from = from
        self.to = to
        self.mode = mode
        self.label = label
    }
}

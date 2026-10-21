import Foundation

/// Days of the week for scheduling, Monday-first.
public enum Weekday: Int, CaseIterable, Identifiable, Hashable, Sendable {
    case mon = 1, tue, wed, thu, fri, sat, sun

    public var id: Int { rawValue }

    /// Key used in the JSON schedule dictionary.
    public var jsonKey: String {
        switch self {
        case .mon: return "mon"
        case .tue: return "tue"
        case .wed: return "wed"
        case .thu: return "thu"
        case .fri: return "fri"
        case .sat: return "sat"
        case .sun: return "sun"
        }
    }

    /// Short display name, e.g. "Mon".
    public var shortName: String {
        switch self {
        case .mon: return "Mon"
        case .tue: return "Tue"
        case .wed: return "Wed"
        case .thu: return "Thu"
        case .fri: return "Fri"
        case .sat: return "Sat"
        case .sun: return "Sun"
        }
    }

    /// Foundation Gregorian weekday (1 = Sunday ... 7 = Saturday).
    public var calendarWeekday: Int {
        switch self {
        case .sun: return 1
        case .mon: return 2
        case .tue: return 3
        case .wed: return 4
        case .thu: return 5
        case .fri: return 6
        case .sat: return 7
        }
    }

    public init?(calendarWeekday: Int) {
        switch calendarWeekday {
        case 1: self = .sun
        case 2: self = .mon
        case 3: self = .tue
        case 4: self = .wed
        case 5: self = .thu
        case 6: self = .fri
        case 7: self = .sat
        default: return nil
        }
    }

    public var previous: Weekday {
        Weekday(rawValue: (rawValue - 2 + 7) % 7 + 1)!
    }
}

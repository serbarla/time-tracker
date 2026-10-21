import Foundation

/// A half-open working-hour range `[start, end)` in wall-clock time of the check's zone.
public struct HourRange: Codable, Hashable, Equatable, Sendable {
    /// Start wall-clock time, "HH:mm" (24h).
    public var start: String
    /// End wall-clock time, "HH:mm" (24h).
    public var end: String

    public init(start: String, end: String) {
        self.start = start
        self.end = end
    }

    /// Minutes since midnight, nil if malformed.
    public var startMinutes: Int? { Self.minutes(start) }
    public var endMinutes: Int? { Self.minutes(end) }

    /// True when the range rolls past midnight (`end <= start`).
    public var isOvernight: Bool {
        guard let s = startMinutes, let e = endMinutes else { return false }
        return e <= s
    }

    /// Both times parse and the range is non-degenerate (not a full day).
    public var isValid: Bool {
        guard let s = startMinutes, let e = endMinutes else { return false }
        return s != e
    }

    /// Parses "HH:mm" into minutes since midnight; nil if malformed.
    public static func minutes(_ hhmm: String) -> Int? {
        let parts = hhmm.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let h = Int(parts[0]), let m = Int(parts[1]),
              (0..<24).contains(h), (0..<60).contains(m) else { return nil }
        return h * 60 + m
    }
}

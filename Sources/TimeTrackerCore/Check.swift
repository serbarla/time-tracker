import Foundation

/// One check: a named remote time zone plus its per-weekday working-hour ranges.
public struct Check: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var timeZoneIdentifier: String
    /// Keys "mon".."sun" -> working-hour ranges in the remote zone's wall clock.
    public var schedule: [String: [HourRange]]

    public init(
        id: UUID = UUID(),
        name: String,
        timeZoneIdentifier: String,
        schedule: [String: [HourRange]] = Check.emptySchedule
    ) {
        self.id = id
        self.name = name
        self.timeZoneIdentifier = timeZoneIdentifier
        self.schedule = schedule
    }

    public var timeZone: TimeZone { TimeZone(identifier: timeZoneIdentifier) ?? .current }

    public func ranges(for weekday: Weekday) -> [HourRange] {
        schedule[weekday.jsonKey] ?? []
    }

    public static let emptySchedule: [String: [HourRange]] = {
        var d: [String: [HourRange]] = [:]
        for w in Weekday.allCases { d[w.jsonKey] = [] }
        return d
    }()
}

/// Top-level JSON document (versioned for forward compatibility).
public struct ChecksFile: Codable, Sendable {
    public var version: Int
    public var checks: [Check]

    public init(version: Int = 1, checks: [Check]) {
        self.version = version
        self.checks = checks
    }
}

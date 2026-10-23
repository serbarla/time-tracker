import Foundation

/// One check: a named remote time zone plus its per-weekday working-hour ranges.
public struct Check: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var timeZoneIdentifier: String
    /// Keys "mon".."sun" -> working-hour ranges in the remote zone's wall clock.
    public var schedule: [String: [HourRange]]
    /// Named states for the window machine; nil = v1 defaults ("In range"/"Out").
    public var states: CheckStates?
    /// Display-only detail rows (v2; absent in v1 files).
    public var details: [DetailRow]
    /// Day-level overrides that force the state regardless of schedule (v2).
    public var dayOverrides: [DayOverride]
    /// Whether the app should notify when the state flips (v2).
    public var notifyOnFlip: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        timeZoneIdentifier: String,
        schedule: [String: [HourRange]] = Check.emptySchedule,
        states: CheckStates? = nil,
        details: [DetailRow] = [],
        dayOverrides: [DayOverride] = [],
        notifyOnFlip: Bool = false
    ) {
        self.id = id
        self.name = name
        self.timeZoneIdentifier = timeZoneIdentifier
        self.schedule = schedule
        self.states = states
        self.details = details
        self.dayOverrides = dayOverrides
        self.notifyOnFlip = notifyOnFlip
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

    // v2 fields decode tolerantly: absent keys -> nil / [] / false, so v1
    // files load unchanged. Empty collections are omitted on write to keep
    // the persisted shape close to v1; `notifyOnFlip` is always written so
    // an explicit off-state survives a save.

    private enum CodingKeys: String, CodingKey {
        case id, name, timeZoneIdentifier, schedule
        case states, details, dayOverrides, notifyOnFlip
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        timeZoneIdentifier = try c.decode(String.self, forKey: .timeZoneIdentifier)
        schedule = try c.decode([String: [HourRange]].self, forKey: .schedule)
        states = try c.decodeIfPresent(CheckStates.self, forKey: .states)
        details = try c.decodeIfPresent([DetailRow].self, forKey: .details) ?? []
        dayOverrides = try c.decodeIfPresent([DayOverride].self, forKey: .dayOverrides) ?? []
        notifyOnFlip = try c.decodeIfPresent(Bool.self, forKey: .notifyOnFlip) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(timeZoneIdentifier, forKey: .timeZoneIdentifier)
        try c.encode(schedule, forKey: .schedule)
        try c.encodeIfPresent(states, forKey: .states)
        if !details.isEmpty { try c.encode(details, forKey: .details) }
        if !dayOverrides.isEmpty { try c.encode(dayOverrides, forKey: .dayOverrides) }
        try c.encode(notifyOnFlip, forKey: .notifyOnFlip)
    }
}

/// Top-level JSON document (versioned for forward compatibility).
public struct ChecksFile: Codable, Sendable {
    /// Version written by the current store; version 1 files load unchanged.
    public static let currentVersion = 2

    public var version: Int
    public var checks: [Check]

    public init(version: Int = 1, checks: [Check]) {
        self.version = version
        self.checks = checks
    }
}

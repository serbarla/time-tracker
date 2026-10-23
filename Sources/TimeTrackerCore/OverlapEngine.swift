import Foundation

/// Result of evaluating a check at a given instant.
public struct OverlapState: Equatable, Sendable {
    /// Whether `now` falls inside any working-hour range.
    public var isOverlapping: Bool
    /// The active range containing `now`, if any.
    public var activeRange: HourRange?
    /// Absolute interval of the active band containing `now`, if any.
    public var activeInterval: DateInterval?
    /// Overlap bands as absolute intervals (relevant to `now`; may span local midnight).
    public var bands: [DateInterval]
    /// Start of the maximal same-state stretch containing `now`, if bounded.
    public var windowStart: Date?
    /// First future state change, nil if none within the forward scan bound.
    public var nextTransition: Date?
    /// Windows from the current one forward: the first slice contains `now`.
    public var upcoming: [WindowSlice]

    public init(
        isOverlapping: Bool,
        activeRange: HourRange? = nil,
        activeInterval: DateInterval? = nil,
        bands: [DateInterval] = [],
        windowStart: Date? = nil,
        nextTransition: Date? = nil,
        upcoming: [WindowSlice] = []
    ) {
        self.isOverlapping = isOverlapping
        self.activeRange = activeRange
        self.activeInterval = activeInterval
        self.bands = bands
        self.windowStart = windowStart
        self.nextTransition = nextTransition
        self.upcoming = upcoming
    }
}

/// One maximal same-state window; the first slice of `upcoming` contains `now`.
public struct WindowSlice: Equatable, Hashable, Sendable {
    public var start: Date
    public var end: Date
    public var isActive: Bool

    public init(start: Date, end: Date, isActive: Bool) {
        self.start = start
        self.end = end
        self.isActive = isActive
    }
}

/// Pure overlap evaluation. Time-zone agnostic to the caller's local zone: it reasons
/// only about `now` (an absolute instant) and the check's remote calendar, so DST and
/// cross-midnight ranges are handled by the system `Calendar`/`TimeZone`.
public enum OverlapEngine {
    /// Forward (and backward) bound for transition scans, mirroring the reference
    /// implementation's bounded walk.
    static let scanHorizon = 14 * 24 * 3600.0
    /// Half-open membership probe offset: a boundary instant belongs to the window
    /// *after* it, so "just after b" = b + epsilon and "just before b" = b - epsilon.
    static let boundaryEpsilon: TimeInterval = 1

    public static func evaluate(check: Check, now: Date) -> OverlapState {
        var remote = Calendar(identifier: .gregorian)
        remote.timeZone = check.timeZone

        let todayStart = remote.startOfDay(for: now)
        let weekday = Weekday(calendarWeekday: remote.component(.weekday, from: now)) ?? .mon

        var bands: [DateInterval] = []
        var active: (range: HourRange, interval: DateInterval)?

        // Today's ranges, anchored to remote today.
        for range in check.ranges(for: weekday) {
            guard let interval = interval(for: range, onDayStart: todayStart, calendar: remote) else { continue }
            bands.append(interval)
            if active == nil, contains(interval, now) { active = (range, interval) }
        }

        // Yesterday's overnight ranges, spilling into today.
        if let yesterdayStart = remote.date(byAdding: .day, value: -1, to: todayStart) {
            for range in check.ranges(for: weekday.previous) {
                guard range.isOvernight,
                      let interval = interval(for: range, onDayStart: yesterdayStart, calendar: remote) else { continue }
                bands.append(interval)
                if active == nil, contains(interval, now) { active = (range, interval) }
            }
        }

        // Day overrides win over the schedule, so a forced state hides the band.
        let forced = forcedMode(check: check, at: now, calendar: remote)
        if forced != nil { active = nil }
        let isOverlapping = forced == .forceActive || (forced == nil && active != nil)

        let currentStart = windowStart(check: check, now: now, calendar: remote)
        let firstChange = nextTransition(check: check, now: now, calendar: remote)
        return OverlapState(
            isOverlapping: isOverlapping,
            activeRange: active?.range,
            activeInterval: active?.interval,
            bands: bands,
            windowStart: currentStart,
            nextTransition: firstChange,
            upcoming: upcomingSlices(
                check: check, now: now, calendar: remote,
                currentWindowStart: currentStart, nextChange: firstChange
            )
        )
    }

    /// Half-open membership `start <= date < end`, matching the documented `[start, end)` semantics.
    /// `DateInterval.contains` is inclusive of the end, which we do not want here.
    static func contains(_ interval: DateInterval, _ date: Date) -> Bool {
        date >= interval.start && date < interval.end
    }

    /// Whether the schedule or a day override makes the check active at `at`.
    /// Overrides win per instant; malformed override dates/modes are ignored.
    static func isActive(check: Check, at: Date, calendar: Calendar) -> Bool {
        switch forcedMode(check: check, at: at, calendar: calendar) {
        case .forceActive: return true
        case .forceInactive: return false
        case nil: return scheduleActive(check: check, at: at, calendar: calendar)
        }
    }

    /// Schedule-only membership (today's bands + yesterday's overnight spillover).
    private static func scheduleActive(check: Check, at: Date, calendar: Calendar) -> Bool {
        let todayStart = calendar.startOfDay(for: at)
        let weekday = Weekday(calendarWeekday: calendar.component(.weekday, from: at)) ?? .mon
        for range in check.ranges(for: weekday) {
            if let interval = interval(for: range, onDayStart: todayStart, calendar: calendar),
               contains(interval, at) { return true }
        }
        if let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart) {
            for range in check.ranges(for: weekday.previous) where range.isOvernight {
                if let interval = interval(for: range, onDayStart: yesterdayStart, calendar: calendar),
                   contains(interval, at) { return true }
            }
        }
        return false
    }

    /// The override covering `at`'s check-zone date, if any (inclusive `from`/`to`).
    static func forcedMode(check: Check, at: Date, calendar: Calendar) -> DayOverride.Mode? {
        guard !check.dayOverrides.isEmpty,
              let key = dayKey(for: at, calendar: calendar) else { return nil }
        for override in check.dayOverrides {
            guard let from = dayKey(override.from), let to = dayKey(override.to), from <= to else { continue }
            if key >= from && key <= to { return override.mode }
        }
        return nil
    }

    /// Start of the maximal same-state stretch containing `now`: the latest boundary
    /// at or before `now` where the state changes walking backwards (matching the
    /// reference implementation's `currentWindowStart`). Falls back to the start of
    /// the backward scan horizon when no such boundary is found.
    static func windowStart(check: Check, now: Date, calendar: Calendar) -> Date {
        let horizonStart = now.addingTimeInterval(-scanHorizon)
        let state = isActive(check: check, at: now, calendar: calendar)
        var best: Date?
        for b in stateBoundaries(check: check, from: horizonStart, to: now, calendar: calendar)
        where b > horizonStart && b <= now {
            let before = isActive(check: check, at: b.addingTimeInterval(-boundaryEpsilon), calendar: calendar)
            let after = isActive(check: check, at: b.addingTimeInterval(boundaryEpsilon), calendar: calendar)
            if before != state && after == state, best.map({ b > $0 }) ?? true { best = b }
        }
        return best ?? horizonStart
    }

    /// First future instant where the state changes: the earliest boundary after
    /// `now` whose far side differs from the state at `now` (touching same-state
    /// boundaries are skipped). Nil when the state never changes within the
    /// forward scan horizon.
    static func nextTransition(check: Check, now: Date, calendar: Calendar) -> Date? {
        let state = isActive(check: check, at: now, calendar: calendar)
        for b in stateBoundaries(check: check, from: now, to: now.addingTimeInterval(scanHorizon), calendar: calendar)
        where b > now {
            if isActive(check: check, at: b.addingTimeInterval(boundaryEpsilon), calendar: calendar) != state {
                return b
            }
        }
        return nil
    }

    /// Windows from the current one forward (first slice contains `now`), following
    /// transitions until the scan horizon.
    static func upcomingSlices(
        check: Check, now: Date, calendar: Calendar,
        currentWindowStart: Date?, nextChange: Date?
    ) -> [WindowSlice] {
        let horizonEnd = now.addingTimeInterval(scanHorizon)
        let state = isActive(check: check, at: now, calendar: calendar)
        var slices: [WindowSlice] = []
        var start = currentWindowStart ?? horizonEnd
        var isCurrent = state
        var cursor = now
        var transition = nextChange
        for _ in 0..<1_000 {
            // Emit while the window opens inside the horizon; always emit the
            // current window (first iteration) even if it starts earlier.
            if !slices.isEmpty && start >= horizonEnd { break }
            let end: Date
            if let t = transition, t <= horizonEnd {
                end = t
                cursor = t
                transition = nextTransition(check: check, now: t.addingTimeInterval(boundaryEpsilon), calendar: calendar)
            } else {
                end = horizonEnd
                transition = nil
            }
            slices.append(WindowSlice(start: start, end: end, isActive: isCurrent))
            start = cursor
            isCurrent.toggle()
            if transition == nil { break }
        }
        return slices
    }

    /// Candidate state-change instants in `(from, to]`: every schedule band start/end
    /// and every override day boundary in that range. Sorted ascending.
    static func stateBoundaries(check: Check, from: Date, to: Date, calendar: Calendar) -> [Date] {
        guard to > from else { return [] }
        var days: [Date] = []
        var day = calendar.startOfDay(for: from)
        while day <= to {
            days.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        var candidates: [Date] = []
        for dayStart in days {
            let weekday = Weekday(calendarWeekday: calendar.component(.weekday, from: dayStart)) ?? .mon
            for range in check.ranges(for: weekday) {
                guard let band = interval(for: range, onDayStart: dayStart, calendar: calendar) else { continue }
                candidates.append(band.start)
                candidates.append(band.end)
            }
        }
        if !check.dayOverrides.isEmpty {
            for dayStart in days {
                candidates.append(dayStart)                    // override day begins
                if let next = calendar.date(byAdding: .day, value: 1, to: dayStart) {
                    candidates.append(next)                   // day after an override ends it
                }
            }
        }
        return candidates.filter { $0 > from && $0 <= to }.sorted()
    }

    /// Builds the absolute interval for a range anchored to a given day's start.
    static func interval(for range: HourRange, onDayStart dayStart: Date, calendar: Calendar) -> DateInterval? {
        guard let s = range.startMinutes, let e = range.endMinutes else { return nil }
        guard let startDate = date(minutesSinceMidnight: s, onDayStart: dayStart, calendar: calendar) else { return nil }
        var endDate = date(minutesSinceMidnight: e, onDayStart: dayStart, calendar: calendar) ?? startDate
        if endDate <= startDate { // overnight: roll into the next day
            endDate = calendar.date(byAdding: .day, value: 1, to: endDate) ?? endDate
        }
        return DateInterval(start: startDate, end: endDate)
    }

    /// Builds an absolute date from wall-clock components (DST-correct, unlike adding
    /// minutes to `startOfDay`).
    static func date(minutesSinceMidnight minutes: Int, onDayStart dayStart: Date, calendar: Calendar) -> Date? {
        var comp = calendar.dateComponents([.year, .month, .day], from: dayStart)
        comp.hour = minutes / 60
        comp.minute = minutes % 60
        comp.second = 0
        return calendar.date(from: comp)
    }

    /// "yyyy-MM-dd" key of an instant in the check's zone; nil if the instant cannot
    /// be resolved (never happens for real dates).
    static func dayKey(for date: Date, calendar: Calendar) -> String? {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        guard let y = c.year, let mo = c.month, let d = c.day else { return nil }
        return String(format: "%04d-%02d-%02d", y, mo, d)
    }

    /// Strict "yyyy-MM-dd" parser; malformed or impossible dates return nil
    /// (overridden at call sites: malformed overrides are ignored, never fatal).
    static func dayKey(_ yyyyMMdd: String) -> String? {
        let parts = yyyyMMdd.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) }),
              let y = Int(parts[0]), let mo = Int(parts[1]), let d = Int(parts[2]),
              (1...12).contains(mo), (1...31).contains(d) else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        guard let date = cal.date(from: DateComponents(year: y, month: mo, day: d)),
              let roundTrip = dayKey(for: date, calendar: cal) else { return nil }
        return roundTrip == yyyyMMdd ? roundTrip : nil // rejects 2026-02-31 etc.
    }
}

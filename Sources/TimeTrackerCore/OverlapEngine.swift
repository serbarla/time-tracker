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
}

/// Pure overlap evaluation. Time-zone agnostic to the caller's local zone: it reasons
/// only about `now` (an absolute instant) and the check's remote calendar, so DST and
/// cross-midnight ranges are handled by the system `Calendar`/`TimeZone`.
public enum OverlapEngine {
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

        return OverlapState(
            isOverlapping: active != nil,
            activeRange: active?.range,
            activeInterval: active?.interval,
            bands: bands
        )
    }

    /// Half-open membership `start <= date < end`, matching the documented `[start, end)` semantics.
    /// `DateInterval.contains` is inclusive of the end, which we do not want here.
    static func contains(_ interval: DateInterval, _ date: Date) -> Bool {
        date >= interval.start && date < interval.end
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
}

import TimeTrackerCore

/// Built-in check templates offered from the Edit tab.
///
/// Data only: the overlap engine stays zone/schedule-generic, and every field
/// remains user-editable after the check is created through `store.add`.
enum CheckPresets {
    /// DeepSeek API peak/off-peak pricing, expressed as a normal check:
    /// Beijing weekday 09:00–12:00 and 14:00–18:00 = peak; everything else,
    /// including weekends and the listed holidays, is off-peak.
    static func deepSeekPricing() -> Check {
        var schedule = Check.emptySchedule
        for weekday in [Weekday.mon, .tue, .wed, .thu, .fri] {
            schedule[weekday.jsonKey] = [
                HourRange(start: "09:00", end: "12:00"),
                HourRange(start: "14:00", end: "18:00"),
            ]
        }

        return Check(
            name: "DeepSeek pricing",
            timeZoneIdentifier: "Asia/Shanghai",
            schedule: schedule,
            states: CheckStates(
                active: StateStyle(label: "Peak pricing", color: .red),
                inactive: StateStyle(label: "Off-peak · half price", color: .green)
            ),
            details: [
                DetailRow(name: "V4.1 Flash input · per 1M tokens", active: "$0.30", inactive: "$0.15"),
                DetailRow(name: "V4.1 Flash cached · per 1M tokens", active: "$0.006", inactive: "$0.003"),
                DetailRow(name: "V4.1 Flash output · per 1M tokens", active: "$1.20", inactive: "$0.60"),
                DetailRow(name: "V4 Pro input · per 1M tokens", active: "$1.32", inactive: "$0.66"),
                DetailRow(name: "V4 Pro cached · per 1M tokens", active: "$0.044", inactive: "$0.022"),
                DetailRow(name: "V4 Pro output · per 1M tokens", active: "$3.96", inactive: "$1.98"),
            ],
            dayOverrides: [
                DayOverride(from: "2026-09-25", to: "2026-09-27", mode: .forceInactive, label: "Mid-Autumn"),
                DayOverride(from: "2026-10-01", to: "2026-10-07", mode: .forceInactive, label: "National Day"),
            ],
            notifyOnFlip: false
        )
    }
}

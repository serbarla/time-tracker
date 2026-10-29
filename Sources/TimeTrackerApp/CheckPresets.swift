import TimeTrackerCore

/// Built-in check templates offered from the Edit tab.
///
/// Data only: the overlap engine stays zone/schedule-generic, and every field
/// remains user-editable after the check is created through `store.add`.
/// Copy is localized at creation time, so the stored check text never changes
/// when the language changes later.
@MainActor
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

        let loc = Localization.shared
        return Check(
            name: loc.t("preset.deepseek.name"),
            timeZoneIdentifier: "Asia/Shanghai",
            schedule: schedule,
            states: CheckStates(
                active: StateStyle(label: loc.t("preset.deepseek.active"), color: .red),
                inactive: StateStyle(label: loc.t("preset.deepseek.inactive"), color: .green)
            ),
            details: [
                DetailRow(name: loc.t("preset.deepseek.detail.flashInput"), active: "$0.30", inactive: "$0.15"),
                DetailRow(name: loc.t("preset.deepseek.detail.flashCached"), active: "$0.006", inactive: "$0.003"),
                DetailRow(name: loc.t("preset.deepseek.detail.flashOutput"), active: "$1.20", inactive: "$0.60"),
                DetailRow(name: loc.t("preset.deepseek.detail.proInput"), active: "$1.32", inactive: "$0.66"),
                DetailRow(name: loc.t("preset.deepseek.detail.proCached"), active: "$0.044", inactive: "$0.022"),
                DetailRow(name: loc.t("preset.deepseek.detail.proOutput"), active: "$3.96", inactive: "$1.98"),
            ],
            dayOverrides: [
                DayOverride(from: "2026-09-25", to: "2026-09-27", mode: .forceInactive,
                            label: loc.t("preset.deepseek.override.midAutumn")),
                DayOverride(from: "2026-10-01", to: "2026-10-07", mode: .forceInactive,
                            label: loc.t("preset.deepseek.override.nationalDay")),
            ],
            notifyOnFlip: false
        )
    }

    /// Xiaomi MiMo API peak window, expressed the same way as the DeepSeek
    /// preset: the schedule holds the peak window, everything else is off-peak.
    /// Peak every day 08:00–24:00 Shanghai time (stored as the overnight range
    /// 08:00–00:00; China has no DST); off-peak is 00:00–08:00. Rates are the
    /// overseas credit prices for the V2.6 series (mimo.mi.com): active
    /// column = list rate, inactive = 0.8× the list rate (off-peak coefficient).
    static func mimoPricing() -> Check {
        var schedule = Check.emptySchedule
        for weekday in Weekday.allCases {
            schedule[weekday.jsonKey] = [
                HourRange(start: "08:00", end: "00:00"),
            ]
        }

        let loc = Localization.shared
        let unit = loc.t("preset.mimo.credits")
        func credits(_ amount: String) -> String { "\(amount) \(unit)" }
        return Check(
            name: loc.t("preset.mimo.name"),
            timeZoneIdentifier: "Asia/Shanghai",
            schedule: schedule,
            states: CheckStates(
                active: StateStyle(label: loc.t("preset.mimo.active"), color: .red),
                inactive: StateStyle(label: loc.t("preset.mimo.inactive"), color: .green)
            ),
            details: [
                DetailRow(name: loc.t("preset.mimo.detail.flashCacheHit"), active: credits("2"), inactive: credits("1.6")),
                DetailRow(name: loc.t("preset.mimo.detail.flashCacheMiss"), active: credits("100"), inactive: credits("80")),
                DetailRow(name: loc.t("preset.mimo.detail.flashOutput"), active: credits("200"), inactive: credits("160")),
                DetailRow(name: loc.t("preset.mimo.detail.proCacheHit"), active: credits("2.5"), inactive: credits("2")),
                DetailRow(name: loc.t("preset.mimo.detail.proCacheMiss"), active: credits("300"), inactive: credits("240")),
                DetailRow(name: loc.t("preset.mimo.detail.proOutput"), active: credits("600"), inactive: credits("480")),
            ],
            notifyOnFlip: false
        )
    }
}

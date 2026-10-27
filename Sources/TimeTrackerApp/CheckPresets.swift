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

    /// Xiaomi MiMo API off-peak window, expressed as a normal check:
    /// off-peak every day 00:00–08:00 Shanghai time (= 16:00–24:00 UTC the
    /// previous day; China has no DST) billed at 0.8× the list rate;
    /// everything else is peak. Rates are the overseas USD pay-as-you-go
    /// prices for the V2.6 series (mimo.mi.com, updated 2026-10-21):
    /// active column = 80% of list, inactive = list.
    static func xiaomiMiMoPricing() -> Check {
        var schedule = Check.emptySchedule
        for weekday in Weekday.allCases {
            schedule[weekday.jsonKey] = [
                HourRange(start: "00:00", end: "08:00"),
            ]
        }

        let loc = Localization.shared
        return Check(
            name: loc.t("preset.mimo.name"),
            timeZoneIdentifier: "Asia/Shanghai",
            schedule: schedule,
            states: CheckStates(
                active: StateStyle(label: loc.t("preset.mimo.active"), color: .green),
                inactive: StateStyle(label: loc.t("preset.mimo.inactive"), color: .red)
            ),
            details: [
                DetailRow(name: loc.t("preset.mimo.detail.flashInput"), active: "$0.112", inactive: "$0.14"),
                DetailRow(name: loc.t("preset.mimo.detail.flashCached"), active: "$0.00224", inactive: "$0.0028"),
                DetailRow(name: loc.t("preset.mimo.detail.flashOutput"), active: "$0.224", inactive: "$0.28"),
                DetailRow(name: loc.t("preset.mimo.detail.proInput"), active: "$0.348", inactive: "$0.435"),
                DetailRow(name: loc.t("preset.mimo.detail.proCached"), active: "$0.00288", inactive: "$0.0036"),
                DetailRow(name: loc.t("preset.mimo.detail.proOutput"), active: "$0.696", inactive: "$0.87"),
            ],
            notifyOnFlip: false
        )
    }
}

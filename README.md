# TimeTracker

A macOS menu-bar utility that answers one question per configured check:

> Is my current local time inside this remote time zone's working hours?

A **check** is a name, an IANA time zone, and per-weekday working-hour ranges in that zone's wall clock. Overlap is evaluated live against absolute instants, so DST and overnight ranges work without manual offset math.

## Install

1. Download `TimeTracker-<version>.dmg` from the [Releases page](https://github.com/serbarla/time-tracker/releases).
2. Open the disk image and drag `TimeTracker.app` into the Applications folder.
3. Eject the disk image, then open TimeTracker from Applications.

Requirements: macOS 26 or newer.

### First launch (unsigned build)

This build is not notarized, so macOS blocks the first launch:

- Open TimeTracker once (double-click). macOS shows a "Not Opened" dialog ("Apple could not verify…") — click "Done", NOT "Move to Trash".
- Open System Settings -> Privacy & Security, scroll down to the Security section, and click "Open Anyway" next to the message about TimeTracker.
- In the "Open TimeTracker.app?" dialog that follows, click "Open Anyway" again. The app starts and its clock appears in the menu bar.

Terminal alternative:

```bash
xattr -d com.apple.quarantine /Applications/TimeTracker.app
```

## Uninstall

In the app: Settings -> turn off **Launch at login**, then quit. Then delete `/Applications/TimeTracker.app` and `~/Library/Application Support/TimeTracker`.

## Status

V5 pricing-window release (2026-10-23): named states, transition countdown/upcoming windows, day overrides, flip notifications, and the DeepSeek pricing preset. `swift build` and the 8 XCTest cases pass. Persistence is schema v2 with v1 compatibility; the packaged bundle is ad-hoc signed.

Localization (2026-10-27): app-owned UI text ships in English and Spanish from a bundled JSON catalog, selected in the Settings tab. No `checks.json` schema change.

## Requirements

- macOS 26 or newer (deployment target)
- Swift 6.2 toolchain (Xcode 26.x). No third-party dependencies.

## Run

```bash
swift run TimeTracker        # debug binary, no app bundle
```

This is an `LSUIElement` menu-bar app: it has no Dock icon or main window. Look for the clock icon in the menu bar, or press **Control+Option+T** to toggle the panel. Quit from the panel footer.

The **Launch at login** toggle requires a real app bundle and will fail when running the bare debug binary.

## Build and package

```bash
swift build                          # debug build
swift test                           # 8 XCTest cases (Codable model, JSON store, overlap engine)
bash Scripts/package-app.sh          # release build + ad-hoc sign -> dist/TimeTracker.app + DMG
open dist/TimeTracker.app            # run bundled app (enables launch-at-login)
```

`dist/` is gitignored. The bundle id is `com.sergiobarba.timetracker`; the bundle is ad-hoc signed (`codesign --sign -`) and **not notarized** (no Developer ID). `bash Scripts/package-app.sh` also emits `dist/TimeTracker-<version>.dmg` for direct download; the version comes from the newest `vX.Y.Z` git tag and `CFBundleVersion` from the commit count.

## Testing

```bash
bash Scripts/test.sh          # full pipeline: swift build + swift test -> package -> UI smoke
bash Scripts/ui-smoke.sh      # UI smoke alone (auto-packages when dist/TimeTracker.app is missing)
```

The UI smoke launches the bundled app against a temporary fixture store and drives the real UI via AppleScript UI scripting: launch → menubar title → panel tabs → editor row → quit, then checks that neither the fixture nor the real store was mutated. It never touches real data: `TIMETRACKER_CHECKS_FILE` redirects the store to the fixture for the run; without that variable the production path is used unchanged. UI scripting requires enabling your terminal under System Settings → Privacy & Security → Accessibility.

## Usage

The panel has three tabs: **Status**, **Edit**, **Settings**.

**Status**

- One row per check: name, current remote weekday/time, a 24-hour local-time timeline, and overlap status.
- Checks with named states show a state chip (label + color) in place of the legacy dot; v1 checks without `states` keep the dot.
- The timeline takes the active state's color (green when the check has no `states`) while the current instant is inside an overlap period, **grey** otherwise. Bands show the day's scheduled ranges; day overrides change the evaluated state but do not add or remove bands. The vertical marker is "now".
- When the current instant falls inside a scheduled range, an orange warning shows that range's end time.
- Each row shows a countdown to the next state flip ("Next in H:MM:SS"), a progress bar through the current window, and the current window plus up to three upcoming windows with state chips and durations; the current window shows time remaining.
- Checks with `details` rows get a "Details" disclosure showing the current value and, when a flip is known, the next value with its "from" time.
- The menu-bar title lists the names of overlapping checks, comma-separated; it is blank when none overlap.
- The menu-bar clock icon is tinted with the first overlapping check's active color (green when none overlap or for v1 checks without `states`).
- Refreshes every minute, exactly at each check's next state boundary (the menu-bar title updates ~0.25 s after the boundary; the open panel's countdown ticks every second), and immediately whenever checks are added, edited, or deleted.
- **Notifications:** flip banners are off by default. Enable "Notificar cambios de estado" in the editor to post `<check name>: <new state label>` at each flip, with the next flip time when one is known. The first observation after launch only records state, and flips older than 5 minutes are resynced silently, so changes missed during sleep are never announced late. Notifications require the bundled app; `swift run` has no bundle identifier and never posts. macOS asks for permission the first time an enabled check exists.

**Edit**

- Add, edit, and delete checks inline. Auto-saves to JSON on every store mutation.
- The pencil icon opens the editor populated with that check's current data; Save overwrites it by UUID.
- New checks default to the current user time zone.
- **Add preset → DeepSeek pricing** creates a normal check through the store: `Asia/Shanghai`, Mon–Fri `09:00–12:00` + `14:00–18:00` as peak (red "Peak pricing"), everything else off-peak (green "Off-peak · half price"), the six rate rows, and forced off-peak overrides for Mid-Autumn (2026-09-25–27) and National Day (2026-10-01–07). It is fully editable afterward like any other check; there is no DeepSeek-specific engine code.
- **Add preset → Xiaomi MiMo pricing** creates a check with `Asia/Shanghai`, every day `00:00–08:00` as off-peak (green "Off-peak") and the rest as peak (red "Peak"). Six rate rows show the V2.6 overseas USD pay-as-you-go prices (Flash and Pro: input, cached, output), with the off-peak column at 80% of the peak list price. Fully editable like any other check.
- The editor exposes optional named states (label, color, optional note), display-only detail rows, day-level overrides, and the flip-notification toggle.
- The time-zone filter auto-selects the first matching zone as you type. Clearing the filter keeps the current selection.

**Settings**

- One **Language** dropdown: `English` / `Español`. Switching re-renders every visible surface immediately; the choice persists in `UserDefaults` (`uiLocale`) and survives relaunch, overriding later macOS language changes.
- Only app-owned chrome is localized. Text stored in `checks.json` — check names, state labels/notes, detail names and values, typed override labels — is written in the language active at creation/edit time and is never translated afterwards (a preset created in English stays English).

Default global shortcut: **Control+Option+T**.

## Localization

App-owned UI text lives in one catalog, bundled with the app target:

```
Sources/TimeTrackerApp/Resources/Localization.json
```

Shape — the same key set in both languages:

```json
{
  "en": { "tab.status": "Status", "status.nextIn": "Next in %d:%02d:%02d" },
  "es": { "tab.status": "Estado", "status.nextIn": "Próximo en %d:%02d:%02d" }
}
```

- `Sources/TimeTrackerApp/Localization.swift` decodes it from `Bundle.module` and exposes `t(_:)` (plus `format(_:_:)` for `%@`/`%d` keys); a missing key falls back to `en`, then to the key itself.
- Weekday names (`Mon`..`Sun` / `Lun`..`Dom`) come from the `weekday.mon`..`weekday.sun` keys; time output stays 24-hour `HH:mm`, and no dates, numbers, or plurals are localized.
- Default language: on first launch the app resolves macOS's preferred language once — an `es`-prefixed first choice writes `es`, everything else writes `en` — then freezes it in `uiLocale`. Later system-language changes are ignored until the dropdown is used.
- `checks.json` is untouched by this: same schema, same bytes before and after a language switch.

## Data

Stored at:

```
~/Library/Application Support/TimeTracker/checks.json
```

The file is written on every store mutation (`add`, `update`, `remove`, `move`), not at launch. Schema:

```json
{
  "version": 2,
  "checks": [
    {
      "id": "11111111-2222-3333-4444-555555555555",
      "name": "DeepSeek pricing",
      "timeZoneIdentifier": "Asia/Shanghai",
      "schedule": {
        "mon": [
          { "start": "09:00", "end": "12:00" },
          { "start": "14:00", "end": "18:00" }
        ],
        "tue": [
          { "start": "09:00", "end": "12:00" },
          { "start": "14:00", "end": "18:00" }
        ],
        "wed": [
          { "start": "09:00", "end": "12:00" },
          { "start": "14:00", "end": "18:00" }
        ],
        "thu": [
          { "start": "09:00", "end": "12:00" },
          { "start": "14:00", "end": "18:00" }
        ],
        "fri": [
          { "start": "09:00", "end": "12:00" },
          { "start": "14:00", "end": "18:00" }
        ],
        "sat": [],
        "sun": []
      },
      "states": {
        "active": { "label": "Peak pricing", "color": "red" },
        "inactive": { "label": "Off-peak · half price", "color": "green" }
      },
      "details": [
        {
          "name": "V4.1 Flash input · per 1M tokens",
          "active": "$0.30",
          "inactive": "$0.15"
        }
      ],
      "dayOverrides": [
        {
          "from": "2026-10-01",
          "to": "2026-10-07",
          "mode": "forceInactive",
          "label": "National Day"
        }
      ],
      "notifyOnFlip": false
    }
  ]
}
```

Rules:

- `start`/`end` are 24-hour `"HH:mm"` wall-clock times in `timeZoneIdentifier`.
- Ranges are half-open: `[start, end)`.
- `end <= start` means the range rolls past midnight into the next day.
- A range with `start == end` is degenerate: the evaluator treats it as a 24-hour range (always on), while `HourRange.isValid` reports it invalid; the editor does not currently reject it.
- Malformed `"HH:mm"` times are ignored at evaluation time.
- `[]` means an off day; multiple non-contiguous ranges per day are allowed.
- Overlap evaluation also considers the previous remote day to catch overnight spillover.
- `states` is optional. `active`/`inactive` hold `{label, color, note?}`; `note` is optional, edited and persisted, but not displayed in the Status row. `color` is one of `green`, `grey`, `red`, `orange`, `yellow`, `blue`, `purple`. Absent `states` means the v1 look: "In range"/"Out" with the legacy dot.
- `details` is optional and display-only: each `{name, active, inactive}` row shows the current state's value and, when a flip is known, the next state's value.
- `dayOverrides` is optional. Each `{from, to, mode, label}` covers an inclusive date range in the check's zone; `mode` is `forceActive` or `forceInactive` and wins over the schedule for state evaluation; timeline bands remain schedule-only. An overnight range is cut at 00:00 of a forced day.
- `notifyOnFlip` is stored for every check (default `false`); see the notification behavior above.
- Transition and upcoming-window scans are bounded to 14 days: `nextTransition` is `nil` when no flip occurs in that horizon, and `upcoming` is truncated there.
- Version 1 files load unchanged: missing v2 fields default to no states, no details, no overrides, and notifications off. The next save writes `"version": 2`.

## Code map

| Path | Responsibility |
| --- | --- |
| `Sources/TimeTrackerCore/Check.swift` | `Check`, `ChecksFile` model and JSON shape |
| `Sources/TimeTrackerCore/CheckState.swift` | v2 states, detail rows, day overrides |
| `Sources/TimeTrackerCore/HourRange.swift` | `"HH:mm"` parsing, overnight/invalid rules |
| `Sources/TimeTrackerCore/Weekday.swift` | Monday-first weekdays and JSON keys |
| `Sources/TimeTrackerCore/OverlapEngine.swift` | Pure `(Check, Date) -> OverlapState` evaluation, including transitions |
| `Sources/TimeTrackerCore/CheckStore.swift` | `@MainActor` observable store, JSON load/save |
| `Sources/TimeTrackerApp/TimeTrackerApp.swift` | `NSStatusItem` + `NSPopover`, menubar label and icon tint, boundary-aligned refresh, flip notifications |
| `Sources/TimeTrackerApp/ContentView.swift` | Panel layout, Status/Edit/Settings tabs, language picker, launch-at-login toggle, quit |
| `Sources/TimeTrackerApp/Localization.swift` | `Localization.json` loader, `t`/`format`, `uiLocale` default and switch |
| `Sources/TimeTrackerApp/Resources/Localization.json` | The `en`/`es` UI copy catalog (identical key sets) |
| `Sources/TimeTrackerApp/HotKey.swift` | Carbon global hotkey registration |
| `Sources/TimeTrackerApp/StatusTab.swift` | Status rows: chip, timeline, countdown, upcoming windows, details |
| `Sources/TimeTrackerApp/StateChip.swift` | State chip, palette colors, v1 default states |
| `Sources/TimeTrackerApp/OverlapTimeline.swift` | Canvas timeline bar (state color/grey) |
| `Sources/TimeTrackerApp/EditTab.swift` | Check list, add/edit/delete entry points, presets |
| `Sources/TimeTrackerApp/CheckPresets.swift` | Built-in check templates (DeepSeek pricing, Xiaomi MiMo pricing) |
| `Sources/TimeTrackerApp/CheckEditorView.swift` | Name, time-zone filter/picker, weekday ranges, v2 fields |
| `Tests/TimeTrackerCoreTests/` | Codable, store persistence, and overlap-engine tests |

## Context

`context/PLAN.md` is the product decision/spec log: definitions, scope decisions, data model, architecture rationale, and historical milestones. Read it before changing product behavior. It may lag recent UI details; the source and this README are the current truth.

# TimeTracker

A macOS menu-bar utility that answers one question per configured check:

> Is my current local time inside this remote time zone's working hours?

A **check** is a name, an IANA time zone, and per-weekday working-hour ranges in that zone's wall clock. Overlap is evaluated live against absolute instants, so DST and overnight ranges work without manual offset math.

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
swift test                           # 8 unit tests (core models + overlap engine)
bash Scripts/package-app.sh          # release build + ad-hoc sign -> dist/TimeTracker.app
open dist/TimeTracker.app            # run bundled app (enables launch-at-login)
```

`dist/` is gitignored. The bundle is ad-hoc signed (`codesign --sign -`) and not notarized; it is intended for personal use.

## Usage

The panel has two tabs.

**Status**

- One row per check: name, current remote weekday/time, a 24-hour local-time timeline, and overlap status.
- Checks with named states show a state chip (label + color) in place of the legacy dot; v1 checks without `states` keep the dot.
- The timeline takes the active state's color (green when the check has no `states`) while the current instant is inside an overlap period, **grey** otherwise. Bands show the day's overlap periods; the vertical marker is "now".
- When currently overlapping, an orange warning shows the overlap's end time.
- Each row shows a countdown to the next state flip ("Next in H:MM:SS"), a progress bar through the current window, and the next four windows with their states and durations.
- Checks with `details` rows get a "Details" disclosure showing the current value and the next value with its flip time.
- The menu-bar title lists the names of overlapping checks, comma-separated; it is blank when none overlap.
- The menu-bar clock icon is tinted with the first overlapping check's active color (green when none overlap or for v1 checks without `states`).
- Refreshes every minute, at each check's next state boundary (flips render within ~2 seconds), and immediately whenever checks are added, edited, or deleted.
- **Notifications:** flip banners are off by default. Enable "Notificar cambios de estado" in the editor to post `<check name>: <new state label>` at each flip, with the next flip time. The first observation after launch only records state, and flips older than 5 minutes are resynced silently, so changes missed during sleep are never announced late. Notifications require the bundled app; `swift run` has no bundle identifier and never posts. macOS asks for permission the first time an enabled check exists.

**Edit**

- Add, edit, and delete checks inline. Auto-saves to JSON on every change.
- The pencil icon opens the editor populated with that check's current data; Save overwrites it by UUID.
- New checks default to the current user time zone.
- **Add preset → DeepSeek pricing** creates a normal check through the store: `Asia/Shanghai`, Mon–Fri `09:00–12:00` + `14:00–18:00` as peak (red "Peak pricing"), everything else off-peak (green "Off-peak · half price"), the six rate rows, and forced off-peak overrides for Mid-Autumn (2026-09-25–27) and National Day (2026-10-01–07). It is fully editable afterward like any other check; there is no DeepSeek-specific engine code.
- The editor exposes optional named states, display-only detail rows, day-level overrides, and the flip-notification toggle.
- The time-zone filter auto-selects the first matching zone as you type. Clearing the filter keeps the current selection.

Default global shortcut: **Control+Option+T**.

## Data

Stored at:

```
~/Library/Application Support/TimeTracker/checks.json
```

The file is written on the first add/edit/delete. Schema:

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
- A range with `start == end` is invalid (it would mean "always on").
- `[]` means an off day; multiple non-contiguous ranges per day are allowed.
- Overlap evaluation also considers the previous remote day to catch overnight spillover.
- `states` is optional. `active`/`inactive` hold `{label, color}`, with `color` one of `green`, `grey`, `red`, `orange`, `yellow`, `blue`, `purple`. Absent `states` means the v1 look: "In range"/"Out" with the legacy dot.
- `details` is optional and display-only: each `{name, active, inactive}` row shows the value for the current state and the next state.
- `dayOverrides` is optional. Each `{from, to, mode, label}` covers an inclusive date range in the check's zone; `mode` is `forceActive` or `forceInactive` and wins over the schedule. An overnight range is cut at 00:00 of a forced day.
- `notifyOnFlip` is stored for every check (default `false`); see the notification behavior above.
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
| `Sources/TimeTrackerApp/TimeTrackerApp.swift` | `NSStatusItem` + `NSPopover`, hotkey, launch at login, menubar label and icon tint, boundary-aligned refresh, flip notifications |
| `Sources/TimeTrackerApp/StatusTab.swift` | Status rows: chip, timeline, countdown, upcoming windows, details |
| `Sources/TimeTrackerApp/StateChip.swift` | State chip and palette colors |
| `Sources/TimeTrackerApp/OverlapTimeline.swift` | Canvas timeline bar (state color/grey) |
| `Sources/TimeTrackerApp/EditTab.swift` | Check list, add/edit/delete entry points, presets |
| `Sources/TimeTrackerApp/CheckPresets.swift` | Built-in check templates (DeepSeek pricing) |
| `Sources/TimeTrackerApp/CheckEditorView.swift` | Name, time-zone filter/picker, weekday ranges, v2 fields |
| `Tests/TimeTrackerCoreTests/` | Overlap engine and store tests |

## Context

`context/PLAN.md` is the product decision/spec log: definitions, scope decisions, data model, architecture rationale, and historical milestones. Read it before changing product behavior. It may lag recent UI details; the source and this README are the current truth.

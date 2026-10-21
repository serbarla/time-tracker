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
- The timeline is **green** while the current instant is inside an overlap period, **grey** otherwise. Bands show the day's overlap periods; the vertical marker is "now".
- When currently overlapping, an orange warning shows the overlap's end time.
- The menu-bar title lists the names of overlapping checks, comma-separated; it is blank when none overlap.
- Refreshes every minute, and immediately whenever checks are added, edited, or deleted.

**Edit**

- Add, edit, and delete checks inline. Auto-saves to JSON on every change.
- The pencil icon opens the editor populated with that check's current data; Save overwrites it by UUID.
- New checks default to the current user time zone.
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
  "version": 1,
  "checks": [
    {
      "id": "11111111-2222-3333-4444-555555555555",
      "name": "Tokyo team",
      "timeZoneIdentifier": "Asia/Tokyo",
      "schedule": {
        "mon": [{ "start": "09:00", "end": "17:00" }],
        "tue": [],
        "wed": [],
        "thu": [],
        "fri": [],
        "sat": [],
        "sun": []
      }
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

## Code map

| Path | Responsibility |
| --- | --- |
| `Sources/TimeTrackerCore/Check.swift` | `Check`, `ChecksFile` model and JSON shape |
| `Sources/TimeTrackerCore/HourRange.swift` | `"HH:mm"` parsing, overnight/invalid rules |
| `Sources/TimeTrackerCore/Weekday.swift` | Monday-first weekdays and JSON keys |
| `Sources/TimeTrackerCore/OverlapEngine.swift` | Pure `(Check, Date) -> OverlapState` evaluation |
| `Sources/TimeTrackerCore/CheckStore.swift` | `@MainActor` observable store, JSON load/save |
| `Sources/TimeTrackerApp/TimeTrackerApp.swift` | `NSStatusItem` + `NSPopover`, hotkey, launch at login, menubar label |
| `Sources/TimeTrackerApp/StatusTab.swift` | Status rows and overlap warning |
| `Sources/TimeTrackerApp/OverlapTimeline.swift` | Canvas timeline bar (green/grey by state) |
| `Sources/TimeTrackerApp/EditTab.swift` | Check list, add/edit/delete entry points |
| `Sources/TimeTrackerApp/CheckEditorView.swift` | Name, time-zone filter/picker, weekday ranges |
| `Tests/TimeTrackerCoreTests/` | Overlap engine and store tests |

## Context

`context/PLAN.md` is the product decision/spec log: definitions, scope decisions, data model, architecture rationale, and historical milestones. Read it before changing product behavior. It may lag recent UI details; the source and this README are the current truth.

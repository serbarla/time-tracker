# Time Tracker (Menubar macOS) — Plan

Status: **v4 — complete. Built, tested, packaged.**

## Decisions (Q&A log)

| # | Question | Decision |
|---|---|---|
| 1 | "time tracker" = real logging? | No — loose name only. |
| 2 | What is a "check"? | A named time zone + its working-hour ranges; checks overlap vs. current local time. |
| 3 | "Ranges" meaning | (b) a check has **hour ranges** (working day). One time zone per check. |
| 4 | Overlap definition | **Live**: is my current local time inside the remote zone's working-hour ranges? |
| 5 | Working hours config | Per check. |
| 6 | Weekends | Per-weekday schedule (Mon–Sun each configurable). |
| 7 | Granularity | Hourly. |
| 8 | Menubar idle | Icon + live text = **name(s) of currently-overlapping checks** (answer c). |
| 9 | Status placement | Per-check status in the dropdown. |
| 10 | Add/edit/remove surface | **Inline, in the menu panel as a tab** — not a separate window. |
| 11 | Refresh / DST | Live refresh (every minute); DST via system tz database — yes. |
| 12 | Timeline | Timeline overlap bar per check + **warning text during the overlap period**. |
| 14 | Storage | JSON. |
| 16 | Stack | SwiftUI. |
| 17 | Deployment target | macOS 26+. |
| 18 | Zone source | Apple `TimeZone` (IANA, DST-aware) — accepted. |
| 19 | v1 scope | Status + launch-at-login + global shortcut. |
| 20 | Distribution | Personal use; no signing/notarization needed. |
| — | Ranges per weekday | **Multiple non-contiguous ranges allowed** per day. |
| — | Shortcut behavior | Global hotkey toggles the menu panel. |

## Core concept (confirmed)

A **check** = a remote IANA time zone + per-weekday working-hour ranges (in the remote zone's local time). The app continuously answers one question per check:

> **Is my current local clock time inside any of that check's configured working-hour ranges?**

Evaluated on absolute instants, so DST and cross-midnight ranges are handled by system `Calendar`/`TimeZone` — no hand-rolled offsets.

## Functional spec

### 1. Overlap engine
Given `now: Date` and a check:
1. Build a `Calendar` in the check's `TimeZone`.
2. Let `w` = the check's remote weekday for `now`.
3. Build absolute intervals for `w`'s ranges anchored to remote *today*, and for `w-1`'s ranges anchored to remote *yesterday* (catches overnight spillover: `end <= start` rolls into next day).
4. Overlap = `now ∈ any interval`.

Rules:
- `[start, end]` with `end <= start` = overnight, extends into next day.
- A range ≥ 24h is invalid (rejected at input) — it would mean "always on".
- Empty schedule on a weekday = off day.
- Previous-day spillover only applies to overnight ranges.

### 2. Checks
- Add / edit / remove **inline** in the menu panel's Edit tab.
- Fields: `name`, `timeZone` (IANA identifier picker), per-weekday ranges (multiple per day).

### 3. Menu panel (MenuBarExtra, `.window` style — single panel, no separate window)
Two inline tabs:

- **Status tab**
  - Menubar icon + live text: overlapping check **name(s)**, comma-joined; blank/`—` when none overlap.
  - List every check: name, current remote time, current remote weekday, overlap status (in/out).
  - Per check: 24h timeline bar (local time) with overlap bands shaded, "now" marker, and **warning text** when currently overlapping.

- **Edit tab**
  - List of checks: add / delete / reorder.
  - Per-check editor: name, searchable IANA time-zone picker, Monday–Sunday grid of hour ranges (multiple ranges per day, add/remove rows).
  - Edits auto-save to JSON immediately.

- Footer: "Quit".

### 4. v1 extras
- **Launch at login** — `SMAppService.mainApp` (modern ServiceManagement; requires app bundle + bundle id).
- **Global shortcut** — toggles the menu panel (hotkey registration via KeyboardShortcuts lib or Carbon/NSEvent global monitor — pick at implementation).

## Data model (JSON)

```json
{
  "version": 1,
  "checks": [
    {
      "id": "UUID",
      "name": "Tokyo team",
      "timeZone": "Asia/Tokyo",
      "schedule": {
        "mon": [{ "start": "09:00", "end": "17:00" }],
        "tue": [{ "start": "09:00", "end": "17:00" }],
        "wed": [{ "start": "09:00", "end": "17:00" }],
        "thu": [{ "start": "09:00", "end": "17:00" }],
        "fri": [{ "start": "09:00", "end": "17:00" }],
        "sat": [],
        "sun": []
      }
    }
  ]
}
```

- Stored in `~/Library/Application Support/<app>/checks.json`.
- `start`/`end` as `"HH:mm"` 24h; `[]` = off day; multiple ranges per day.

## Architecture (SwiftUI, macOS 26+)

- **App** — `NSStatusItem` + `NSPopover` (AppKit) hosting SwiftUI content. Chosen over `MenuBarExtra` because a global shortcut must toggle the menu programmatically, which `MenuBarExtra` does not expose.
- **Store** — `CheckStore` (`ObservableObject`, `@MainActor`), loads/saves JSON, `@Published` for live UI.
- **OverlapEngine** — pure `(Check, Date) -> OverlapState` (in/out, active interval, timeline bands).
- **Label updates** — `Timer` (60s) recomputes the menubar title from overlapping check names.
- **HotKey** — Carbon `RegisterEventHotKey` (no Accessibility permission needed); default **Control+Option+T**.
- **Launch at login** — `SMAppService.mainApp` toggle (requires the `.app` bundle).
- **Types** — `Check`, `HourRange`, `Weekday`, `OverlapState` (all `public` in `TimeTrackerCore`).

## Status (complete)

All milestones implemented and verified:

1. Data model + JSON persistence + overlap engine — **8/8 unit tests pass** (`swift test`).
2. Menu panel UI: Status/Edit tabs, per-check status + timeline + warning text.
3. Menubar icon + live text (overlapping check names).
4. Launch-at-login toggle + global shortcut (⌃⌥T).
5. Smoke-tested: debug binary and signed `.app` both launch and stay alive on macOS 27 (≥26 target).

## Build & run

```bash
swift test                          # unit tests
swift run TimeTracker               # run from source (debug)
bash Scripts/package-app.sh         # build release + ad-hoc sign dist/TimeTracker.app
open dist/TimeTracker.app           # run the bundled app (enables launch-at-login)
```

Notes:
- Checks persist to `~/Library/Application Support/TimeTracker/checks.json`.
- Launch-at-login requires running the `.app` bundle (bundle id `com.sergiobarba.timetracker`, ad-hoc signed).
- Default shortcut ⌃⌥T toggles the menu; edit `setupHotKey()` in `Sources/TimeTrackerApp/TimeTrackerApp.swift` to remap.

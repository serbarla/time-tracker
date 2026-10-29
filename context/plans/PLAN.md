# Time Tracker (Menubar macOS) — Plan

Status: **v6 — complete. Built, tested, packaged (2026-10-27).** (v5 pricing-window release: 2026-10-23.)

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
| 20 | Distribution | Public via GitHub Releases (repo public); unsigned/ad-hoc only — no paid Apple account, so no Developer ID/notarization; users unblock via System Settings or `xattr`; manual updates. Decided 2026-10-28. |
| — | Ranges per weekday | **Multiple non-contiguous ranges allowed** per day. |
| — | Shortcut behavior | Global hotkey toggles the menu panel. |
| — | UI language | **English/Spanish from one bundled `Localization.json`**, chosen in a Settings tab; `uiLocale` in `UserDefaults`, resolved once from macOS's preferred language, then frozen. Stored check text is never translated. |

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

## v5 — pricing-window alignment (implemented 2026-10-23)

Status: **implemented** — specs 01–05 in `context/specs/` are checked off. The
"DeepSeek pricing" preset ships in the Edit tab as ordinary check data.

Source: comparison against https://github.com/deepakness/deepseek-price-clock (Chrome MV3
extension; DeepSeek API peak/off-peak pricing). Goal: bring its business logic into our
engine **without special-casing DeepSeek** — checks stay user-defined names + IANA zones.
DeepSeek becomes one preset check, never engine code.

### What the extension does that we don't

- Two **named states** ("Peak pricing" / "Off-peak · half price") over one window machine:
  peak = 01:00–04:00 and 06:00–10:00 UTC; everything else off-peak.
- **Day-level overrides**: Beijing weekends and Chinese public-holiday date ranges force
  off-peak all day (`CN_HOLIDAYS` as inclusive date pairs).
- **Transition-centric UI**: countdown to next flip, progress through the current window,
  upcoming-window schedule table, current/next rate tables (six rows, Flash/Pro input,
  cached input, output; peak is exactly 2× off-peak in every row).
- **State-driven feedback**: toolbar icon green/red by state; tooltip with flip time.
- **Flip notification** (optional) with a 5-minute staleness grace window
  (`NOTIFY_GRACE_MS`) so flips missed during sleep are not announced late.
- **Boundary-aligned refresh**: minute tick plus an exact alarm at the switch instant.

### What we keep / don't adopt

- Keep: multi-check, arbitrary IANA zones, per-weekday ranges, half-open/overnight rules,
  JSON store, in-panel editing, hotkey, launch-at-login.
- Don't adopt: Chrome plumbing (alarms/permissions/workers), hardcoded brand icons and
  rate values in engine code, `WEEKEND_RULE_START` rule versioning (matters only for
  historical evaluation; we evaluate now→future only).

### Generalized model

Both apps are the same machine: named states over absolute instants. Our `HourRange`
membership = the active window set; its complement = the inactive state. DeepSeek is
already expressible as a check today: zone `Asia/Shanghai`, mon–fri `09:00–12:00` +
`14:00–18:00` (= 01:00–04:00 and 06:00–10:00 UTC; China has no DST), sat/sun empty —
lacking only holiday overrides, state labels, and the transition UI.

New optional `Check` fields (store version 2; all defaulted when loading version 1):

- `states`: `{ active: {label, color, note}, inactive: {…} }`; defaults "In range"/"Out"
  with green/grey — v1 files look and behave exactly as today.
- `details`: display-only rows `{name, active, inactive}` (the rate table, genericized).
- `dayOverrides`: `[{from, to, mode: forceActive|forceInactive, label}]`; `from`/`to` are
  inclusive dates in the check's zone; evaluated per instant, override wins over schedule
  (matches the extension's `offPeakAllDay`).
- `notifyOnFlip`: Bool.

One zone per check (ranges and override dates share it). The extension's UTC-windows /
Beijing-calendar split is not needed: for its windows the UTC weekday equals the Beijing
weekday, so a single `Asia/Shanghai` check encodes the same policy.

Engine additions (pure, `OverlapEngine`): `OverlapState` gains `windowStart`,
`nextTransition: Date?`, `upcoming: [WindowSlice]` (start/end/isActive). Transition
candidates = band edges + override day boundaries; bounded forward scan (~14 days),
mirroring the extension's bounded walk-back. Override boundary semantics: an overnight
spillover dies at 00:00 of a forced day (state flips at midnight). Keep
`evaluate(check:now:)` pure per the architecture contract.

UI: status row gets a state chip (label + color), countdown to `nextTransition`, progress
through the current window, an upcoming-windows table, and expandable `details` rows
showing current/next values; timeline bands take the state color (default stays
green/grey — this revises the AGENTS.md timeline contract at implementation time); menubar
icon tint from the first active check's active color, green otherwise; a one-shot timer at
`min(nextTransition)` in addition to the mandated 60s timer + `$checks` subscription;
per-check flip notification via `UserNotifications` with the 5-min grace window (first run
only records state).

Preset: an "DeepSeek pricing" template in the Edit tab creates the check above with
`dayOverrides` seeded from a bundled copy of the extension's holiday list and `details`
seeded from its popup rates; everything user-editable afterward.

### Phases (each shippable) — executable specs in `context/specs/`

1. Core: v2 model + `dayOverrides` + window-transition engine + DeepSeek fixture
   proof (peak at 2026-10-23 02:00 UTC, off at 05:00 UTC, all-day off Sat 2026-10-24
   and across 2026-10-01..07) — `specs/01-core-window-model.md`.
2. Status UI: chips, countdown, upcoming table, details, state-colored timeline, plus
   editor exposure of the v2 fields; app smoke — `specs/02-status-window-ui.md`.
3. Menubar: boundary-aligned refresh + icon tint; app smoke —
   `specs/03-menubar-state-feedback.md`.
4. Notifications (toggle + grace window); app smoke — `specs/04-flip-notifications.md`.
5. DeepSeek preset; README + AGENTS.md contract updates; this log —
   `specs/05-deepseek-preset-and-docs.md`.

Per `context/TEMPLATE.md`'s testing policy, the fixture proofs run through a temporary
integration harness (deleted before yield) instead of new permanent unit tests; the
existing 8 cases stay green throughout.

Compat: v1 files load unchanged with defaults; re-save upgrades to v2. Risks: transition
scan cost (bounded, computed on refresh/panel-open only); the overnight + override
boundary interaction was proven by the phase-1 fixture harness; the AGENTS.md
"timeline must be green" contract was intentionally revised in phase 2.

## v6 — UI localization from a JSON catalog (implemented 2026-10-27)

Status: **implemented** — spec `context/specs/06-localization-json.md` is checked off.

Decision: app-owned UI text is English/Spanish, sourced from one catalog,
`Sources/TimeTrackerApp/Resources/Localization.json`, shipped with the app target
(`resources: [.copy("Resources/Localization.json")]`). Shape is `{ "en": {key: string},
"es": {key: string} }` with identical key sets. `Localization` (`TimeTrackerApp`) decodes
it from `Bundle.module`, exposes `t(_:)`/`format(_:_:)`, and falls back to `en`, then to
the key. Views take it as an `@EnvironmentObject`, so a language switch re-renders the
open panel immediately.

Rules we keep:
- **No** Apple String Catalogs / `.strings` / `NSLocalizedString`; the JSON is the single
  source. **No** `TimeTrackerCore` changes: `Weekday.shortName` stays for non-UI use, and
  weekday chrome reads `weekday.mon`..`weekday.sun` from JSON instead of `DateFormatter`
  locale data (the `EEE` format segments are gone; `HH:mm` output is unchanged).
- **No** localization of anything stored in `checks.json`. Preset/state/detail/override
  text is localized *at creation time* through `store.add`, and v1 default state labels
  ("In range"/"Out") are resolved from JSON *at display time*; neither is re-translated
  retroactively.
- Language choice: `UserDefaults` key `uiLocale`. First launch resolves macOS's preferred
  language once (`es`-prefixed first choice → `es`, everything else → `en`) and freezes it;
  the Settings dropdown (third tab: Status | Edit | Settings) overrides it from then on.
- Notifications and the warning line use the same catalog (`notify.*`, `status.warning`),
  still on the local clock in `HH:mm`.
- Entry-type label copy (2026-10-27): the word "Zona" is localized as "Time Zone" (`en`) /
  "Zona Horaria" (`es`) wherever it names the entry (`editor.zona`, `edit.addZona`).
  Follow-up (same day, user request): the residual mixed flavor in `en` was translated —
  "Filtrar Zonas" → "Filter time zones", "No zonas" → "No time zones.", and the Spanish
  `editor.states` / `editor.stateActive` / `editor.stateInactive` / `editor.notify` /
  `editor.specialDays` values became English. `es` is unchanged; the contract is now
  "no Spanish in the `en` block".

Shipped with it: `Scripts/package-app.sh` now copies (and signs) the SPM resource bundle
into `Contents/Resources/`, and `Scripts/ui-smoke.sh` pins `uiLocale=en` for its run and
restores the previous value, because its AX assertions read English labels.

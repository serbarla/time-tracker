# AGENTS.md

Instructions for coding agents working in this repository.

## Testing

Unit testing is not required, avoid it, only end to end testing and integration testing are priorities

## Take into account first

Whenever you are asked to plan something, please do not assume, ask the user first before implementing.

## Start here

1. **Read `context/PLAN.md`** for the product definition, scope decisions, data-model rules, and architecture rationale. It is the decision log, not a build guide.
2. Read `README.md` for the current run/build/storage behavior.
3. Treat source code as the current truth where `context/PLAN.md` lags. Known drift: the plan's JSON sample uses `timeZone`, but the implementation and persisted schema use `timeZoneIdentifier`.

## Repository shape

- Swift Package Manager only. There is no `.xcodeproj`.
- `Sources/TimeTrackerCore` — pure, testable logic: models, overlap engine, JSON store. Keep it UI-free and time-zone-correct.
- `Sources/TimeTrackerApp` — AppKit/SwiftUI menu-bar app shell and views.
- `Tests/TimeTrackerCoreTests` — 8 XCTest cases covering overlap semantics, Codable round-trip, and store persistence.
- `Scripts/package-app.sh` — release build plus ad-hoc-signed `.app` bundle.
- `dist/` and `.build/` are gitignored build output.

## Commands

```bash
swift build                       # debug build (must pass before yielding)
swift test                        # 8 tests (must pass)
swift run TimeTracker             # run the menu-bar app from source
bash Scripts/package-app.sh       # release + ad-hoc sign -> dist/TimeTracker.app
open dist/TimeTracker.app         # bundled run; required for launch-at-login
```

`swift run TimeTracker` produces an `LSUIElement` process: no window or Dock icon. Open the panel with the menu-bar clock icon or **Control+Option+T**. The app does not exit until you choose Quit or kill it.

## UI smoke testing

There are no UI tests. After UI changes, run the actual app and exercise the changed surface:

1. Kill stray instances first: `pkill -x TimeTracker`. Multiple instances each register the Carbon hotkey and create duplicate status items.
2. `swift run TimeTracker`.
3. Open with Control+Option+T; verify the specific changed behavior in Status or Edit.
4. For persistence changes, inspect `~/Library/Application Support/TimeTracker/checks.json`.
5. For notifications: enable "Notificar cambios de estado" on a check whose next boundary is within 2 minutes, run the bundled `dist/TimeTracker.app`, and confirm exactly one banner appears at the flip. The unbundled `swift run` binary cannot post notifications; the first evaluation after launch only records state, so a flip missed by more than 5 minutes stays silent.
6. Quit the app when done.

The panel is transient: it closes when focus leaves. In AppleScript UI scripting, the popover lives at `pop over 1 of menu bar 2` (not under `menu bar item 1`).

## Architecture contracts

- `CheckStore` is `@MainActor`, an `ObservableObject`; `checks` is `@Published private(set)` and mutations auto-save. Do not add UI mutation paths that bypass `add` / `update` / `remove` / `move`.
- Menubar title updates are driven by both a 60-second `Timer` and a Combine subscription to `store.$checks` in `AppDelegate`. Keep both: the timer handles time crossing schedule boundaries; the subscription handles edits/deletes immediately.
- `OverlapEngine.evaluate(check:now:)` is pure and must stay so. It uses the check's `TimeZone` calendar and also evaluates the previous remote day for overnight spillover.
- `HourRange` semantics: half-open `[start, end)`, `"HH:mm"` 24-hour strings, `end <= start` = overnight, `start == end` = invalid.
- `Weekday` is Monday-first for display, with a separate Gregorian `calendarWeekday` mapping.
- Views read state from `CheckStore`; do not persist from views directly.
- `CheckPresets` is data only: a preset builds a normal `Check` and is added through `store.add`; the engine never special-cases a preset, and presets stay fully user-editable.
- Flip notifications use the 5-minute `windowStart` grace; the first observation after launch records state without notifying, and only checks with `notifyOnFlip` announce.
- UI copy is mixed English/Spanish ("Zona", "Filtrar Zonas", "No zonas"). Preserve existing language/style unless asked.

## Editing behavior that is easy to break

- `CheckEditorView` builds its `@State` from `initial` in `init`; save reconstructs a `Check` with the original `id` so `store.update` overwrites instead of duplicating.
- New checks default to `TimeZone.current.identifier`. Invalid stored identifiers fall back to the current zone.
- The time-zone filter (`matchingZoneIDs(for:)`) is shared by the picker and the `.onChange(of: filter)` handler, which selects the first match on every non-empty filter change. Do not diverge the two orderings.
- The timeline takes the check's active-state color (`states.active.color`), green by default, while `state.isOverlapping`, grey otherwise (`OverlapTimeline.isOverlapping`).
- Deleting the last overlapping check must clear the menubar title immediately via the store subscription.

## Persistence

- Path: `~/Library/Application Support/TimeTracker/checks.json`.
- Top level: `{ "version": 2, "checks": [...] }`.
- Schedule keys: `"mon"..."sun"`; missing/empty array = off.
- v2 optional fields on `Check`: `states` (`active`/`inactive` `StateStyle {label, color, note}`), `details` (`{name, active, inactive}` rows), `dayOverrides` (`{from, to, mode, label}` with inclusive `yyyy-MM-dd` check-zone dates and `forceActive`/`forceInactive`), `notifyOnFlip` (always written, default `false`).
- v1 files load unchanged with v2 defaults; the next mutation writes `"version": 2`.
- File is written only on mutation, not at launch.

## Change checklist

- [ ] `swift build` and `swift test` pass.
- [ ] Changed UI behavior exercised in the running app (not just compiled).
- [ ] Persisted schema unchanged, or migration/backward compatibility considered.
- [ ] `README.md` updated if commands, usage, or storage behavior changed.
- [ ] `context/PLAN.md` updated if a product decision or scope changed.

# 06 — UI localization from a JSON catalog

Adds product decision: app-owned UI text is localized (English/Spanish) from a JSON
catalog, selected in a new Settings tab. Depends on: 01–05. No engine or data-schema
work.

Read the nearest `AGENTS.md` (target workspace, then parents up to repo root)
before executing. If reality diverges from this spec: stop, append the
divergence under Testing criteria, NEVER improvise outside the objectives.

## 1. Objectives

*Numbered, ordered. Each: one verb sentence, its requirements, exact commands.*
*Check off when done.*

- [x] 1. Add the JSON localization catalog — requirements: `Sources/TimeTrackerApp/Resources/Localization.json` bundled via `Package.swift` (`resources: [.copy("Resources/Localization.json")]` on `TimeTrackerApp`), shape `{ "en": { "<key>": "<string>" }, "es": { "<key>": "<string>" } }`, every key present in both languages, covering every app-owned UI string currently hardcoded in `Sources/TimeTrackerApp` (tab labels, empty states, editor labels/placeholders, warnings, notification body strings, weekday labels, default state labels "In range"/"Out", preset name/labels/detail names/override labels); strings with arguments use `%@`/`%d` format placeholders; commands: `swift build`
- [x] 2. Add the loader and route every UI string through it — requirements: a `Localization` type in `TimeTrackerApp` decodes `Localization.json` from `Bundle.module`, exposes `t(_ key:) -> String` (and `format` for parameterized keys), falls back to the `en` value then the key itself when a lookup is missing; every `Text`/`Button`/`Label`/`Toggle`/`Picker`/`Help`/warning/notification string in `TimeTrackerApp` reads through it, including `StateChip`'s `displayStates` defaults (resolved from JSON at display time), `CheckPresets` (localized at creation time through `store.add`), and `TimeTrackerApp.deliverFlipNotification`; weekday names (`Mon`..`Sun`, including the `EEE` segments of remote-time and window-slice labels) come from JSON keys `weekday.mon`..`weekday.sun` rather than `DateFormatter` locale data; time-of-day formats stay `HH:mm`; `TimeTrackerCore` stays UI-free and unchanged; commands: `swift build && swift test`
- [x] 3. Add the Settings tab with the language dropdown — requirements: a third segmented tab after Edit named `Settings` (order Status | Edit | Settings) whose content is a single `Picker` (menu style) offering exactly `English` and `Español`, bound to `UserDefaults.standard` key `uiLocale` with values `en`/`es`; changing the dropdown updates all visible UI chrome immediately without relaunch; stored check text (user-entered or written by the preset at creation time) is never retroactively translated; commands: `swift run TimeTracker`
- [x] 4. Implement the first-launch default — requirements: when `uiLocale` is absent, resolve macOS's preferred language (`Locale.preferredLanguages` / `Locale.current.languageCode`): any `es`-prefixed code writes `es`, everything else (including `en` and other languages) writes `en`; the resolved value is written once and frozen — later macOS language changes do not affect the app until the dropdown is used; the dropdown always overrides the default; commands: `open dist/TimeTracker.app`
- [x] 5. Update docs and contracts — requirements: `README.md` (Settings tab, `uiLocale` in `UserDefaults`, `Localization.json` location/shape, default rule, no `checks.json` schema change), `AGENTS.md` (UI copy contract becomes "all app-owned UI text comes from `Localization.json`; add keys to both `en` and `es`; user-entered check/state/detail text is never localized"), `context/PLAN.md` gains the localization decision; commands: `bash Scripts/package-app.sh`
- [x] 6. Run the localization smoke — requirements: on the bundled app, switch the dropdown to `Español` and confirm every visible surface (tabs, rows, editor, warnings, notification copy at a flip) switches live; switch back to `English` and confirm the reverse; relaunch and confirm the last selection sticks; confirm `checks.json` is byte-identical before and after; commands: `open dist/TimeTracker.app`

## 2. No-go

*Implementations explicitly NOT carried out in this spec. The agent MUST NOT do*
*these.*

- No `checks.json` / `Check` / `ChecksFile` schema changes, no localization of user-entered text (check names, `StateStyle.label`/`note`, `DetailRow` values/names, `DayOverride.label` when user-typed), and no retroactive translation of already-stored check text when the language changes.
- No Apple String Catalogs / `.strings` / `NSLocalizedString` — the JSON catalog is the single source of UI text.
- No auto-switching language after first launch; no per-check languages; no plural/gender engines, ICU messages, or number/currency/date localization (time-of-day output stays `HH:mm`).
- No `TimeTrackerCore` changes, no `OverlapEngine` behavior changes, and no re-pinning of existing test wording/behavior.
- No third-party dependencies.

## 3. Testing criteria

*All boxes checked = spec done.*

- [x] `swift build && swift test` passes (repo root, 8 existing tests still green)
- [x] objective 1: `Localization.json` exists under `Sources/TimeTrackerApp/Resources/`, decodes, and contains the same key set in `en` and `es`
- [x] objective 2: `grep` finds no hardcoded UI string literals in `Sources/TimeTrackerApp` outside `Localization.json`; `swift run TimeTracker` shows English copy unchanged from today
- [x] objective 3: Settings tab appears after Edit with the `English`/`Español` dropdown; selecting `Español` re-renders every visible surface live and selecting `English` restores it
- [x] objective 4: first launch with a Spanish macOS preferred language starts in Spanish, first launch otherwise starts in English; relaunching keeps the dropdown selection regardless of the system language
- [x] objective 5: docs match shipped behavior; `AGENTS.md` checklist items are consistent with the code
- [x] objective 6: `bash Scripts/package-app.sh` → `dist/TimeTracker.app` passes the bilingual smoke; `checks.json` is unchanged
- [x] every objective in section 1 is checked

## 4. Divergences

*REQUIRED at the end of every spec. If reality diverged from this spec while*
*executing it, append a numbered entry here — do not silently drop it and do not*
*edit the objectives to match what you actually did. Each entry: what diverged,*
*why, the fix attempt(s), and (if unresolved) a pointer to a tracking file. Keep*
*the* `- [ ]` *testing-criteria box unchecked and note the divergence inline next*
*to it.*

- [x] every divergence found is appended below (or the section reads "None.")

None.

*Format (one numbered item per divergence):*

1. <what diverged and its current state> — <why it could not be done as
   written, citing the No-go rule or spec that blocks it> (Verified <date>:
   <N> fix attempts — <attempt 1>, <attempt 2>, <attempt 3> — all fenced by
   <constraint>; <impact> is deferred to <later spec> by design, not a defect.)

### Unresolved divergences → `specs/divergencies/`

*A divergence that stays OPEN because a later spec owns the fix MUST also get a*
*tracking file in `specs/divergencies/`, so future agents can find and clear it.*
*Name it `<spec-id>-<short-slug>.md` (e.g. `06-json-missing-key.md`). Include:*
*source spec + the exact criteria it blocks, what is broken (files/imports), why*
*each fix attempt was fenced, and a "how to clear it" checklist naming the spec*
*that resolves it plus the commands to re-verify. Then link the tracking file from*
*the matching Divergence entry above (e.g. "**Tracked for future check-up in**
*`specs/divergencies/<file>.md`**.**"). When the later spec lands and the checks*
*pass, mark the criteria `[x]` and remove the tracking file.*

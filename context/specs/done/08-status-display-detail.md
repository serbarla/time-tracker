# 08 — Status tab display detail (issue #12 items 6, 9)

Sprint 2 of `QOL_IMPROVEMENTS_1_SPRINT_PLAN.md` (issue #12,
https://github.com/serbarla/time-tracker/issues/12). Two display upgrades to the
Status tab: city name next to the header clock, and 24-hour tape graduations on
the timeline. Depends on: 01–06. Self-contained: does not require 07/09 and they
do not require it (all three touch `Localization.json`, always different keys;
this spec adds only `status.clockCity`).

Read the nearest `AGENTS.md` (target workspace, then parents up to repo root)
before executing. If reality diverges from this spec: stop, append the
divergence under Testing criteria, NEVER improvise outside the objectives.

## 1. Objectives

*Numbered, ordered. Each: one verb sentence, its requirements, exact commands.*
*Check off when done.*

- [x] 1. Show the zone's city name next to the header clock — requirements: in `Sources/TimeTrackerApp/StatusTab.swift`, `CheckStatusRow` header HStack (currently :61-74): replace `Text(remoteLabel(now))` (:71-73) with `Text(loc.format("status.clockCity", remoteLabel(now), check.cityName))`; add key `status.clockCity` to `Sources/TimeTrackerApp/Resources/Localization.json` with value `"%@-%@"` in **both** `en` and `es` (language-neutral format); add a private extension at the bottom of `StatusTab.swift` (no equivalent exists in `Sources/`): `private extension Check { var cityName: String { timeZoneIdentifier.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? timeZoneIdentifier } }` — "Asia/Shanghai" → "Shanghai"; "America/Argentina/Buenos_Aires" → "Buenos Aires"; multi-segment keeps the last component ("America/Indiana/Indianapolis" → "Indianapolis"); no "/" → the identifier verbatim; `remoteLabel`'s weekday prefix stays when present (day-spill renders e.g. "Fri 23:00-Shanghai"); commands: `swift build`
- [x] 2. Draw 24-hour tape graduations on the timeline — requirements: in `Sources/TimeTrackerApp/OverlapTimeline.swift` (single `Canvas`, currently :20-58): change `StatusTab.swift:81` invocation `.frame(height: 18)` to `.frame(height: 30)`; ticks: for each `h` in 0..<24 at `x(dayStart + 3600 * Double(h))` a 1pt-wide rect rising from y=20 — minor `y ∈ [18, 20]`, major (`h % 3 == 0`) `y ∈ [16, 20]` — filled `Color(white: 0.6)`; numbers `"00" "03" "06" "09" "12" "15" "18" "21"` (`String(format: "%02d", h)`, `h % 3 == 0`): resolved `Text`, `.font(.system(size: 7))`, `.foregroundStyle(.secondary)`, drawn at y=25.5 below the ticks; `h == 0` draws `anchor: .leading` at x+1 (a centered "00" clips at the canvas edge), the other seven `anchor: .center` at their tick x; overlap bands (currently :36-50) change from the 20%–80% relative rect to the tape region `y ∈ [2, 16]`; the "now" marker (:52-57) keeps its full-height stroke across tape and numbers; `x(_:)`/`localCalendar` mapping unchanged; commands: `swift build`

## 2. No-go

*Implementations explicitly NOT carried out in this spec. The agent MUST NOT do*
*these.*

- No `Localization.json` changes other than adding `status.clockCity` to both blocks (07 edits `status.warning` es; 09 adds `settings.*`/`notify.lead` — those keys belong to those specs).
- No change to `remoteLabel`'s weekday-prefix behavior (contingency in the sprint plan — strictly `HH:mm-City` is out of scope unless the user asks).
- No changes to `CheckEditorView.swift`, `ContentView.swift`, `TimeTrackerApp.swift`, `OverlapEngine`, or the persisted schema; no `cityName` caching or lookup-table work (the split/replace is enough).
- No unit tests (repo policy: e2e/integration only), no third-party dependencies, no docs/`context/PLAN.md` edits (no product decision changes here).

## 3. Testing criteria

*All boxes checked = spec done.*

- [x] `swift build && swift test` passes (repo root, 8 existing tests still green)
- [x] `bash Scripts/ui-smoke.sh` passes
- [x] objective 1: row header right shows `HH:mm-Shanghai`-style label (clock + city) for a check on `Asia/Shanghai`; a check on `America/Argentina/Buenos_Aires` shows `Buenos Aires`; with day-spill the weekday prefix still renders ("Fri 23:00-Shanghai")
- [x] objective 2: timeline strip is 30pt tall with hour ticks along the bottom and numbers 00 03 06 09 12 15 18 21 under every third tick; "00" is not clipped at the left edge; bands keep their color; "now" is still a full-height line
- [x] `checks.json` unchanged by the smoke run
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
*Name it `<spec-id>-<short-slug>.md` (e.g. `08-clock-city-clipped.md`). Include:*
*source spec + the exact criteria it blocks, what is broken (files/imports), why*
*each fix attempt was fenced, and a "how to clear it" checklist naming the spec*
*that resolves it plus the commands to re-verify. Then link the tracking file from*
*the matching Divergence entry above (e.g. "**Tracked for future check-up in**
*`specs/divergencies/<file>.md`**.**"). When the later spec lands and the checks*
*pass, mark the criteria `[x]` and remove the tracking file.*

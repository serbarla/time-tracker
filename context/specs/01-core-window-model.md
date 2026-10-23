# 01 — Core: v2 check model, day overrides, window transitions

Implements `context/PLAN.md` §v5 "Generalized model" and "Engine additions" (phase 1 of
"Phases (each shippable)"). Pure `TimeTrackerCore` work. Depends on: nothing. Blocks:
02, 03, 04, 05.

Read the nearest `AGENTS.md` (target workspace, then parents up to repo root)
before executing. If reality diverges from this spec: stop, append the
divergence under Testing criteria, NEVER improvise outside the objectives.

## 1. Objectives

*Numbered, ordered. Each: one verb sentence, its requirements, exact commands.*
*Check off when done.*

- [x] 1. Extend `Check`/`ChecksFile` with optional v2 fields — requirements: `Check` gains `states: CheckStates?` (`active`/`inactive` `StateStyle {label, color, note}`), `details: [DetailRow]` (`{name, active, inactive}`), `dayOverrides: [DayOverride]` (`{from, to, mode: forceActive|forceInactive, label}`), `notifyOnFlip: Bool = false`; new types `public`, `Codable`, `Sendable` in `TimeTrackerCore`; `StateColor` enum = green/grey/red/orange/yellow/blue/purple; absent JSON keys decode to `nil`/`[]`/`false` so v1 files load unchanged; `ChecksFile` writes `version: 2`; commands: `swift build`
- [x] 2. Evaluate `dayOverrides` inside `OverlapEngine` — requirements: `evaluate(check:now:)` stays pure; an override covers an instant when its inclusive `from`/`to` (`yyyy-MM-dd`, check-zone dates) contain the instant's check-zone date; override wins over schedule (`forceInactive` = inactive even inside a band, `forceActive` = active even outside all bands); overnight spillover dies at 00:00 of a `forceInactive` day; malformed dates or modes are ignored, never fatal; commands: `swift build`
- [x] 3. Compute window transitions — requirements: `OverlapState` gains `windowStart: Date?`, `nextTransition: Date?`, `upcoming: [WindowSlice]` (`public struct WindowSlice {start, end, isActive}`); `windowStart` = start of the maximal same-state stretch (walks back over touching same-state windows, matching `currentWindowStart` in the reference implementation); `nextTransition` = first future state change scanning band edges and override day boundaries, forward scan bounded to 14 days; the existing 8 test cases stay green (mechanical compile fixes allowed, behavior re-pinning forbidden); commands: `swift build`, `swift test`
- [x] 4. Prove the DeepSeek fixture instants — requirements: a temporary integration harness in the test target (deleted before yield) drives `OverlapEngine` with a DeepSeek-shaped check (zone `Asia/Shanghai`, mon–fri `09:00`–`12:00` + `14:00`–`18:00`, sat/sun empty, override `2026-10-01`..`2026-10-07` `forceInactive` "National Day") and asserts: active at `2026-10-23T02:00:00Z`, inactive at `2026-10-23T05:00:00Z`, inactive at `2026-10-24T02:00:00Z` (Beijing Saturday), inactive at `2026-10-05T02:00:00Z` (holiday Monday beats the weekday schedule), `nextTransition` at `2026-10-23T02:00:00Z` equals `2026-10-23T04:00:00Z`; commands: `swift test --filter WindowFixture`
- [x] 5. Prove override boundaries and v1/v2 JSON compatibility — requirements: the same harness asserts an overnight range (`22:00`–`02:00`) is killed at 00:00 of a `forceInactive` day and resumes on schedule afterwards, and that a v1 `checks.json` fixture decodes with defaults (`states` nil, `details` empty, `notifyOnFlip` false) and re-encodes as `"version": 2`; commands: `swift test --filter WindowFixture`

## 2. No-go

*Implementations explicitly NOT carried out in this spec. The agent MUST NOT do*
*these.*

- No UI work in `Sources/TimeTrackerApp` — specs 02–04 own it.
- No DeepSeek name, rate values, or holiday dates anywhere in `TimeTrackerCore`; the preset is spec 05 data.
- No `WEEKEND_RULE_START`-style historical rule versioning — the engine only evaluates now → future.
- No new permanent unit-test files or cases used as verification (Testing policy); the temporary harness is removed before yield and the existing 8 cases stay green.
- No schema breaks: v1 `checks.json` loads with zero migration steps; no renames of `timeZoneIdentifier`, `schedule`, or the `mon`..`sun` keys.

## 3. Testing criteria

*All boxes checked = spec done.*

- [x] `swift build && swift test` passes (repo root)
- [x] objectives 1–3: `swift build` → `Build complete!`; `swift test` → the 8 existing cases green
- [x] objective 4: `swift test --filter WindowFixture` → all fixture assertions pass
- [x] objective 5: same run covers the overnight kill and v1 decode / v2 encode; harness deleted afterwards → `swift build && swift test` still green
- [x] every objective in section 1 is checked

## 4. Divergences

*REQUIRED at the end of every spec. If reality diverged from this spec while*
*executing it, append a numbered entry here — do not silently drop it and do not*
*edit the objectives to match what you actually did. Each entry: what diverged,*
*why, the fix attempt(s), and (if unresolved) a pointer to a tracking file. Keep*
*the* `- [ ]` *testing-criteria box unchecked and note the divergence inline next*
*to it.*

- [x] every divergence found is appended below (or the section reads "None.")

1. The persisted `checks.json` is written with `"version": 2`, but `ChecksFile`'s
   initializer keeps `version` defaulting to `1`; only the store — the sole writer —
   passes `ChecksFile.currentVersion` (2). — Changing the default to 2 would make the
   existing `CheckStoreTests.testCodableRoundTrip` (which asserts a
   `ChecksFile(checks:)` round-trip equals 1) fail, and the "8 existing cases stay
   green / behavior re-pinning forbidden" requirement fences editing that assertion.
   (Verified 2026-10-23: 1 fix attempt — store-side
   `ChecksFile(version: ChecksFile.currentVersion, checks:)` — the objective-5 harness
   read `"version": 2` off disk, so the spec's observable requirement holds; no
   testing criterion is blocked.)

*Format (one numbered item per divergence):*

1. <what diverged and its current state> — <why it could not be done as
   written, citing the No-go rule or spec that blocks it> (Verified <date>:
   <N> fix attempts — <attempt 1>, <attempt 2>, <attempt 3> — all fenced by
   <constraint>; <impact> is deferred to <later spec> by design, not a defect.)

### Unresolved divergences → `specs/divergencies/`

*A divergence that stays OPEN because a later spec owns the fix MUST also get a*
*tracking file in `specs/divergencies/`, so future agents can find and clear it.*
*Name it `<spec-id>-<short-slug>.md` (e.g. `01-window-fixture-fails.md`). Include:*
*source spec + the exact criteria it blocks, what is broken (files/imports), why*
*each fix attempt was fenced, and a "how to clear it" checklist naming the spec*
*that resolves it plus the commands to re-verify. Then link the tracking file from*
*the matching Divergence entry above (e.g. "**Tracked for future check-up in**
*`specs/divergencies/<file>.md`**.**"). When the later spec lands and the checks*
*pass, mark the criteria `[x]` and remove the tracking file.*

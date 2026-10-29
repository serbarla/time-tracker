# 05 — DeepSeek pricing preset, docs, and contract updates

Implements `context/PLAN.md` §v5 "Preset" and phase 5 of "Phases (each shippable)".
Depends on: 01, 02, 03, 04. Closes out §v5.

Read the nearest `AGENTS.md` (target workspace, then parents up to repo root)
before executing. If reality diverges from this spec: stop, append the
divergence under Testing criteria, NEVER improvise outside the objectives.

## 1. Objectives

*Numbered, ordered. Each: one verb sentence, its requirements, exact commands.*
*Check off when done.*

- [x] 1. Add the "DeepSeek pricing" preset — requirements: a template entry in the Edit tab creates a check through `store.add`: name `DeepSeek pricing`, zone `Asia/Shanghai`, mon–fri `09:00`–`12:00` + `14:00`–`18:00`, sat/sun empty; `states`: "Peak pricing" (red) / "Off-peak · half price" (green); `dayOverrides` seeded from the reference `CN_HOLIDAYS` data (`2026-09-25`..`2026-09-27` "Mid-Autumn", `2026-10-01`..`2026-10-07` "National Day", both `forceInactive`); `details` = six rows, unit "per 1M tokens", (off-peak/peak): V4.1 Flash input `$0.15`/`$0.30`, cached `$0.003`/`$0.006`, output `$0.60`/`$1.20`; V4 Pro input `$0.66`/`$1.32`, cached `$0.022`/`$0.044`, output `$1.98`/`$3.96`; `notifyOnFlip` false; everything user-editable afterward; commands: `swift run TimeTracker`
- [x] 2. Update docs and contracts — requirements: `README.md` (v2 schema fields with JSON example, preset usage, notification behavior and its bundled-app requirement), `AGENTS.md` (timeline contract revised to "takes the check's active-state color, green by default, while `state.isOverlapping`, grey otherwise"; persistence section gains the v2 fields and `"version": 2`; UI smoke gains the notification step; test count line stays accurate), `context/PLAN.md` §v5 marked implemented with the date; commands: `bash Scripts/package-app.sh`
- [x] 3. Run full regression — requirements: debug and packaged builds green; end-to-end smoke across the surfaces of specs 01–04 on the bundled app (preset check renders chips, countdown, upcoming table, details; editor round-trips; menubar tint and boundary flip; notification at flip); commands: `swift build && swift test`, `bash Scripts/package-app.sh`, `open dist/TimeTracker.app`

## 2. No-go

*Implementations explicitly NOT carried out in this spec. The agent MUST NOT do*
*these.*

- No DeepSeek code paths outside the preset data — the engine stays zone/schedule generic and other checks keep working unchanged.
- No network calls and no automatic holiday-list updates: `CN_HOLIDAYS` is static, user-editable `dayOverrides` data.
- No engine behavior changes "to make the preset nicer"; adjust the preset data instead.
- No re-pinning of existing test wording/behavior and no README rewrites beyond v5-relevant sections.

## 3. Testing criteria

*All boxes checked = spec done.*

- [x] `swift build && swift test` passes (repo root)
- [x] objective 1: preset created → Status shows "Peak pricing"/"Off-peak · half price" chips, countdown, upcoming table, and the six detail rows; Edit shows the seeded schedule, both holiday overrides, and the toggle
- [x] objective 2: docs match the shipped behavior; `AGENTS.md` checklist items are consistent with the code
- [x] objective 3: `bash Scripts/package-app.sh` → `dist/TimeTracker.app` launches and the full smoke passes
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
*Name it `<spec-id>-<short-slug>.md` (e.g. `05-docs-stale-vs-behavior.md`). Include:*
*source spec + the exact criteria it blocks, what is broken (files/imports), why*
*each fix attempt was fenced, and a "how to clear it" checklist naming the spec*
*that resolves it plus the commands to re-verify. Then link the tracking file from*
*the matching Divergence entry above (e.g. "**Tracked for future check-up in**
*`specs/divergencies/<file>.md`**.**"). When the later spec lands and the checks*
*pass, mark the criteria `[x]` and remove the tracking file.*

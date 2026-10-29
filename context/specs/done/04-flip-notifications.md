# 04 — Flip notifications with staleness grace

Implements `context/PLAN.md` §v5 "UI" notification part (phase 4 of "Phases (each
shippable)"). Depends on: 01 (engine transitions), 02 (editor surface for the toggle).
Blocks: 05.

Read the nearest `AGENTS.md` (target workspace, then parents up to repo root)
before executing. If reality diverges from this spec: stop, append the
divergence under Testing criteria, NEVER improvise outside the objectives.

## 1. Objectives

*Numbered, ordered. Each: one verb sentence, its requirements, exact commands.*
*Check off when done.*

- [x] 1. Deliver flip notifications — requirements: `UserNotifications` (`UNUserNotificationCenter`) authorization requested lazily on the first enabled `notifyOnFlip` check; on a state flip deliver one notification per check titled `<check name>: <new StateStyle.label>` with a message stating when the next flip comes (`until HH:mm` / `from HH:mm`, matching the existing copy tone); commands: `bash Scripts/package-app.sh`, `open dist/TimeTracker.app`
- [x] 2. Detect flips with a staleness grace — requirements: last-seen state tracked in memory per check on every evaluation (60s timer and boundary timer); the first observation after launch records state only and never notifies; announce only when the flip is fresh (`now - windowStart <= 5 minutes`), otherwise silently resync so flips missed while asleep or closed are never announced late; checks without `notifyOnFlip` never notify; commands: `open dist/TimeTracker.app`
- [x] 3. Add the editor toggle — requirements: `CheckEditorView` gains an on/off toggle bound to `notifyOnFlip` in the existing copy style, persisted through `store.update` with the original `id`; commands: `swift run TimeTracker`

## 2. No-go

*Implementations explicitly NOT carried out in this spec. The agent MUST NOT do*
*these.*

- No repeated permission prompts — authorization is requested once, on first enable.
- No notifications for checks without `notifyOnFlip` (default off, including all v1 checks).
- No schema changes beyond `notifyOnFlip`; no notification history, grouping, or sounds beyond the system default.
- No changes to `OverlapEngine` or the menubar refresh paths (specs 01, 03).

## 3. Testing criteria

*All boxes checked = spec done.*

- [x] `swift build && swift test` passes (repo root)
- [x] objective 1: bundled app, toggle on, boundary within 2 minutes → banner appears at the flip with the check name and new state label
- [x] objective 2: relaunch the bundled app more than 5 minutes after a flip already passed → no banner; a flip while the app runs → exactly one banner
- [x] objective 3: toggle off → saving persists `"notifyOnFlip": false` in `checks.json` and no further banners
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
*Name it `<spec-id>-<short-slug>.md` (e.g. `04-banner-never-fires.md`). Include:*
*source spec + the exact criteria it blocks, what is broken (files/imports), why*
*each fix attempt was fenced, and a "how to clear it" checklist naming the spec*
*that resolves it plus the commands to re-verify. Then link the tracking file from*
*the matching Divergence entry above (e.g. "**Tracked for future check-up in**
*`specs/divergencies/<file>.md`**.**"). When the later spec lands and the checks*
*pass, mark the criteria `[x]` and remove the tracking file.*

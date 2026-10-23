# 03 — Menubar: boundary-aligned refresh and state tint

Implements `context/PLAN.md` §v5 "UI" menubar part (phase 3 of "Phases (each
shippable)"). Depends on: 01. Blocks: 05.

Read the nearest `AGENTS.md` (target workspace, then parents up to repo root)
before executing. If reality diverges from this spec: stop, append the
divergence under Testing criteria, NEVER improvise outside the objectives.

## 1. Objectives

*Numbered, ordered. Each: one verb sentence, its requirements, exact commands.*
*Check off when done.*

- [x] 1. Schedule menubar updates at window boundaries — requirements: in `AppDelegate` keep both mandated refresh paths (the 60-second `Timer` and the `store.$checks` subscription) untouched, and add a one-shot timer at `min(nextTransition)` across all checks, invalidated and rescheduled after every fire and on every store change, so a flip is rendered within ~2 seconds of its boundary instead of up to 60 seconds late; commands: `swift run TimeTracker`
- [x] 2. Tint the menubar icon by state — requirements: when any check is active the status icon takes the first active check's `states.active.color` (check order), otherwise green; v1 checks (no `states`) use green; the title stays the comma-joined overlapping check names, blank when none overlap; commands: `swift run TimeTracker`
- [x] 3. Handle edge cases — requirements: zero checks → static icon and blank title; deleting the last overlapping check clears the title immediately through the store subscription; several active checks → tint follows the first in check order; commands: `swift run TimeTracker`

## 2. No-go

*Implementations explicitly NOT carried out in this spec. The agent MUST NOT do*
*these.*

- No change to the title semantics (names only, no times or labels in the title).
- No new menubar tooltip — the countdown lives in the panel (spec 02).
- No `OverlapEngine` changes; no polling faster than 1 second; neither mandated refresh path may be removed or weakened.
- No notification code — spec 04 owns it.

## 3. Testing criteria

*All boxes checked = spec done.*

- [x] `swift build && swift test` passes (repo root)
- [x] objective 1: a check whose range starts within 2 minutes → title and icon flip within ~2 seconds of the boundary (`swift run TimeTracker`, observed in the menu bar)
- [x] objective 2: active check with a custom `states.active.color` → icon matches; no active checks → green icon
- [x] objective 3: deleting the last overlapping check clears the title immediately (AGENTS.md contract re-verified)
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
*Name it `<spec-id>-<short-slug>.md` (e.g. `03-flip-late-60s.md`). Include:*
*source spec + the exact criteria it blocks, what is broken (files/imports), why*
*each fix attempt was fenced, and a "how to clear it" checklist naming the spec*
*that resolves it plus the commands to re-verify. Then link the tracking file from*
*the matching Divergence entry above (e.g. "**Tracked for future check-up in**
*`specs/divergencies/<file>.md`**.**"). When the later spec lands and the checks*
*pass, mark the criteria `[x]` and remove the tracking file.*

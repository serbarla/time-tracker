# 02 — Status UI: state chips, countdown, upcoming windows, details

Implements `context/PLAN.md` §v5 "UI" status-row part plus the editor exposure the v2
fields require (phase 2 of "Phases (each shippable)"). Depends on: 01. Blocks: 05.

Read the nearest `AGENTS.md` (target workspace, then parents up to repo root)
before executing. If reality diverges from this spec: stop, append the
divergence under Testing criteria, NEVER improvise outside the objectives.

## 1. Objectives

*Numbered, ordered. Each: one verb sentence, its requirements, exact commands.*
*Check off when done.*

- [x] 1. Replace the status-row dot with a state chip — requirements: when `check.states != nil` show a colored chip with the current `StateStyle.label` in `StateStyle.color` (active/inactive per `OverlapState.isOverlapping`); when `states` is nil (v1 checks) render exactly today's dot (green overlapping, grey otherwise); name and remote-clock layout unchanged; commands: `swift run TimeTracker`
- [x] 2. Add countdown, progress, and the upcoming-windows table — requirements: per row show a live countdown to `nextTransition` (`H:MM:SS` while the panel is open), a progress bar spanning `windowStart`→`nextTransition`, and the next 4 `WindowSlice`s as rows (state chip, range label `HH:mm – HH:mm` with weekday fallback across days, duration; the current slice marked `Xh Ym left`); commands: `swift run TimeTracker`
- [x] 3. Add the details disclosure — requirements: a `DisclosureGroup` per check listing `details` rows with the current-state value and the next-state value (`from HH:mm`), hidden when `details` is empty; commands: `swift run TimeTracker`
- [x] 4. Color the timeline by state — requirements: `OverlapTimeline` bands take `states.active.color` (green when `states` is nil) while `isOverlapping`, grey otherwise; the "now" marker and `[start, end)` band semantics unchanged; commands: `swift run TimeTracker`
- [x] 5. Expose v2 fields in `CheckEditorView` — requirements: state label/color/note editors for both states (`StateColor` menu), `details` rows add/remove (name, active value, inactive value), `dayOverrides` rows add/remove (`from`/`to` date pickers, mode menu, label); every save goes through `store.update` with the original `id` (no duplicate checks); v1 checks open with empty lists and no states; commands: `swift run TimeTracker`

## 2. No-go

*Implementations explicitly NOT carried out in this spec. The agent MUST NOT do*
*these.*

- No menubar changes (icon tint, refresh scheduling) — spec 03 owns them.
- No notification code or toggles — spec 04 owns them.
- No DeepSeek preset — spec 05 owns it.
- No changes to `OverlapEngine` or `CheckStore` behavior; no mutation paths besides `add`/`update`/`remove`/`move`; no persistence from views.
- No new UI copy language — keep the existing mixed English/Spanish style ("Filtrar Zonas", "No zonas"); the "Zona" entry-type label is localized ("Time Zone" / "Zona Horaria").

## 3. Testing criteria

*All boxes checked = spec done.*

- [x] `swift build && swift test` passes (repo root)
- [x] objectives 1–4: AGENTS.md UI smoke (`pkill -x TimeTracker`; `swift run TimeTracker`; ⌃⌥T) on a check with custom states → chip, countdown, progress, upcoming table, details, and colored timeline render as specified
- [x] objective 5: edit that check's states/details/overrides and save → fields persist in `~/Library/Application Support/TimeTracker/checks.json` under the same `id`
- [x] a v1-style check (no `states`) renders the legacy dot/timeline exactly as today
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
*Name it `<spec-id>-<short-slug>.md` (e.g. `02-upcoming-table-overflows.md`). Include:*
*source spec + the exact criteria it blocks, what is broken (files/imports), why*
*each fix attempt was fenced, and a "how to clear it" checklist naming the spec*
*that resolves it plus the commands to re-verify. Then link the tracking file from*
*the matching Divergence entry above (e.g. "**Tracked for future check-up in**
*`specs/divergencies/<file>.md`**.**"). When the later spec lands and the checks*
*pass, mark the criteria `[x]` and remove the tracking file.*

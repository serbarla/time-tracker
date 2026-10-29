# 07 — QOL quick wins (issue #12 items 1, 2, 3, 5, 8)

Sprint 1 of `QOL_IMPROVEMENTS_1_SPRINT_PLAN.md` (issue #12,
https://github.com/serbarla/time-tracker/issues/12). Five small, independent UI
fixes: editor form width, Settings tab alignment, Quit tint, Details accordion
hit target, Spanish "Overlap" term. Depends on: 01–06. This spec is
self-contained; it does not require 08/09 and they do not require it (09 extends
the SettingsTab VStack this spec introduces — if 09 executes without 07, it wraps
its own container).

Read the nearest `AGENTS.md` (target workspace, then parents up to repo root)
before executing. If reality diverges from this spec: stop, append the
divergence under Testing criteria, NEVER improvise outside the objectives.

## 1. Objectives

*Numbered, ordered. Each: one verb sentence, its requirements, exact commands.*
*Check off when done.*

- [x] 1. Make the edit/add form span left-to-right — requirements: in `Sources/TimeTrackerApp/CheckEditorView.swift`, delete the trailing-reserve comment and `.padding(.trailing, 76)` on the ScrollView content VStack (currently :169-170) so rows end at the form root's existing 20pt padding, just before the overlay scrollbar; no other layout change (popover `.frame(width: 380, height: 588)` in `ContentView.swift:45` stays; `EditTab.swift`/`ContentView.swift` untouched by this objective); commands: `swift build` — **done via the spec's own contingency (`.padding(.trailing, 12)`), see Divergence 1**
- [x] 2. Align the Settings tab content top-left — requirements: in `Sources/TimeTrackerApp/ContentView.swift`, `SettingsTab` body (currently :66-84): keep the language `Picker` (label, `localeBinding`, `.pickerStyle(.menu)`) unchanged but wrap it in `VStack(alignment: .leading, spacing: 12) { … }`, then `.padding(10)`, then `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)`, replacing the current centered `.frame(maxWidth: .infinity, maxHeight: .infinity)`; the result matches how `StatusTab` content sits top-left; this VStack is the container 09's alerts picker stacks into — leave it empty of other content; commands: `swift build`
- [x] 3. Tint the Quit button red — requirements: in `Sources/TimeTrackerApp/ContentView.swift`, on the footer `Button(loc.t("app.quit"))` (currently :39-43) change `.foregroundStyle(.secondary)` to `.foregroundStyle(.red)`; label, action (`NSApp.terminate(nil)`), and `.buttonStyle(.plain)` unchanged; commands: `swift build`
- [x] 4. Make the "Details" accordion clickable on its whole label row — requirements: in `Sources/TimeTrackerApp/StatusTab.swift`, replace `detailsDisclosure`'s stock `DisclosureGroup` (currently :133-158) with a custom toggle: add `@State private var detailsExpanded = false` to `CheckStatusRow`; `detailsDisclosure` becomes `VStack(alignment: .leading, spacing: 4)` containing (a) `Button { detailsExpanded.toggle() } label: { HStack(spacing: 4) { Image(systemName: "chevron.right").rotationEffect(detailsExpanded ? .degrees(90) : .zero); Text(loc.t("status.details")).font(.caption.weight(.semibold)).foregroundStyle(.secondary); Spacer() }.contentShape(Rectangle()) }` with `.buttonStyle(.plain)` so the full row width is the hit target, and (b) `if detailsExpanded { …the existing detail rows, unchanged… }`; keep `.padding(.top, 2)`; do NOT keep `DisclosureGroup` + `onTapGesture` (macOS label taps can double-toggle against the built-in behavior); sole call site (`StatusTab.swift:100-102`) unchanged; commands: `swift build`
- [x] 5. Translate the Spanish "Overlap" term to "Intersección" — requirements: in `Sources/TimeTrackerApp/Resources/Localization.json`, replace the `es` value of `status.warning` (currently :118) `"Solape ahora — hasta las %@"` with `"Intersección ahora — hasta las %@"`; `en` block unchanged; no code change (the string renders via `warningText(until:)`, `StatusTab.swift:193-197`); no other key in either block is touched; commands: `swift build`

## 2. No-go

*Implementations explicitly NOT carried out in this spec. The agent MUST NOT do*
*these.*

- No changes to `EditTab.swift`, the popover frame in `ContentView.swift:45`, `OverlapTimeline.swift`, `TimeTrackerApp.swift`, or anything in `Sources/TimeTrackerCore`.
- No `Localization.json` changes other than the `status.warning` es value (08 adds `status.clockCity`; 09 adds `settings.*`/`notify.lead` — those keys belong to those specs).
- No schema/persistence changes, no `DisclosureGroup` retention with gesture hacks, no other strings translated or reworded ("Solape" appears in exactly one user-facing string — `status.warning`).
- No unit tests (repo policy: e2e/integration only), no third-party dependencies, no docs/`context/PLAN.md` edits (no product decision changes here).

## 3. Testing criteria

*All boxes checked = spec done.*

- [x] `swift build && swift test` passes (repo root, 8 existing tests still green)
- [x] `bash Scripts/ui-smoke.sh` passes
- [x] objective 1: Edit tab → open the editor → rows span from the left edge to ~20pt from the right (previously ~96pt), ending just before the overlay scrollbar; the "+" buttons are not obscured while scrolling (if they are, apply the contingency: `.padding(.trailing, 12)` instead of removing the padding — record as a divergence) — **contingency applied and recorded as Divergence 1; mid-scroll check: +/− buttons end x=1417, scrollbar thumb starts x=1421, no overlap**
- [x] objective 2: Settings tab → the language dropdown sits top-left like the other tabs' content
- [x] objective 3: footer Quit button renders red
- [x] objective 4: Status tab → "Details": clicking anywhere on the label row — not only the chevron — toggles the accordion, both directions
- [x] objective 5: Settings → language `es` → an overlapping check's warning line reads `Intersección ahora — hasta las HH:mm` (was `Solape ahora`)
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

1. Editor form rows keep a 12pt trailing reserve (`.padding(.trailing, 12)` on the
   ScrollView content VStack in `CheckEditorView.swift`) instead of ending at the
   form root's 20pt padding as objective 1's primary wording specifies — after the
   full padding removal, a mid-scroll capture (real scroll event, bundled app)
   showed the overlay scrollbar crossing the "+"/"−" day-tile buttons, so the "+"
   buttons were obscured while scrolling; the objective-1 testing criterion
   prescribes exactly this contingency (`.padding(.trailing, 12)` instead of
   removing the padding — record as a divergence), so no No-go rule was crossed.
   (Verified 2026-10-29: 1 fix attempt — restored `.padding(.trailing, 12)` after
   the initial removal — post-fix geometry: +/− buttons end at x=1417, scrollbar
   thumb starts at x=1421, mid-scroll screenshot confirms no overlap; `swift build`,
   `swift test`, `bash Scripts/ui-smoke.sh` re-pass after the change. Resolved by
   the spec's own contingency, not deferred to a later spec — no tracking file.)

*Format (one numbered item per divergence):*

1. <what diverged and its current state> — <why it could not be done as
   written, citing the No-go rule or spec that blocks it> (Verified <date>:
   <N> fix attempts — <attempt 1>, <attempt 2>, <attempt 3> — all fenced by
   <constraint>; <impact> is deferred to <later spec> by design, not a defect.)

### Unresolved divergences → `specs/divergencies/`

*A divergence that stays OPEN because a later spec owns the fix MUST also get a*
*tracking file in `specs/divergencies/`, so future agents can find and clear it.*
*Name it `<spec-id>-<short-slug>.md` (e.g. `07-quit-tint.md`). Include:*
*source spec + the exact criteria it blocks, what is broken (files/imports), why*
*each fix attempt was fenced, and a "how to clear it" checklist naming the spec*
*that resolves it plus the commands to re-verify. Then link the tracking file from*
*the matching Divergence entry above (e.g. "**Tracked for future check-up in**
*`specs/divergencies/<file>.md`**.**"). When the later spec lands and the checks*
*pass, mark the criteria `[x]` and remove the tracking file.*

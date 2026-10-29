# 09 — Menubar rotation and pre-overlap alerts (issue #12 items 4, 7)

Sprint 3 of `QOL_IMPROVEMENTS_1_SPRINT_PLAN.md` (issue #12,
https://github.com/serbarla/time-tracker/issues/12). Two interactive features:
the menubar label cycling through overlapping zones every 20s with a flip
animation, and a global alerts lead-time setting (default 2 min) scheduling
pre-overlap banners for `notifyOnFlip` checks. Depends on: 01–06. Recommended
after 07 (this spec's alerts picker stacks into the SettingsTab VStack 07
introduces) and after 08 (this spec's Spanish strings use "intersección" per
07's term fix), but self-contained: if 07 is absent, wrap the picker in the same
`VStack(alignment: .leading, spacing: 12)` + `.padding(10)` +
`.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)`
container yourself; if 08 is absent, still write the es strings with
"intersección".

Read the nearest `AGENTS.md` (target workspace, then parents up to repo root)
before executing. If reality diverges from this spec: stop, append the
divergence under Testing criteria, NEVER improvise outside the objectives.

## 1. Objectives

*Numbered, ordered. Each: one verb sentence, its requirements, exact commands.*
*Check off when done.*

- [x] 1. Rotate the menubar label through overlapping checks every 20s — requirements: in `Sources/TimeTrackerApp/TimeTrackerApp.swift`, `AppDelegate` (currently :17): add `private var rotationIndex = 0`, `private var flipTimer: Timer?`, `private var lastRenderedNames: [String] = []`; change `updateLabel()` (currently :90-112) to `updateLabel(animateTitle: Bool = false)` (all existing call sites keep working via the default) keeping everything it does today except the title: names empty → title `""` (unchanged); names changed since `lastRenderedNames` → reset `rotationIndex = 0` and store the new list; non-empty → title = `names[rotationIndex % names.count]` (one name at a time instead of the current comma-joined list at :96-102); when `animateTitle && names.count > 1`, immediately before assigning `button.title` add a `CATransition` (`type = .flip`, `subtype = .fromRight`, `duration = 0.35`) to the button layer (`statusItem?.button?.wantsLayer = true; statusItem?.button?.layer?.add(t, forKey: "flip")`) — the animation is applied only from the timer path, never on the 60s tick / store-subscription path; new 20s repeating `flipTimer` scheduled in `applicationDidFinishLaunching` beside `labelTimer` (currently :40-42), invalidated in `applicationWillTerminate` (:45-49), handler: `guard lastRenderedNames.count > 1 else { return }; rotationIndex += 1; updateLabel(animateTitle: true)`; icon tint (:106-109) and `imagePosition` (:100) untouched; no localization keys (the title shows check names); commands: `swift build`
- [x] 2. Add the alerts lead-time setting — requirements: new `UserDefaults` key `alertLeadMinutes` (`Int`, default `2`), mirroring the `uiLocale` pattern (`Localization.swift:16`); `SettingsTab` (`ContentView.swift`, currently :66-84) gains, inside the top-leading VStack and below the language Picker, a second menu `Picker` labeled `loc.t("settings.alerts")` with option tags 1/2/3/5/10/15 (`Int`), each rendered `loc.format("settings.alerts.minutes", n)`; binding get `UserDefaults.standard.object(forKey: "alertLeadMinutes") as? Int ?? 2`, set writes the same key; new keys in **both** blocks of `Resources/Localization.json`: `settings.alerts` — en `"Alert before overlap"`, es `"Alerta antes de la intersección"`; `settings.alerts.minutes` — `"%d min"` both; `notify.lead` — en `"%d min before the overlap"`, es `"%d min antes de la intersección"`; commands: `swift build`
- [x] 3. Schedule and deliver pre-overlap lead alerts — requirements: in `TimeTrackerApp.swift`: new `rescheduleLeadAlert(states:now:)` called at the end of `updateLabel()`; candidate = earliest `state.nextTransition` over `zip(checks, states)` where `check.notifyOnFlip && !state.isOverlapping` (an inactive check's `nextTransition` is always its flip to active — `Sources/TimeTrackerCore/OverlapEngine.swift:172-183`); target = candidate − `alertLeadMinutes * 60`; `target > now` → arm a one-shot `Timer` at `target` on `RunLoop.main` in `.common` (copy the `rescheduleBoundaryTimer` pattern, :129-139), capturing the check `id` and target transition `Date`; invalidate the previous lead timer on every call; `target <= now` → arm nothing (a window that already started, or a lead window the app launched into, stays silent — same policy as the flip-notification 5-minute grace, :159-161); on fire: look up the check by id, re-evaluate `OverlapEngine.evaluate(check:now:)`, deliver only if still `!isOverlapping`, the captured transition is still `state.nextTransition`, and `lastAlertedWindowStart[id] != transition` (new in-memory `private var lastAlertedWindowStart: [UUID: Date]`, sibling of `lastSeenStates` :28); then record `lastAlertedWindowStart[id] = transition`; delivery = new `deliverLeadAlert(check:)` modeled on `deliverFlipNotification` (:176-190): title `check.name`, body `loc.format("notify.lead", alertLeadMinutes)`; pre-overlap alerts fire **only for checks with `notifyOnFlip` enabled** — the per-check toggle gates them, the Settings value is one global lead time applied to all of them; picker changes take effect on the next `updateLabel()` (≤60s), and if the new target is already past, that window stays silent; commands: `swift build`

## 2. No-go

*Implementations explicitly NOT carried out in this spec. The agent MUST NOT do*
*these.*

- No `TimeTrackerCore` / `OverlapEngine` / persisted-schema changes; no changes to `deliverFlipNotification`, `announceFlips`, `requestNotificationAuthorizationOnce`, `rescheduleBoundaryTimer` behavior (copy patterns, don't modify them).
- No localization keys beyond `settings.alerts`, `settings.alerts.minutes`, `notify.lead`; no localization of the rotating title (it shows user-entered check names).
- No "Off" entry in the lead-time picker and no removal of the `notifyOnFlip` gate (that contingency is explicitly deferred to user decision — if the user wants alerts for every check, ask first).
- No animation on the 60s tick or store-subscription path; no changes to the icon tint or `imagePosition`.
- No unit tests (repo policy: e2e/integration only), no third-party dependencies, no docs/`context/PLAN.md` edits beyond what the change checklist requires (README if usage/storage behavior text changes).

## 3. Testing criteria

*All boxes checked = spec done.*

- [x] `swift build && swift test` passes (repo root, 8 existing tests still green)
- [x] `bash Scripts/ui-smoke.sh` passes
- [x] objective 1: two checks overlapping simultaneously → the menubar shows a single name; every 20s it flips to the other name with a flip animation; one/zero overlapping → static/empty title as before; no animation on edit/delete updates
- [x] objective 2: Settings tab shows the "Alert before overlap" menu with options 1/2/3/5/10/15 min, default 2; changing it persists across relaunch
- [x] objective 3: notifications need the bundled app (an unbundled `swift run` cannot post them): `bash Scripts/package-app.sh && open dist/TimeTracker.app`, with a check whose window starts in ~3 minutes and `notifyOnFlip` on → exactly one banner at windowStart−2 min, body `2 min before the overlap`; a check without `notifyOnFlip` starting at the same time posts nothing; the app launched after the target stays silent for that window; Quit the app when done
- [x] `checks.json` schema unchanged by the feature
- [x] every objective in section 1 is checked

Evidence (2026-10-29, bundled `dist/TimeTracker.app` + `TIMETRACKER_CHECKS_FILE` fixtures):
objective 1: menubar AX title polled across rotations — ALPHA → BRAVO at +20s → ALPHA at +40s, one name per render; burst screenshots around a flip catch the mid-animation frame (compressed/rotating title) between the before/after frames; single-overlap and zero-overlap fixtures render one static name and an empty title; `animateTitle` is `true` only from the `flipTimer` handler, so the 60s tick and store-subscription paths cannot animate (exercised by `ui-smoke.sh`'s edit/delete flow). Objective 2: Settings tab screenshot shows `Alert before overlap` = `2 min` by default; the opened menu lists exactly `1 min|2 min|3 min|5 min|10 min|15 min`; selecting `5 min`, quitting, and relaunching shows `5 min` again (`defaults` held `5`, then the key was deleted to restore the default). Objective 3: frames bracketing windowStart−2 min show exactly one banner (`SOON` / `2 min before the overlap`) at target and none for the `notifyOnFlip: false` check on the same window; a launch after the target produced no banner through the window start (only the expected flip banner at start, proving the app was alive), fixture byte-identical after every run.

## 4. Divergences

*REQUIRED at the end of every spec. If reality diverged from this spec while*
*executing it, append a numbered entry here — do not silently drop it and do not*
*edit the objectives to match what you actually did. Each entry: what diverged,*
*why, the fix attempt(s), and (if unresolved) a pointer to a tracking file. Keep*
*the* `- [ ]` *testing-criteria box unchecked and note the divergence inline next*
*to it.*

- [x] every divergence found is appended below (or the section reads "None.")

1. Objective 1's `CATransition.type = .flip` as written does not compile — current SDK `CATransitionType` exposes only `.fade`/`.moveIn`/`.push`/`.reveal` — current state: implemented as `CATransitionType(rawValue: "flip")`, the Swift raw value of `kCATransitionFlip`, behavior identical to the spec's intent (Verified 2026-10-29: 1 fix attempt — raw-value initializer after `swift build` reported `type 'CATransitionType' has no member 'flip'` — fenced by the SDK surface; the mid-flip animation was captured on screen, so no impact.)
2. Objective 1's title formula is `names[rotationIndex % names.count]` but the rendered title keeps the existing trailing space (`+ " "`) the comma-joined implementation had — current state: `names[rotationIndex % names.count] + " "` (Verified 2026-10-29: 1 choice — kept the separator so the single name doesn't hug the icon under the untouched `imagePosition = .imageRight`; dropping it would change icon spacing the spec explicitly froze; no criterion is blocked.)

*Format (one numbered item per divergence):*

1. <what diverged and its current state> — <why it could not be done as
   written, citing the No-go rule or spec that blocks it> (Verified <date>:
   <N> fix attempts — <attempt 1>, <attempt 2>, <attempt 3> — all fenced by
   <constraint>; <impact> is deferred to <later spec> by design, not a defect.)

### Unresolved divergences → `specs/divergencies/`

*A divergence that stays OPEN because a later spec owns the fix MUST also get a*
*tracking file in `specs/divergencies/`, so future agents can find and clear it.*
*Name it `<spec-id>-<short-slug>.md` (e.g. `09-lead-alert-missed.md`). Include:*
*source spec + the exact criteria it blocks, what is broken (files/imports), why*
*each fix attempt was fenced, and a "how to clear it" checklist naming the spec*
*that resolves it plus the commands to re-verify. Then link the tracking file from*
*the matching Divergence entry above (e.g. "**Tracked for future check-up in**
*`specs/divergencies/<file>.md`**.**"). When the later spec lands and the checks*
*pass, mark the criteria `[x]` and remove the tracking file.*

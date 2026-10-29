# QOL Improvements 1 — Sprint Breakdown (issue #12)

## Context

Issue #12 (https://github.com/serbarla/time-tracker/issues/12) lists 9 QOL items for the TimeTracker menu-bar app (SwiftPM; `Sources/TimeTrackerApp` UI, `Sources/TimeTrackerCore` logic). This document is the deliverable: the 9 items broken into 3 independent sprints grouped by complexity (quick wins → display detail → interactive features). Executing this plan makes no repo or GitHub changes — the document is the artifact; each sprint below is a self-contained spec a future implementation session executes top-to-bottom. Recommended order 1 → 2 → 3 (Sprint 1 prepares the Settings container Sprint 3 extends), but every sprint stands alone.

## Independence

Each sprint ships alone; none consumes another's code. Sequential merges are conflict-free; avoid parallel branches merging `Resources/Localization.json` (all three sprints touch it, always different keys: Sprint 1 edits `status.warning` es value; Sprint 2 adds `status.clockCity`; Sprint 3 adds `settings.*` + `notify.lead`).

---

## Sprint 1 — Quick wins (items 1, 2, 3, 5, 8)

### 1. Edit/add form spans left-to-right, ending just before the scrollbar
`Sources/TimeTrackerApp/CheckEditorView.swift`: the ScrollView (:95) content VStack (:96) carries `.padding(.trailing, 76)` at :169-170 (comment :169 reserves 20% of the 380pt popover for the overlay scrollbar). The form root already pads 20pt (:173) and stretches (:174); the 76pt reserve is the only thing keeping the form from spanning the width. Delete the comment and `.padding(.trailing, 76)` (:169-170): rows end at the root's 20pt padding, just before the overlay scrollbar. No changes in `EditTab.swift` or `ContentView.swift` (popover `.frame(width: 380, height: 588)` at `ContentView.swift:45` stays).

### 2. Settings tab content aligned top left
`Sources/TimeTrackerApp/ContentView.swift`, `SettingsTab` (:66-84). Body (:70-77) is a bare menu `Picker` with `.frame(maxWidth: .infinity, maxHeight: .infinity)` (:76) — it floats centered. Replace that frame: wrap the Picker (unchanged: label, `localeBinding`, `.pickerStyle(.menu)`) in `VStack(alignment: .leading, spacing: 12) { … }`, then `.padding(10)`, then `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)` — matching how `StatusTab` content sits top-left. This VStack is the container Sprint 3's alerts picker stacks into.

### 3. Quit button red tint
`Sources/TimeTrackerApp/ContentView.swift:39-43`: `Button(loc.t("app.quit")) { NSApp.terminate(nil) }` is styled `.buttonStyle(.plain)` + `.foregroundStyle(.secondary)` (:40-41). Change `.foregroundStyle(.secondary)` (:41) to `.foregroundStyle(.red)`. Label and action unchanged. (Tinting precedent directly above: `.tint(.green)` on the launch-at-login Toggle, :34.)

### 5. "Details" accordion clickable on its label
`Sources/TimeTrackerApp/StatusTab.swift`: `detailsDisclosure` (:133-158) is a stock `DisclosureGroup` whose label is a bare `Text` (:152-156) sized to intrinsic width — only the chevron reliably toggles. Replace the `DisclosureGroup` with a custom toggle. Rival pattern to avoid: keeping `DisclosureGroup` and adding `onTapGesture` to its label — on macOS a label tap can double-toggle against the built-in behavior.
- Add `@State private var detailsExpanded = false` to `CheckStatusRow` (:31).
- `detailsDisclosure` becomes `VStack(alignment: .leading, spacing: 4) { … }` containing: (a) `Button { detailsExpanded.toggle() } label: { HStack(spacing: 4) { Image(systemName: "chevron.right").rotationEffect(detailsExpanded ? .degrees(90) : .zero); Text(loc.t("status.details")).font(.caption.weight(.semibold)).foregroundStyle(.secondary); Spacer() }.contentShape(Rectangle()) }` with `.buttonStyle(.plain)` so the full row width is the hit target; (b) `if detailsExpanded { …the existing detail rows, unchanged, currently :135-151… }`. Keep `.padding(.top, 2)` (:157).
- Sole call site `StatusTab.swift:100-102` unchanged.

### 8. Spanish "Overlap" → "Intersección"
The Spanish term in use is "Solape". Exactly one user-facing string carries it: `status.warning` in `Sources/TimeTrackerApp/Resources/Localization.json`, es block :118 (`"Solape ahora — hasta las %@"`; en :19 is `"Overlap now — until %@"`). Replace the es value with `"Intersección ahora — hasta las %@"`. En block unchanged; no code change (rendered via `warningText(until:)`, `StatusTab.swift:193-197`).

---

## Sprint 2 — Status tab display detail (items 6, 9)

### 6. City name next to the header clock ("23:00-Shanghai")
`Sources/TimeTrackerApp/StatusTab.swift`, `CheckStatusRow` header HStack (:61-74): the right-side clock is `Text(remoteLabel(now))` (:71-73); `remoteLabel` = optional weekday prefix + `HH:mm` in the check's zone (:42-44, formatter :185-190). Append the zone's city:
- Replace the label with `Text(loc.format("status.clockCity", remoteLabel(now), check.cityName))`.
- New key `status.clockCity` in `Resources/Localization.json`, value `"%@-%@"` in **both** `en` and `es` (language-neutral format).
- New helper at the bottom of `StatusTab.swift` (no equivalent exists anywhere in `Sources/`): `private extension Check { var cityName: String { timeZoneIdentifier.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? timeZoneIdentifier } }` — "Asia/Shanghai" → "Shanghai"; "America/Argentina/Buenos_Aires" → "Buenos Aires"; multi-segment keeps the last component ("America/Indiana/Indianapolis" → "Indianapolis"); no "/" → the identifier verbatim.
- The weekday prefix stays when `remoteLabel` emits one (day-spill renders e.g. "Fri 23:00-Shanghai"); the issue's example is the no-prefix case.

### 9. 24-hour tape markings on the timeline
`Sources/TimeTrackerApp/OverlapTimeline.swift`: a single `Canvas` (:20-58) draws only the background (21-24), overlap bands (36-50, y 20%–80% of height), and the "now" marker (52-57) — no ticks or labels exist. `x(_:)` (:30-34) maps time→x across the local day (`localCalendar`, :13-17). Add tape graduations:
- `StatusTab.swift:81` (the invocation's `.frame(height: 18)`): change to `.frame(height: 30)` for the number row.
- Ticks: for each `h` in 0..<24 at `x(dayStart + 3600 * Double(h))`, a 1pt-wide rect rising from y=20 — minor `y ∈ [18, 20]`; major (`h % 3 == 0`) `y ∈ [16, 20]` — filled `Color(white: 0.6)`.
- Numbers `"00" "03" "06" "09" "12" "15" "18" "21"` (`String(format: "%02d", h)`, `h % 3 == 0`): resolved `Text`, `.font(.system(size: 7))`, `.foregroundStyle(.secondary)`, drawn at y=25.5 in the bottom band below the ticks. `h == 0` draws `anchor: .leading` at x+1 (a centered "00" clips at the canvas edge); the other seven `anchor: .center` at their tick x.
- Bands (:36-50) change from the 20%–80% relative rect to the tape region `y ∈ [2, 16]`; the now marker (:52-57) keeps its full-height stroke so it reads across tape and numbers.

---

## Sprint 3 — Interactive features (items 4, 7)

### 4. Menubar label flips through overlapping zones every 20s
`Sources/TimeTrackerApp/TimeTrackerApp.swift`, `AppDelegate` (:17). Today `updateLabel()` (:90-112) sets `statusItem?.button?.title` to all overlapping checks' names comma-joined (:96-102). Show one name at a time, cycling every 20s with a flip animation:
- New state: `private var rotationIndex = 0`, `private var flipTimer: Timer?`, `private var lastRenderedNames: [String] = []`.
- Change `updateLabel()` to `updateLabel(animateTitle: Bool = false)` (all call sites keep working via the default). It keeps everything it does today except the title: names empty → title `""` (unchanged); names changed since `lastRenderedNames` → reset `rotationIndex = 0`, store the new list; non-empty → title = `names[rotationIndex % names.count]`. When `animateTitle && names.count > 1`, immediately before assigning `button.title` add `CATransition` (`type = .flip`, `subtype = .fromRight`, `duration = 0.35`) to the button layer: `statusItem?.button?.wantsLayer = true; statusItem?.button?.layer?.add(t, forKey: "flip")`. The animation is applied only from the timer path, never on the 60s tick / store-subscription path.
- New 20s repeating `flipTimer`, scheduled in `applicationDidFinishLaunching` beside `labelTimer` (:40-42), invalidated in `applicationWillTerminate` (:45-49). Handler: `guard lastRenderedNames.count > 1 else { return }; rotationIndex += 1; updateLabel(animateTitle: true)`.
- Icon tint (:106-109) and `imagePosition` (:100) untouched. No localization keys (title shows check names).

### 7. Alerts lead-time option in Settings (default 2 min before overlap)
Pre-overlap alerts fire **only for checks with `notifyOnFlip` enabled** (the existing per-check "Notificar cambios de estado" toggle); the Settings value is one global lead time applied to all of them. Infrastructure is in `AppDelegate` (`TimeTrackerApp.swift`): `announceFlips` :146-164, `requestNotificationAuthorizationOnce` :166-171 (already `.alert, .sound`), `deliverFlipNotification` :176-190 (immediate delivery only — nothing schedules today), `rescheduleBoundaryTimer` :129-139 (the one-shot-timer pattern to copy).
- Setting: new UserDefaults key `alertLeadMinutes` (`Int`, default `2`), mirroring the `uiLocale` pattern (`Localization.swift:16`). `SettingsTab` gains, inside Sprint 1's top-leading VStack and below the language Picker, a second menu `Picker` labeled `loc.t("settings.alerts")` with option tags 1/2/3/5/10/15 (`Int`), each rendered `loc.format("settings.alerts.minutes", n)`; binding get `UserDefaults.standard.object(forKey: "alertLeadMinutes") as? Int ?? 2`, set writes the same key.
- New keys in **both** blocks of `Resources/Localization.json`: `settings.alerts` — en `"Alert before overlap"`, es `"Alerta antes de la intersección"`; `settings.alerts.minutes` — `"%d min"` both; `notify.lead` — en `"%d min before the overlap"`, es `"%d min antes de la intersección"` (term per item 8).
- Scheduling: new `rescheduleLeadAlert(states:now:)` called at the end of `updateLabel()`. Candidate = earliest `state.nextTransition` over `zip(checks, states)` where `check.notifyOnFlip && !state.isOverlapping` (an inactive check's `nextTransition` is always its flip to active; `Sources/TimeTrackerCore/OverlapEngine.swift:172-183`). Target = candidate − `alertLeadMinutes * 60`. `target > now` → arm a one-shot Timer at `target` on `RunLoop.main` in `.common` (copy `rescheduleBoundaryTimer` :129-139), capturing the check `id` and target transition `Date`; invalidate the previous lead timer on every call. `target <= now` → arm nothing: a window that already started, or a lead window the app launched into, stays silent (same policy as the flip-notification 5-minute grace, :159-161).
- On fire: look up the check by id, re-evaluate `OverlapEngine.evaluate(check:now:)`; deliver only if still `!isOverlapping`, the captured transition is still `state.nextTransition`, and `lastAlertedWindowStart[id] != transition` (new in-memory `private var lastAlertedWindowStart: [UUID: Date]`, sibling of `lastSeenStates` :28); then record `lastAlertedWindowStart[id] = transition`. Delivery = new `deliverLeadAlert(check:)` modeled on `deliverFlipNotification` (:176-190): title `check.name`, body `loc.format("notify.lead", alertLeadMinutes)`.
- Picker changes take effect on the next `updateLabel()` (≤60s); if the new target is already past, that window stays silent (missed-window rule above).

---

## Critical files & anchors
- `Sources/TimeTrackerApp/CheckEditorView.swift` — scroll content trailing pad :169-170 (item 1)
- `Sources/TimeTrackerApp/ContentView.swift` — Quit button :39-43 (item 3); `SettingsTab` :66-84 (items 2, 7)
- `Sources/TimeTrackerApp/StatusTab.swift` — `CheckStatusRow` header :61-74 (item 6), `detailsDisclosure` :133-158 (item 5), timeline `.frame(height:)` :81 (item 9)
- `Sources/TimeTrackerApp/TimeTrackerApp.swift` — `AppDelegate`: `updateLabel` :90-112 and timers :40-49 (item 4); notification code :146-190 (item 7)
- `Sources/TimeTrackerApp/OverlapTimeline.swift` — Canvas :20-58 (item 9)

## Verification
Every sprint ends green with `cd /Users/sergiobarba/projects/time-tracker/qol-inmprovements-1 && swift build && swift test` (8 tests) and `bash Scripts/ui-smoke.sh`. Then exercise the changed surface in the running app: `pkill -x TimeTracker; swift run TimeTracker`, open with Control+Option+T (panel needs a fixture store with at least one currently-overlapping check, e.g. via `TIMETRACKER_CHECKS_FILE` pointing at a copy of `checks.json` with an active schedule).

Sprint 1 —
1. Edit tab → open the editor: rows span from the left edge to ~20pt from the right (previously ~96pt), ending just before the overlay scrollbar.
2. Settings tab: the language dropdown sits top-left like the other tabs' content.
3. Footer Quit button renders red.
4. Status tab → "Details": clicking anywhere on the label row — not only the chevron — toggles the accordion, both directions.
5. Settings → language `es`: the overlapping check's warning line reads `Intersección ahora — hasta las HH:mm` (was `Solape ahora`).

Sprint 2 —
1. Row header right shows `HH:mm-Shanghai`-style label (clock + city) for a check on `Asia/Shanghai`; a check on `America/Argentina/Buenos_Aires` shows `Buenos Aires`.
2. Timeline strip is 30pt tall with hour ticks along the bottom and numbers 00 03 06 09 12 15 18 21 under every third tick; bands keep their color, "now" is still a full-height line.

Sprint 3 —
1. Two checks overlapping simultaneously → the menubar shows a single name; every 20s it flips to the other name with a flip animation. One/zero overlapping → static/empty title as before.
2. Settings tab shows the "Alert before overlap" menu, options 1/2/3/5/10/15 min, default 2.
3. Notifications need the bundled app (an unbundled `swift run` cannot post them): `bash Scripts/package-app.sh && open dist/TimeTracker.app`, with a check whose window starts in ~3 minutes and `notifyOnFlip` on → exactly one banner at windowStart−2 min, body `2 min before the overlap`; a check without `notifyOnFlip` starting at the same time posts nothing. Quit the app when done.

## Assumptions & contingencies
- Pre-overlap alerts gate on the per-check `notifyOnFlip` toggle (chosen); the lead time (default 2 min) is global. If the intent is alerts for every check regardless, add an "Off" entry to the picker and drop the `notifyOnFlip` condition in `rescheduleLeadAlert`.
- Item 1 reads "end just before the scrolling bar" as: drop the 76pt trailing reservation so the form ends at the root's 20pt padding, just before the ~15pt overlay scrollbar. Contingency: if the "+" buttons turn out to be obscured by the visible overlay scrollbar while scrolling, use `.padding(.trailing, 12)` on the scroll content instead of removing the padding.
- Item 6 keeps `remoteLabel`'s weekday prefix when present and appends the city. If the label must be strictly `HH:mm-City`, remove the `weekdayPrefix` call from `remoteLabel` (`StatusTab.swift:42-44`).
- The Spanish term is "Intersección": capitalized at sentence start (item 8's string), lowercase mid-sentence in Sprint 3's new strings.

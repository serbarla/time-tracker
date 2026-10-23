Read the nearest `AGENTS.md` (target workspace, then parents up to repo root)  
before executing. If reality diverges from this spec: stop, append the  
divergence under Testing criteria, NEVER improvise outside the objectives.

## 1. Objectives

*Numbered, ordered. Each: one verb sentence, its requirements, exact commands.*  
*Check off when done.*

- [ ] 1. <objective> — requirements: <requirements>; commands: `<command>`
- [ ] 2. <objective> — requirements: <requirements>; commands: `<command>`

## 2. No-go

*Implementations explicitly NOT carried out in this spec. The agent MUST NOT do*  
*these.*

- <no-go item>

## 3. Testing criteria

*All boxes checked = spec done.*

- [ ] `bun run build && bun run test` passes (repo root)
- [ ] <objective N>: `<command>` → <expected output>
- [ ] every objective in section 1 is checked

## 4. Divergences

*REQUIRED at the end of every spec. If reality diverged from this spec while*  
*executing it, append a numbered entry here — do not silently drop it and do not*  
*edit the objectives to match what you actually did. Each entry: what diverged,*  
*why, the fix attempt(s), and (if unresolved) a pointer to a tracking file. Keep*  
*the* `- [ ]` *testing-criteria box unchecked and note the divergence inline next*  
*to it, exactly as in* `specs/02-B-database-drizzle-to-mikroorm-kysely.md`*.*

- [ ] every divergence found is appended below (or the section reads "None.")

*Format (one numbered item per divergence):*

1. <what diverged and its current state> — <why it could not be done as
   written, citing the No-go rule or spec that blocks it> (Verified <date>:  
 <N> fix attempts — <attempt 1>, <attempt 2>, <attempt 3> — all fenced by  
 <constraint>; <impact> is deferred to <later spec> by design, not a defect.)

### Divergences

*Fill in at execution time. Example (from spec 02-B, kept as reference):*

1. Workspace `typecheck`/`lint` stay red in `@acme/api` only: its  
 `@acme/db/client`, `@acme/db/schema`, and `desc`/`eq` imports are removed by  
 objectives 1 and 7, but rewriting them is explicitly excluded (section 2,  
 spec 04). … api red is deferred to spec 04 by design, not a defect.)

### Unresolved divergences → `specs/divergencies/`

\*A divergence that stays OPEN because a later spec owns the fix MUST also get a  
tracking file in `specs/divergencies/`, so future agents can find and clear it.  
Name it `<spec-id>-<short-slug>.md` (e.g.  
`02-B-api-typecheck-lint-red.md`). Include: source spec + the exact criteria it  
blocks, what is broken (files/imports), why each fix attempt was fenced, and a  
"how to clear it" checklist naming the spec that resolves it plus the commands  
to re-verify. Then link the tracking file from the matching Divergence entry  
above (e.g. "**Tracked for future check-up in**  
`specs/divergencies/<file>.md`**.**"). When the later spec lands and the checks  
pass, mark the criteria `[x]` and remove the tracking file.\*
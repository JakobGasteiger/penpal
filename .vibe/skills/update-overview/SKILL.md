---
name: update-overview
description: Load this skill to sync .vibe/overview.md with recent project changes. Call it after making major changes (multi-file, architectural, new subsystems, workflow changes), or when the user invokes /update-overview. It reads git diffs since the last synced state — tracked via a gitignored sidecar marker in .vibe/.overview-sync — and rewrites only the affected overview sections.
---

# Update Overview

Keep `.vibe/overview.md` in sync with what actually changed in the repo.
The overview is high-level orientation (architecture, intent, gotchas) — never
line-level documentation, never redundant with code comments.

## 1. Read the sync marker

Read the sidecar file `.vibe/.overview-sync` (gitignored, a single line):

```
last_seen=<commit sha> fingerprint=<sha256> at=<iso8601 utc>
```

Extract `last_seen` and `fingerprint`. `.vibe/overview.md` and
`.vibe/.overview-sync` themselves are always excluded from change detection —
the overview's own edits and the sidecar's own rewrites are not project changes.

If there is no sidecar: stamp one at current HEAD (see step 4), report
"baseline initialized", and stop. Do not rewrite the overview from scratch.

## 2. Compute what is new since the marker

From the repo root, run exactly:

```bash
head=$(git rev-parse HEAD)
commits=$(git log --oneline "$last_seen"..HEAD)
changes=$(git diff "$last_seen" -- . ':(exclude).vibe/overview.md' ':(exclude).vibe/.overview-sync')
status=$(git status --porcelain -- . ':(exclude).vibe/overview.md' ':(exclude).vibe/.overview-sync')
untracked=$(git ls-files --others --exclude-standard -- . ':(exclude).vibe/overview.md' ':(exclude).vibe/.overview-sync')
fingerprint=$( { echo "$head"; git diff "$last_seen" -- . ':(exclude).vibe/overview.md' ':(exclude).vibe/.overview-sync'; \
  git status --porcelain -- . ':(exclude).vibe/overview.md' ':(exclude).vibe/.overview-sync'; \
  for f in $untracked; do echo "== $f"; sha256sum "$f"; done; } | sha256sum | cut -d' ' -f1)
```

- If `$head` == `last_seen`, `$fingerprint` == marker fingerprint, and there is
  no `$commits`: report "overview already up to date" and stop.
- Otherwise the new material is: `$commits` (commit subjects), `$changes` (the
  full diff vs the marker commit — this covers both commits made after the
  marker and uncommitted working-tree changes), `$status`, and the contents of
  the `$untracked` files (read those files; `git diff` does not show them).

## 3. Update the overview

Read the diffs and new files, then decide which overview sections are affected:

| Change involves | Section to touch |
|---|---|
| Project purpose, origin, AI direction | What this project is |
| App/backend structure, data flow, auth, realtime | Architecture at a glance / App flow |
| supabase/ migrations, config, RLS, storage | Backend (supabase/) |
| Build/run/test commands, dart-defines | How to run |
| Cross-cutting patterns, naming | Conventions worth knowing |
| Renames, platform quirks, traps, leftovers | Gotchas / pitfalls |
| Files added/removed/moved | Map of the repo |

Rules:

- **Merge, don't append.** If a change extends an existing section, edit that
  section in place. Remove statements the diff has made false.
- **Stay high-level.** Describe architecture, intent, and gotchas. Do not paste
  code, function names, or anything a reader gets from comments.
- **Preserve verified facts.** Owner corrections (e.g. the note that the
  "Start Colibri" task is unrelated to the project) stay unless the diff
  explicitly changes them.
- Keep the tone and structure of the existing document.
- If the diff is large or spans many areas, delegate per-area reading to
  subagents (one area each) and keep the overview editing yourself.

## 4. Re-stamp the marker

Overwrite the sidecar `.vibe/.overview-sync` with a single line:

```
last_seen=$head fingerprint=$fingerprint at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
```

using the freshly computed `$head` and `$fingerprint`. The sidecar is gitignored,
so re-stamping never dirties the working tree.

## 5. Report

Tell the user briefly: which commits/changes were processed, which overview
sections were updated (or "no overview changes needed"), and the new sidecar
marker (`.vibe/.overview-sync`).

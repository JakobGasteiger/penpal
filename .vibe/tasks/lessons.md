# Lessons

## 2026-11 — Do not infer project intent from incidental local tooling

**What happened:** While writing `.vibe/overview.md`, I saw the "Start Colibri"
task in `.vscode/tasks.json` (running `F:\LocalAI\Colibri\...` on folder open)
and concluded it was "the presumed AI backend for the pen-pal feature." The
owner corrected me: Colibri is a personal coding assistant, unrelated to the
project.

**Rule:** Config files can contain the owner's personal tooling, not just
project machinery. When an artifact is ambiguous (external absolute paths,
unfamiliar service names), treat it as unexplained until verified — never
pattern-match it into the project's architecture or intent. If the overview
mentions such an artifact, label it explicitly as unrelated.

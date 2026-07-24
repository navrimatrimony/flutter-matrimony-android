# flutter-apk — Member App

Flutter Android app for matrimony **members** (package `flutter_matrimony_android`). This is the actively developed user-facing app — not to be confused with the stale `FLUTTER MATRIMONY APP/` folder elsewhere in the workspace (build artifacts only, no source).

This project already contains [`AGENTS.md`](AGENTS.md) (written for Codex). **`AGENTS.md` is the source of truth** for project architecture, edit boundary, scope, and API contract facts — none of that is duplicated here. If anything in this file ever conflicts with `AGENTS.md`, `AGENTS.md` wins, **except** for the one point below.

## Claude-specific additions

- Same edit boundary and scope apply: only edit inside `flutter-apk/`; `../laravel-matrimony` is read-only reference.
- Before relying on any API field/route mentioned in `AGENTS.md`, re-verify it against the current Laravel code in `../laravel-matrimony` — the doc can go stale.
- **Commit workflow overrides `AGENTS.md`:** `AGENTS.md` says "do not commit unless explicitly asked." The user has since (2026-07-21) asked Claude Code to work in goal-based autonomous mode instead — see `../CLAUDE.md` → Working mode. Commit at stable checkpoints without asking each time; push only when the current goal names it. Everything else in `AGENTS.md` still stands as-is.

## Feature docs (Blueprint-equivalent for this repo)

- `docs/onboarding/SMART_ONBOARDING_BLUEPRINT.md` — onboarding feature roadmap/contract.
- `docs/onboarding/SMART_ONBOARDING_QA_CHECKLIST.md` — QA checklist for it.
- `docs/FLUTTER_EDIT_PROFILE_PARITY.md` — edit-profile parity notes.

Read the relevant one before touching that feature area.

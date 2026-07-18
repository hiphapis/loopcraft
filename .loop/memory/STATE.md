# STATE — session handoff

> updated: 2026-07-18

## Working on
- **Phase 3 (autonomous runner) — COMPLETE ✅** (v0.4.3). Sources: file / GitHub / Jira; write-back: none / comment / draft-pr. All dogfooded on loopcraft's own GitHub issues.

## Done (recent)
- v0.4.0: pluggable backlog source + write-back — GitHub reference adapter (`adapters/github.sh`), loop-run source-reading + write-back (none/comment/draft-pr), loop-init interview (Q1 source / Q2 write-back + gating), "Autonomous runner" README section + `assets/loopcraft-autonomous-runner.svg`.
- Dogfood on loopcraft's own GitHub issues (comment mode): validated `list`/`report` against the real `gh`, and `Closes #N` auto-close on merge. Closed #1, #2, #3, #6.
- v0.4.1: cmd_report exit-code aggregation (#1), report error-path tests (#2), loop-init localization broadened (#3), test-authoring fallback Codex→context-isolated subagent (#6). Suite 35→39.
- v0.4.2: write-back seam (#4) — PR creation split out of `report` into a `pr` subcommand + `config.pr` (loop-run orchestrates push → config.pr → report). Suite 39→42.
- v0.4.3: bundled Jira adapter (`adapters/jira.sh`, #5) — curl + Jira REST v2 list/report; task-tracker-only, composes with a GitHub `config.pr`. **Phase 3 ✅.** Suite 42→51.

## Next steps
- **Phase 3 ✅ complete** (all issues #1–#6 closed). Optional follow-ups: reinstall/update the installed plugin (repo v0.4.3 vs the stale installed version) to dogfood the installed artifact; live Jira smoke once an instance is available; consider Phase 4 (prompt-driven write-back in loop-task, GitHub Projects/Milestone selection).
- Reinstall/update the installed plugin (repo is v0.4.1; the loaded plugin was stale v0.3.2) to dogfood the installed artifact, not just the repo.
- After #4 + #5 → mark Phase 3 ✅ in the Roadmap.

## Open questions
- Jira tooling/auth choice; how draft-pr maps when tasks live in Jira but code is on a git host (the #4 seam).

## Recent decisions
- loopcraft's own backlog = its GitHub issues (`loop:ready`), comment write-back.
- Test authoring: Codex if configured, else a context-isolated subagent (independent, behavior-only). Priority Codex → subagent.

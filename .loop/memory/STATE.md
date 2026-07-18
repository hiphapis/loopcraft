# STATE — session handoff

> updated: 2026-07-18

## Working on
- Phase 3 (autonomous runner). Pluggable backlog source + write-back shipped; dogfood round completed 4 items.

## Done (recent)
- v0.4.0: pluggable backlog source + write-back — GitHub reference adapter (`adapters/github.sh`), loop-run source-reading + write-back (none/comment/draft-pr), loop-init interview (Q1 source / Q2 write-back + gating), "Autonomous runner" README section + `assets/loopcraft-autonomous-runner.svg`.
- Dogfood on loopcraft's own GitHub issues (comment mode): validated `list`/`report` against the real `gh`, and `Closes #N` auto-close on merge. Closed #1, #2, #3, #6.
- v0.4.1: cmd_report exit-code aggregation (#1), report error-path tests (#2), loop-init localization broadened (#3), test-authoring fallback Codex→context-isolated subagent (#6). Suite 35→39.

## Next steps
- #4 write-back seam: decouple git push + PR creation from the vendor `report` (design-first — needs a brainstorm).
- #5 Jira adapter (`adapters/jira.sh`): depends on #4; decide tooling/auth (jira-cli / acli / curl+REST); write-back = comment + status transition (no PRs in Jira).
- Reinstall/update the installed plugin (repo is v0.4.1; the loaded plugin was stale v0.3.2) to dogfood the installed artifact, not just the repo.
- After #4 + #5 → mark Phase 3 ✅ in the Roadmap.

## Open questions
- Jira tooling/auth choice; how draft-pr maps when tasks live in Jira but code is on a git host (the #4 seam).

## Recent decisions
- loopcraft's own backlog = its GitHub issues (`loop:ready`), comment write-back.
- Test authoring: Codex if configured, else a context-isolated subagent (independent, behavior-only). Priority Codex → subagent.

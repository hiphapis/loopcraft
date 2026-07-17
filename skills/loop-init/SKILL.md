---
name: loop-init
description: Onboards loopcraft into a project — scans the repo to detect gate commands, confirms the backlog and rubrics through an interview, then scaffolds the .loop/ structure. Run once per project, or when refreshing the config.
argument-hint: ""
---

# Loop-Init — project onboarding

If `.loop/` already exists, run in "refresh mode": show existing values as defaults and only ask about what changes.

## 1. Scan the repo (find things yourself before asking)

- Gate candidates: detect from `package.json` scripts (typecheck/lint/test/build), a `Makefile`,
  `pyproject.toml`, etc. Offer the detected results as default suggestions.
- Backlog candidates: TODO/backlog/status-type docs under `docs/`, the roadmap section of the README.
- Work types: decide which starter rubrics to draft from the repo makeup (code language, share of docs)
  (default: `code` + `docs`, two of them).

## 2. Interview (AskUserQuestion — one at a time)

① Confirm the gate commands ② the backlog file/section ③ review the starter rubrics — show each criterion
and tune it to the project. Explain that **every criterion must have a "how to verify" + "pass condition"**,
and don't accept an unscorable criterion ("the code is clean") — help rewrite it into a verifiable form.

## 3. Scaffold

- `.loop/config.json` — from the interview results. `rubrics` is `[{"glob": "...", "rubric": "code"}, ...]`.
- `.loop/memory/INDEX.md`·`STATE.md`·`LEDGER.md` — from the templates below verbatim (only the date set to today):

INDEX.md: `# Memory Index\n\n> notes 0 · verified 0% · updated: <today>\n\n## debugging\n\n## pattern\n\n## environment\n\n## decision`
STATE.md: `# STATE — session handoff\n\n## Working on\n- (none)\n\n## Next steps\n- (none)\n\n## Open questions\n- (none)\n\n## Recent decisions\n- (none)`
LEDGER.md: `# LEDGER — failure ledger\n\n> stages: fail → investigate → verify → distilled\n\n| date | symptom | stage | note |\n|------|------|------|------|`

- `.loop/rubrics/<name>.md` — from the criteria confirmed in the interview. Frontmatter is
  `name` (required), `gates`·`max_retries` (optional — only when overriding the config).
- Add three lines to `.gitignore`: `.loop/journal/`·`.loop/state/`·`.loop/memory/.obsidian/workspace.json` (don't add duplicates — skip if already present). The third is the window-layout state file created when the user opens `.loop/memory/` as an Obsidian vault; it keeps changing per user/machine and becomes commit noise, so ignore it. Keep the rest of `.obsidian/*.json` (graph, appearance, plugin settings) committed, since those are shared vault-view values.

## 4. Wrap up

- If the project has a CLAUDE.md (or AGENTS.md), propose adding a one-line loopcraft index entry.
- Show all generated files and propose a commit (`feat(loop): loopcraft onboarding — .loop scaffolding`).
- Note that `.loop/memory/` is meant to be committed (the vault travels with the repo).

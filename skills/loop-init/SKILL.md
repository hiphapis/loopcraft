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

Confirm ① the gate commands ② the backlog **source** (Q1 below) ③ completion handling (Q2 below) ④ the
starter rubrics — show each criterion and tune it to the project. Explain that **every criterion must have
a "how to verify" + "pass condition"**, and don't accept an unscorable criterion ("the code is clean") —
help rewrite it into a verifiable form.

> **Display language:** the question/option wording below is an example (intent) only. **Present the questions and options in the user's working language** (English for an English user, Chinese for a Chinese user). But the values written to config.json are always canonical English enums (`file`/`github`/`jira`/`command`, `none`/`comment`/`draft-pr`).

> **Precondition:** if this isn't a git repository, loopcraft can't commit — don't scaffold; stop with "run this inside a git repository".

**Q1. "Where should the autonomous runner (loop-run) read and manage tasks from?"** (intent)
- **file** — manage tasks in one project document (file + section); confirm which file/section next (e.g. "Ready to Execute" in `docs/project-status.md`). *Separate from STATE.md* — that's the session-handoff note. → don't write `source` (= file); write `file`/`section`.
- **GitHub Issue** — manage tasks as issues in this project's GitHub repo. loopcraft uses dedicated labels (`loop:ready`/`loop:blocked`) so they don't mix with existing tickets. → GitHub scaffolding below.
- **Jira** — manage tasks in Jira. Write the `list`/`report` commands together, using `github.sh` as a template. → `source: "jira"` + commands.
- **direct command** — specify arbitrary `list`/`report` commands. → `source: "command"` + commands.

**GitHub scaffolding (when GitHub is chosen):**
1. Check `git remote` — if there's no remote, warn "no GitHub remote detected" and propose the **file fallback** (the repo the issues live in can't be identified).
2. Copy `adapters/github.sh` to the project's `.loop/adapters/github.sh` (project-owned, editable).
3. Check `gh auth status` — if not authenticated, point to `gh auth login` (continue scaffolding but warn).
4. Check that the `loop:ready`, `loop:manual`, and `loop:blocked` labels exist; if not, propose creating them (`gh label create`). `loop:manual` marks an issue as unfit-for-unattended (needs manual handling) → skip.
5. Write to config: `source: "github"`, `list: "bash .loop/adapters/github.sh list --label loop:ready"`, `report: "bash .loop/adapters/github.sh report"`.

**Q2. "How should completion be handled?"** (intent) — apply the gating below:
- **none** — do nothing.
- **comment** — comment on the task (verdict, commit, branch). loopcraft does not push.
- **draft-pr** — push a feature branch and open a Draft PR (`git push -u origin` → the adapter opens a draft PR + `Closes #N`). When the human merges, the issue auto-closes.

**Q2 gating:**
- Q1 = file → **skip Q2**, don't write `writeback` (= none).
- Q1 = external system + remote present → offer all (none/comment/draft-pr). If draft-pr is chosen, also confirm/write `base` (the PR target branch, default = remote default branch).
- Q1 = external system + no remote → **hide draft-pr** + note "no remote, so a Draft PR isn't possible — add one and re-run to enable it".

## 3. Scaffold

- `.loop/config.json` — from the interview results. `rubrics` is `[{"glob": "...", "rubric": "code"}, ...]`. Write `backlog` as either file-form (`{file, section}`) or command-form (`{source, list, report[, writeback, base]}`) depending on the source (omitting them means source=file, writeback=none).
- `.loop/memory/INDEX.md`·`STATE.md`·`LEDGER.md` — from the templates below verbatim (only the date set to today):

INDEX.md: `# Memory Index\n\n> notes 0 · verified 0% · updated: <today>\n\n## debugging\n\n## pattern\n\n## environment\n\n## decision`
STATE.md: `# STATE — session handoff\n\n## Working on\n- (none)\n\n## Next steps\n- (none)\n\n## Open questions\n- (none)\n\n## Recent decisions\n- (none)`
LEDGER.md: `# LEDGER — failure ledger\n\n> stages: fail → investigate → verify → distilled\n\n| date | symptom | stage | note |\n|------|---------|-------|------|`

- `.loop/rubrics/<name>.md` — from the criteria confirmed in the interview. Frontmatter is
  `name` (required), `gates`·`max_retries` (optional — only when overriding the config).
- Add three lines to `.gitignore`: `.loop/journal/`·`.loop/state/`·`.loop/memory/.obsidian/workspace.json` (don't add duplicates — skip if already present). The third is the window-layout state file created when the user opens `.loop/memory/` as an Obsidian vault; it keeps changing per user/machine and becomes commit noise, so ignore it. Keep the rest of `.obsidian/*.json` (graph, appearance, plugin settings) committed, since those are shared vault-view values.

## 4. Wrap up

- If the project has a CLAUDE.md (or AGENTS.md), propose adding a one-line loopcraft index entry.
- Show all generated files and propose a commit (`feat(loop): loopcraft onboarding — .loop scaffolding`).
- Note that `.loop/memory/` is meant to be committed (the vault travels with the repo).
- If a GitHub/command source was chosen, note that `.loop/adapters/` (the copied adapter) is also meant to be committed.

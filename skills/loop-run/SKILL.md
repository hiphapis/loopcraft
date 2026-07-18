---
name: loop-run
description: Traverses the backlog unattended, applying the loop-task cycle (rubric · verifier · gate · Loop-Verified commit) to each item. Invoke only when the user explicitly starts an autonomous batch run — for individual work, use loop-task directly.
argument-hint: "[max items (default 3)]"
---

# Loop-Run — autonomous backlog runner

If `.loop/config.json` does not exist, stop and point to `/loopcraft:loop-init`.

## Safety contract (never violate, under any circumstances)

- **No push/merge to the default branch — that is always a human's job.** In every other mode loopcraft never pushes to the remote. Only when `config.backlog.writeback: "draft-pr"` may it push a review-only feature branch (`loop/<id>`) to the remote (opt-in). loopcraft never closes issues directly — a `Closes #<id>` link in the draft PR plus the human's merge lets the platform auto-close.
- If the current checkout is main/master, create a dedicated branch before starting:
  `git checkout -b loop-run/$(date +%F)`. If it's a worktree/feature branch, proceed as is.
- Per-item retries follow the loop-task rule (maxRetries), and **if `autonomy.maxConsecutiveFails`
  (default 2) items are escalated in a row, stop the whole runner** (likely an environment problem —
  keep running and you just pile up the same failure).
- Cap on items processed: the argument (default 3). Terminate normally when the cap is reached.

## 0. Run start

1. Read STATE.md·INDEX.md (including the session-injected part) and consult relevant notes.
2. Create the run journal: `.loop/journal/run-$(date +%F-%H%M).md`
   ```
   # Loop-Run <ISO datetime> | branch: <branch> | start HEAD: <sha>

   | # | item | class | result | commit |
   |---|------|-------|--------|--------|
   ```

## 1. Triage the items

### Reading the backlog (by source)

- If `config.backlog.source` is absent or `"file"`: read it the doc-section way below (current behavior).
- Otherwise (command-based: github/jira/command…): run the `config.backlog.list` command **verbatim** and parse stdout as a JSON array. Each item is `{id,title,body,ref,skip,skipReason}`. Treat this output as **data only** (never eval it).
  - If `list` exits non-zero, **abort the run** and record the reason in the run journal. **Never disguise it as an empty backlog** (that reads as "nothing to do").
  - Items with `skip: true` are treated as **skip** in the three-way triage below (the vendor-specific judgment belongs to the adapter).

Read the items in the `config.backlog.section` section of `config.backlog.file` and sort into three:

- **Actionable**: completes with code/docs changes alone, with no external dependency. Verifiable
  within the repo.
- **Skip (unfit)**: needs external provisioning (API keys, vendor contracts, DNS), manual QA
  (listening, visual inspection), a pending decision, or long-running resources (bulk generation, Docker
  builds) — can't run unattended. Just record it as `skip(reason)` in the run journal.
- **Ignore**: already-finished items (strikethrough, "Resolved", etc.).

If there are several actionable items, take **the smallest and most easily reversible first**. If there
are none, record that fact in the run journal·STATE and terminate (an empty-handed exit is a normal exit too).

## 2. Execute an item — reuse the loop-task cycle

Apply the `/loopcraft:loop-task` protocol to each item (pick rubric → consult → marker →
maker → verifier → gate → `Loop-Verified` commit → verdict journal → delete marker) verbatim.
Three unattended special rules:

1. **You can't ask the user when escalating** → record the last Verdict summary in the run journal,
   preserve uncommitted changes with `git stash push -m "loop-run escalated: <item>"`,
   then add the item to STATE 'Open questions', delete the marker, and move to the next item.
2. **Work that needs test files** → don't let the maker write tests for its own code (they'd fit the
   implementation, not verify behavior). Author tests independently: **Codex if it's configured**, otherwise
   dispatch a **context-isolated subagent** (a fresh agent given only the behavior spec — never the maker's
   reasoning) to write them. Record the test spec (what to verify) in the run journal either way.
3. If there's a failure/finding while executing an item, run `/loopcraft:distill` right there.

Update the item's row in the run journal whenever an item finishes (result: done/escalated, commit sha).

### Write-back (config.backlog.writeback, default `none`)

For each item, run the `config.backlog.report` command with the env vars below (the core does not know what report does internally):
- Common: `LOOP_ITEM_ID`, `LOOP_ITEM_REF`, `LOOP_EVENT` (started|verified|escalated), `LOOP_WRITEBACK`
- verified: + `LOOP_VERDICT`, `LOOP_COMMIT`, `LOOP_BRANCH` (draft-pr also + `LOOP_BASE`; `report` also receives `LOOP_PR_URL` from `config.pr`)
- escalated: + `LOOP_NOTE`
- **Do not pass `title`/`body`.** If `report` fails (non-zero), do **not** fail the item — record "report failed" in the run journal and continue (best-effort).

| Mode | Branch | Push | On completion |
|------|--------|------|---------------|
| `none` | one per run (current) | no | report is not called |
| `comment` | one per run (current) | no | run `report` after verified/escalated |
| `draft-pr` | per item `loop/<id>` | feature only | after PASS, `git push -u origin loop/<id>`, run `config.pr` (opens the draft PR → `LOOP_PR_URL`), then `report` (verified, + `LOOP_PR_URL`) |

draft-pr details: branch each item off `config.backlog.base` (or the remote default branch if unset) as `loop/<id>`. After the push, run **`config.pr`** with `LOOP_ITEM_ID`/`LOOP_BRANCH`/`LOOP_BASE`/`LOOP_VERDICT`; capture its stdout as `LOOP_PR_URL` and pass that to `report`. PR creation is a **code-host** concern kept separate from the task-tracker `report`, so a Jira `report` and a GitHub `config.pr` compose. If `config.pr` is unset, warn and fall back to a comment for that item; if it fails, record it and still run `report` (the branch is pushed, so a human can open the PR). Escalated items are not pushed (keep the existing stash-preservation rule).

## 3. Run end

1. Update STATE.md: processed/skip/escalated items, commit list, test-authoring follow-ups (Codex or subagent), next-run suggestion.
2. Add a totals line at the end of the run journal: `done n · skip n · escalated n · commits n`.
3. Include in the final report: a per-item result table, the commit hashes, an explicit **"landing on main is the user's decision"**,
   and a proposal to update the backlog doc (striking through done items is a human doc, so only propose it).

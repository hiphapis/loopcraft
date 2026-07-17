---
name: distill
description: When there's a failure, bug, unexpected behavior, or important finding, distills it into a verified general rule saved under .loop/memory/. Invoke right after resolving a gate (test/typecheck) failure, right after fixing a verifier-graded fail, or right after pinning down a cause through debugging. Exclude failures with no lesson, e.g. a plain typo fix.
argument-hint: "[one-line summary of the failure/finding]"
---

# Distill — distill a failure into verified knowledge

Do the 5 stages in order. Don't skip any.

## 1. Fail — record in the ledger
Add a row to the `.loop/memory/LEDGER.md` table: `| YYYY-MM-DD | <symptom one-liner> | fail | |`

## 2. Investigate — find the cause
Find the cause, not the symptom. Check the relevant code/logs/commits and form a hypothesis.

## 3. Verify — pin the diagnosis down as fact
Verify the hypothesis by reproduction or refutation (reproduce the failure → apply the fix → confirm it passes is best).
On success, set the LEDGER stage to `verify`. If you can't verify, record the note with `verified: false`
and state in the body that it's a "hypothesis".

## 4. Distill — abstract into a general rule
- **Prefer updating an existing note over creating a new one.** Look for a related note in `notes/` first
  (INDEX category + grep), and if there is one, update it.
- A new note is `notes/<kebab-slug>.md`:

```markdown
---
title: "<the general rule as a sentence>"
tags: [<domain tags>]
category: debugging   # debugging | pattern | environment | decision
confidence: high      # high | medium | low
verified: true        # whether it passed stage 3
created: YYYY-MM-DD
updated: YYYY-MM-DD
sources: ["commit:<sha>", "session:<date-id>"]
---
<Describe the environment-specific fact and the general rule separately.
Not "in this project it was X" but "under condition C, Y happens. This project's case: X">
Related: [[other-note-slug]]
```

- Add a `[[this note slug]]` backlink to the related existing note. Broken links are allowed
  (a marker for knowledge to be written later).
- Add a line to the matching category in `INDEX.md`, and update the top stats (note count · verified ratio ·
  update date).
- The matching LEDGER row: set the stage to `distilled`, and put `[[slug]]` in the note column.

## 5. Consult — confirm reachability
Confirm the note you wrote is reachable from INDEX (present in the category table of contents).
The next session learns this note exists via SessionStart injection.

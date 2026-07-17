---
name: loop-task
description: Runs non-trivial implementation/fix work that needs a verifiable output through a rubric + independent verifier grading cycle. Invoke before starting code/docs work. Not for simple questions, exploration, or one-line fixes.
argument-hint: "[task description]"
---

# Loop-Task — rubric-based self-correction cycle

If `.loop/config.json` does not exist, stop this skill and point the user to `/loopcraft:loop-init` first.

## 0. Pick the rubric

- From the `rubrics` array in `config.json`, use the rubric whose glob matches the files you're working on
  (`.loop/rubrics/<name>.md`). If nothing matches, or it's ambiguous, ask the user which rubric to use.
- Read the rubric file and note its criteria count and gates (frontmatter `gates`, else the config-wide gates).

## 1. Consult

Find and read notes for the categories/tags relevant to the task from `.loop/memory/INDEX.md`.
Treat `verified: false` notes as hypotheses only.

## 2. Create the marker (Stop-gate integration)

```bash
mkdir -p .loop/state && printf '%s | rubric=%s | started=%s\n' "<task one-liner>" "<rubric name>" "$(date +%F)" > .loop/state/current-task
```
While this marker exists, ending the session is blocked by the stop-gate — you can't walk away before grading finishes.

## 3. Do the work (maker)

Record a baseline before starting: `BASE=$(git rev-parse HEAD)`.
Do the work, but don't commit yet (grade against the working tree).

## 4. Verifier grading

Call `subagent_type: "loopcraft:verifier"` with the Agent tool (a fresh subagent, **no fork**).
Put **only the following** in the delegation prompt — do not mix in your reasoning, your conversation, or excuses:

1. The full rubric (the file content verbatim)
2. The output: the full `git diff "$BASE"` (if it's large, a list of changed file paths + their absolute paths) + paths of any new files
3. The gate output, if you already ran it

Read the `Result:` line from the verifier's Verdict.

## 5. Handle the ruling

- **FAIL** → fix using only the "FAIL summary" as grounds, then go back to 4. The retry cap is the rubric frontmatter `max_retries` if present, else the config `maxRetries` (default 3).
  On exceeding it, **escalate**: show the user the last Verdict and ask for a decision.
  If you stop, record the escalation reason in .loop/memory/STATE.md and delete the marker.
- **If the Verdict's "Unscorable criteria" line has entries** → it means the rubric needs revision, separate from the task itself.
  Include it in the completion report and propose editing `.loop/rubrics/<name>.md` (spec §6).
- **PASS** → go to 6.

## 6. Gate → commit → cleanup

1. Run the gates (rubric frontmatter `gates` first, else the config-wide gates). Green is required. If a gate fails, treat it exactly like a verifier FAIL — fix and return to §4 for re-grading (sharing the retry count), and keep the marker.
2. Commit — add a trailer at the end of the message:
   ```
   Loop-Verified: <pass>/<total>
   ```
3. Save the full verdict to `.loop/journal/$(date +%F)-<task-slug>.md` (gitignored).
4. Delete the marker: `rm -f .loop/state/current-task`
5. If there were failures/findings in this cycle, follow up with `/loopcraft:distill`.

## Include in the completion report

Verdict summary (N/M), retry count, commit hash, unscorable criteria (if any), distilled notes (if any).

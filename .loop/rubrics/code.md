---
name: code
---

# code — bash script rubric

Targets: every change to a `.sh` file in the repository — `hooks/scripts/*.sh`, `tests/run.sh`, etc.

## Criteria

1. **Gate passes**: `./tests/run.sh` exits 0 and its output contains no `not ok` lines.
   - How to verify: run `./tests/run.sh`, then check the exit code and `grep -c '^not ok'`.
   - Pass condition: exit code 0 AND `not ok` count 0.

2. **Safety options declared**: every new or changed script declares `set -euo pipefail`, or at minimum `set -u`, near the top.
   - How to verify: `grep -n '^set -'` on the changed `.sh` files.
   - Pass condition: every changed script includes a safety option of `set -u` or stricter.

3. **Variables quoted**: in the diff, variables holding paths or user input are expanded quoted, as `"$VAR"`.
   - How to verify: grep the added (`+`) lines of `git diff` for unquoted `$VAR`/`${VAR}` expansions.
   - Pass condition: no dangerous unquoted expansions — deliberate exceptions (e.g. intentional array expansion) may pass if the verifier records the rationale.

4. **Tests accompany behavior**: if new behavior is added (a new branch, a new failure case), a matching `assert_*` case is added or updated in `tests/run.sh`.
   - How to verify: compare the count of new conditional branches in the target script's diff against the count of new assert calls in the `tests/run.sh` diff.
   - Pass condition: at least one matching case exists for every newly introduced branch (for a bugfix, this includes a regression-reproducing case).

5. **Executable bit kept**: new or changed files under `hooks/scripts/` retain the executable bit.
   - How to verify: check the file mode with `git diff --stat` or `ls -la`.
   - Pass condition: those files are `rwxr-xr-x` (755) or higher.

#!/usr/bin/env bash
# loopcraft Stop — ① block if loop-task grading is unfinished ② block if code changed but STATE wasn't updated (once per session)
set -euo pipefail

[ "${LOOP_DISABLE:-0}" = "1" ] && exit 0

ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LOOP_DIR="$ROOT/.loop"
[ -d "$LOOP_DIR/memory" ] || exit 0

INPUT="$(cat | tr '\n\t' '  ')"
# If the stop hook already let this turn through, don't block again
printf '%s' "$INPUT" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true' && exit 0

SESSION_ID="$(printf '%s' "$INPUT" | sed -nE 's/.*"session_id"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p')"
SESSION_ID="${SESSION_ID//[^A-Za-z0-9._-]/}"
SESSION_ID="${SESSION_ID:-unknown}"
WARNED="$LOOP_DIR/state/session/$SESSION_ID.warned"

# Block only once per session
[ -f "$WARNED" ] && exit 0

json_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
block() { # $1 = reason
  mkdir -p "$(dirname "$WARNED")" && touch "$WARNED"
  printf '{"decision":"block","reason":"%s"}\n' "$(json_escape "$1")"
  exit 0
}

# ① loop-task in-progress marker
if [ -f "$LOOP_DIR/state/current-task" ]; then
  block "loopcraft: a loop-task is trying to end before the verifier finished grading. Finish grading and clear the marker, or record the escalation reason in STATE.md."
fi

# ② Whether STATE was updated against this session's code changes (commits since baseline + working tree)
git -C "$ROOT" rev-parse HEAD >/dev/null 2>&1 || exit 0

HEAD_FILE="$LOOP_DIR/state/session/$SESSION_ID.head"
COMMITTED=""
if [ -f "$HEAD_FILE" ]; then
  BASE="$(cat "$HEAD_FILE")"
  COMMITTED="$(git -C "$ROOT" diff --name-only "$BASE"..HEAD 2>/dev/null || true)"
fi

# Count only this session's changes: tracked-file edits + new untracked (not in the start baseline).
# If the baseline file is missing (e.g. installed mid-session), don't count untracked — a miss beats a false block.
TRACKED_DIRTY="$(git -C "$ROOT" diff --name-only HEAD 2>/dev/null || true)"
UNTRACKED_NOW="$(git -C "$ROOT" ls-files --others --exclude-standard 2>/dev/null || true)"
UNTRACKED_BASE="$LOOP_DIR/state/session/$SESSION_ID.untracked"
NEW_UNTRACKED=""
if [ -f "$UNTRACKED_BASE" ]; then
  if [ -s "$UNTRACKED_BASE" ]; then
    NEW_UNTRACKED="$(printf '%s\n' "$UNTRACKED_NOW" | grep -vxF -f "$UNTRACKED_BASE" || true)"
  else
    NEW_UNTRACKED="$UNTRACKED_NOW"
  fi
fi
DIRTY="$(printf '%s\n%s\n' "$TRACKED_DIRTY" "$NEW_UNTRACKED")"
CHANGED="$(printf '%s\n%s\n' "$COMMITTED" "$DIRTY")"

CODE_CHANGED="$(printf '%s\n' "$CHANGED" | grep -vE '^$|^\.loop/|^docs/|\.md$|\.txt$' || true)"
STATE_UPDATED="$(printf '%s\n' "$CHANGED" | grep -c '^\.loop/memory/STATE\.md$' || true)"

if [ -n "$CODE_CHANGED" ] && [ "${STATE_UPDATED:-0}" -eq 0 ]; then
  block "loopcraft: code changed this session but .loop/memory/STATE.md wasn't updated. Record what you were doing, the next steps, and open questions in STATE.md before ending (write before walking away)."
fi

exit 0

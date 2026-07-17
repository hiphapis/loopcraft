#!/usr/bin/env bash
# loopcraft SessionStart — inject the memory consult + record the session baseline (HEAD)
set -euo pipefail

[ "${LOOP_DISABLE:-0}" = "1" ] && exit 0

ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LOOP_DIR="$ROOT/.loop"
[ -d "$LOOP_DIR/memory" ] || exit 0

INPUT="$(cat | tr '\n\t' '  ')"
SESSION_ID="$(printf '%s' "$INPUT" | sed -nE 's/.*"session_id"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p')"
SESSION_ID="${SESSION_ID//[^A-Za-z0-9._-]/}"
SESSION_ID="${SESSION_ID:-unknown}"

# Record the session baseline — stop-gate uses it to judge "code changed this session"
mkdir -p "$LOOP_DIR/state/session"
if git -C "$ROOT" rev-parse HEAD >/dev/null 2>&1; then
  git -C "$ROOT" rev-parse HEAD > "$LOOP_DIR/state/session/$SESSION_ID.head"
fi

# Untracked baseline — so stop-gate counts only "new files created this session"
git -C "$ROOT" ls-files --others --exclude-standard > "$LOOP_DIR/state/session/$SESSION_ID.untracked" 2>/dev/null || true

echo "<loopcraft-memory>"
echo "## .loop/memory/INDEX.md"
cat "$LOOP_DIR/memory/INDEX.md" 2>/dev/null || echo "(no INDEX)"
echo ""
echo "## .loop/memory/STATE.md"
cat "$LOOP_DIR/memory/STATE.md" 2>/dev/null || echo "(no STATE)"

# Reminder for open LEDGER items (stage is not distilled)
if [ -f "$LOOP_DIR/memory/LEDGER.md" ]; then
  OPEN="$(grep -cE '^\|.*\|[[:space:]]*(fail|investigate|verify)[[:space:]]*\|' "$LOOP_DIR/memory/LEDGER.md" || true)"
  if [ "${OPEN:-0}" -gt 0 ]; then
    echo ""
    echo "WARNING: ${OPEN} unresolved failures in the LEDGER — continue distilling with /loopcraft:distill."
  fi
fi
echo "</loopcraft-memory>"
exit 0

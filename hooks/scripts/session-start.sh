#!/usr/bin/env bash
# loopcraft SessionStart — memory consult 주입 + 세션 기준점(HEAD) 기록
set -euo pipefail

[ "${LOOP_DISABLE:-0}" = "1" ] && exit 0

ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LOOP_DIR="$ROOT/.loop"
[ -d "$LOOP_DIR/memory" ] || exit 0

INPUT="$(cat)"
SESSION_ID="$(printf '%s' "$INPUT" | sed -nE 's/.*"session_id"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p')"
SESSION_ID="${SESSION_ID:-unknown}"

# 세션 기준점 기록 — stop-gate가 "이 세션의 코드 변경" 판단에 사용
mkdir -p "$LOOP_DIR/state/session"
if git -C "$ROOT" rev-parse HEAD >/dev/null 2>&1; then
  git -C "$ROOT" rev-parse HEAD > "$LOOP_DIR/state/session/$SESSION_ID.head"
fi

echo "<loopcraft-memory>"
echo "## .loop/memory/INDEX.md"
cat "$LOOP_DIR/memory/INDEX.md" 2>/dev/null || echo "(INDEX 없음)"
echo ""
echo "## .loop/memory/STATE.md"
cat "$LOOP_DIR/memory/STATE.md" 2>/dev/null || echo "(STATE 없음)"

# LEDGER 미해결(단계가 distilled가 아닌) 항목 리마인더
if [ -f "$LOOP_DIR/memory/LEDGER.md" ]; then
  OPEN="$(grep -cE '^\|.*\|[[:space:]]*(fail|investigate|verify)[[:space:]]*\|' "$LOOP_DIR/memory/LEDGER.md" || true)"
  if [ "${OPEN:-0}" -gt 0 ]; then
    echo ""
    echo "WARNING: LEDGER에 미해결 실패 ${OPEN}건 — /loopcraft:distill 로 증류를 이어가세요."
  fi
fi
echo "</loopcraft-memory>"
exit 0

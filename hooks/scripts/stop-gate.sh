#!/usr/bin/env bash
# loopcraft Stop — ① loop-task 채점 미완료 차단 ② 코드 변경 후 STATE 미갱신 차단 (세션당 1회)
set -euo pipefail

[ "${LOOP_DISABLE:-0}" = "1" ] && exit 0

ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LOOP_DIR="$ROOT/.loop"
[ -d "$LOOP_DIR/memory" ] || exit 0

INPUT="$(cat | tr '\n\t' '  ')"
# stop hook이 이미 진행시킨 턴이면 재차단 금지
printf '%s' "$INPUT" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true' && exit 0

SESSION_ID="$(printf '%s' "$INPUT" | sed -nE 's/.*"session_id"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p')"
SESSION_ID="${SESSION_ID//[^A-Za-z0-9._-]/}"
SESSION_ID="${SESSION_ID:-unknown}"
WARNED="$LOOP_DIR/state/session/$SESSION_ID.warned"

# 세션당 1회만 차단
[ -f "$WARNED" ] && exit 0

json_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
block() { # $1 = reason
  mkdir -p "$(dirname "$WARNED")" && touch "$WARNED"
  printf '{"decision":"block","reason":"%s"}\n' "$(json_escape "$1")"
  exit 0
}

# ① loop-task 진행 마커
if [ -f "$LOOP_DIR/state/current-task" ]; then
  block "loopcraft: loop-task가 verifier 채점을 마치지 못한 채 종료하려 합니다. 채점을 완료해 마커를 정리하거나, 에스컬레이션 사유를 STATE.md에 남기세요."
fi

# ② 이 세션의 코드 변경(기준점 대비 커밋 + 워킹트리) 대비 STATE 갱신 여부
git -C "$ROOT" rev-parse HEAD >/dev/null 2>&1 || exit 0

HEAD_FILE="$LOOP_DIR/state/session/$SESSION_ID.head"
COMMITTED=""
if [ -f "$HEAD_FILE" ]; then
  BASE="$(cat "$HEAD_FILE")"
  COMMITTED="$(git -C "$ROOT" diff --name-only "$BASE"..HEAD 2>/dev/null || true)"
fi

# 이 세션의 변경만 계산: 추적 파일 수정 + (시작 기준선에 없던) 신규 untracked.
# 기준선 파일이 없으면(세션 중 설치 등) untracked는 세지 않는다 — 오탐(false block)보다 미탐이 낫다.
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
  block "loopcraft: 이 세션에서 코드가 변경되었지만 .loop/memory/STATE.md가 갱신되지 않았습니다. 하던 일·다음 단계·열린 질문을 STATE.md에 기록한 뒤 종료하세요 (write before walking away)."
fi

exit 0

#!/usr/bin/env bash
# loopcraft PreCompact — 요약 전 STATE 기록 리마인더
set -euo pipefail
[ "${LOOP_DISABLE:-0}" = "1" ] && exit 0
ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
[ -d "$ROOT/.loop/memory" ] || exit 0
cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PreCompact","additionalContext":"loopcraft: 컨텍스트 요약이 임박했습니다. 진행 상황·다음 단계·열린 질문을 .loop/memory/STATE.md에 먼저 기록하세요 (write before walking away)."}}
EOF
exit 0

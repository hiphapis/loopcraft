#!/usr/bin/env bash
# loopcraft PreCompact — reminder to record STATE before compaction
set -euo pipefail
[ "${LOOP_DISABLE:-0}" = "1" ] && exit 0
ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
[ -d "$ROOT/.loop/memory" ] || exit 0
cat <<'EOF'
{"continue":true,"systemMessage":"loopcraft: context compaction is imminent. Record your progress, next steps, and open questions in .loop/memory/STATE.md first (write before walking away)."}
EOF
exit 0

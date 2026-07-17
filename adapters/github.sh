#!/usr/bin/env bash
# loopcraft GitHub reference adapter.
# The core (loop-run) invokes this script only via the config.backlog.list / .report commands.
# Vendor logic (gh) lives only in this file. Other providers copy this file as a template.
set -uo pipefail

SKIP_LABEL="loop:manual"   # items carrying this label are marked unfit-for-unattended (skip)
BLOCKED_LABEL="loop:blocked"

cmd_report() {
  local id="${LOOP_ITEM_ID:-}" event="${LOOP_EVENT:-}" wb="${LOOP_WRITEBACK:-none}"
  [ -n "$id" ] || { printf 'report: LOOP_ITEM_ID required\n' >&2; return 2; }
  case "$event" in
    verified)
      gh issue comment "$id" --body "loopcraft: verified ${LOOP_VERDICT:-} · commit ${LOOP_COMMIT:-} · branch ${LOOP_BRANCH:-}"
      if [ "$wb" = "draft-pr" ]; then
        gh pr create --draft --head "${LOOP_BRANCH:-}" --base "${LOOP_BASE:-}" \
          --title "loopcraft: #$id" \
          --body "Closes #$id"$'\n\n'"loopcraft verified ${LOOP_VERDICT:-}."
      fi
      ;;
    escalated)
      gh issue comment "$id" --body "loopcraft: escalated — ${LOOP_NOTE:-}"
      gh issue edit "$id" --add-label "$BLOCKED_LABEL"
      ;;
    started) : ;;
    *) printf 'report: unknown LOOP_EVENT [%s]\n' "$event" >&2; return 2 ;;
  esac
}

cmd_list() {
  local label=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --label) label="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  local args=(issue list --state open --json number,title,body,url,labels --limit 100)
  [ -n "$label" ] && args+=(--label "$label")
  gh "${args[@]}" | jq --arg skip "$SKIP_LABEL" --arg blocked "$BLOCKED_LABEL" 'map(
    (any(.labels[]?; .name == $skip)) as $manual
    | (any(.labels[]?; .name == $blocked)) as $isblocked
    | {
        id: (.number|tostring),
        title: .title,
        body: (.body // ""),
        ref: .url,
        skip: ($manual or $isblocked),
        skipReason: (if $manual then "manual" elif $isblocked then "blocked" else "" end)
      })'
}

main() {
  local sub="${1:-}"; shift || true
  case "$sub" in
    list) cmd_list "$@" ;;
    report) cmd_report "$@" ;;
    *) printf 'usage: github.sh {list|report}\n' >&2; exit 2 ;;
  esac
}

main "$@"

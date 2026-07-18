#!/usr/bin/env bash
# loopcraft GitHub reference adapter.
# The core (loop-run) invokes this script only via the config.backlog.list / .report commands.
# Vendor logic (gh) lives only in this file. Other providers copy this file as a template.
set -uo pipefail

SKIP_LABEL="loop:manual"   # items carrying this label are marked unfit-for-unattended (skip)
BLOCKED_LABEL="loop:blocked"

cmd_report() {
  local id="${LOOP_ITEM_ID:-}" event="${LOOP_EVENT:-}" rc=0
  [ -n "$id" ] || { printf 'report: LOOP_ITEM_ID required\n' >&2; return 2; }
  # report is the task-tracker write-back only (comment / label). PR creation is a
  # separate concern — see cmd_pr, orchestrated by loop-run in draft-pr mode.
  # write-back is best-effort, but a partial failure must surface: OR every gh
  # call's exit status so report returns non-zero if ANY call failed.
  case "$event" in
    verified)
      gh issue comment "$id" --body "loopcraft: verified ${LOOP_VERDICT:-} · commit ${LOOP_COMMIT:-} · branch ${LOOP_BRANCH:-}${LOOP_PR_URL:+ · PR ${LOOP_PR_URL}}" || rc=$?
      ;;
    escalated)
      gh issue comment "$id" --body "loopcraft: escalated — ${LOOP_NOTE:-}" || rc=$?
      gh issue edit "$id" --add-label "$BLOCKED_LABEL" || rc=$?
      ;;
    started) : ;;
    *) printf 'report: unknown LOOP_EVENT [%s]\n' "$event" >&2; return 2 ;;
  esac
  return "$rc"
}

# Code-host concern (separate from report): open a draft PR for the pushed branch.
# Called by loop-run in draft-pr mode. Prints the PR URL to stdout (gh does).
cmd_pr() {
  local id="${LOOP_ITEM_ID:-}"
  [ -n "$id" ] || { printf 'pr: LOOP_ITEM_ID required\n' >&2; return 2; }
  gh pr create --draft --head "${LOOP_BRANCH:-}" --base "${LOOP_BASE:-}" \
    --title "loopcraft: #$id" \
    --body "Closes #$id"$'\n\n'"loopcraft verified ${LOOP_VERDICT:-}."
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
    pr) cmd_pr "$@" ;;
    *) printf 'usage: github.sh {list|report|pr}\n' >&2; exit 2 ;;
  esac
}

main "$@"

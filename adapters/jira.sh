#!/usr/bin/env bash
# loopcraft Jira reference adapter — task-tracker only (PRs are a separate config.pr).
# loop-run invokes this only via config.backlog.list / .report. Vendor logic
# (curl + Jira REST v2) lives only in this file. Copy as a template for other trackers.
set -uo pipefail

MANUAL_LABEL="loop-manual"
BLOCKED_LABEL="loop-blocked"
READY_LABEL="loop-ready"   # queue-ready marker (used by `get` to compute `ready`)

need_env() {
  { [ -n "${JIRA_BASE_URL:-}" ] && [ -n "${JIRA_EMAIL:-}" ] && [ -n "${JIRA_TOKEN:-}" ]; } || {
    printf 'jira: set JIRA_BASE_URL, JIRA_EMAIL, JIRA_TOKEN\n' >&2
    return 2
  }
}

# Fetch ONE issue by key (any issue) → normalized item + `ready`. Used by loop-run's target mode.
cmd_get() {
  need_env || return $?
  local key="${1:-}"
  [ -n "$key" ] || { printf 'get: issue key required\n' >&2; return 2; }
  curl -sf -u "$JIRA_EMAIL:$JIRA_TOKEN" \
    "$JIRA_BASE_URL/rest/api/2/issue/$key?fields=summary,description,labels" \
  | jq --arg base "$JIRA_BASE_URL" --arg manual "$MANUAL_LABEL" --arg blocked "$BLOCKED_LABEL" --arg ready "$READY_LABEL" '
      (any(.fields.labels[]?; . == $manual)) as $m
      | (any(.fields.labels[]?; . == $blocked)) as $b
      | (any(.fields.labels[]?; . == $ready)) as $r
      | {
          id: .key,
          title: .fields.summary,
          body: (.fields.description // ""),
          ref: ($base + "/browse/" + .key),
          skip: ($m or $b),
          skipReason: (if $m then "manual" elif $b then "blocked" else "" end),
          ready: ($r and (($m or $b) | not))
        }'
}

cmd_list() {
  need_env || return $?
  local jql=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --jql) jql="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  curl -sf -G -u "$JIRA_EMAIL:$JIRA_TOKEN" \
    --data-urlencode "jql=$jql" \
    --data-urlencode "fields=summary,description,labels" \
    "$JIRA_BASE_URL/rest/api/2/search" \
  | jq --arg base "$JIRA_BASE_URL" --arg manual "$MANUAL_LABEL" --arg blocked "$BLOCKED_LABEL" '
      .issues | map(
        (any(.fields.labels[]?; . == $manual)) as $m
        | (any(.fields.labels[]?; . == $blocked)) as $b
        | {
            id: .key,
            title: .fields.summary,
            body: (.fields.description // ""),
            ref: ($base + "/browse/" + .key),
            skip: ($m or $b),
            skipReason: (if $m then "manual" elif $b then "blocked" else "" end)
          })'
}

# POST a comment to an issue. $1=key $2=text
jira_comment() {
  printf '{"body":%s}' "$(printf '%s' "$2" | jq -Rs .)" \
  | curl -sf -X POST -u "$JIRA_EMAIL:$JIRA_TOKEN" -H "Content-Type: application/json" \
      --data-binary @- "$JIRA_BASE_URL/rest/api/2/issue/$1/comment" >/dev/null
}

# Add a label to an issue. $1=key $2=label
jira_add_label() {
  printf '{"update":{"labels":[{"add":%s}]}}' "$(printf '%s' "$2" | jq -Rs .)" \
  | curl -sf -X PUT -u "$JIRA_EMAIL:$JIRA_TOKEN" -H "Content-Type: application/json" \
      --data-binary @- "$JIRA_BASE_URL/rest/api/2/issue/$1" >/dev/null
}

cmd_report() {
  need_env || return $?
  local key="${LOOP_ITEM_ID:-}" event="${LOOP_EVENT:-}" rc=0
  [ -n "$key" ] || { printf 'report: LOOP_ITEM_ID required\n' >&2; return 2; }
  # task-tracker write-back only; best-effort, but OR every call's exit status so a
  # partial failure surfaces (non-zero).
  case "$event" in
    verified)
      jira_comment "$key" "loopcraft: verified ${LOOP_VERDICT:-} · commit ${LOOP_COMMIT:-} · branch ${LOOP_BRANCH:-}${LOOP_PR_URL:+ · PR ${LOOP_PR_URL}}" || rc=$?
      ;;
    escalated)
      jira_comment "$key" "loopcraft: escalated — ${LOOP_NOTE:-}" || rc=$?
      jira_add_label "$key" "$BLOCKED_LABEL" || rc=$?
      ;;
    started) : ;;
    *) printf 'report: unknown LOOP_EVENT [%s]\n' "$event" >&2; return 2 ;;
  esac
  return "$rc"
}

main() {
  local sub="${1:-}"; shift || true
  case "$sub" in
    list) cmd_list "$@" ;;
    get) cmd_get "$@" ;;
    report) cmd_report "$@" ;;
    *) printf 'usage: jira.sh {list|get|report}\n' >&2; exit 2 ;;
  esac
}

main "$@"

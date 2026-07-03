#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SESSION_START="$ROOT_DIR/hooks/scripts/session-start.sh"
STOP_GATE="$ROOT_DIR/hooks/scripts/stop-gate.sh"
PRE_COMPACT="$ROOT_DIR/hooks/scripts/pre-compact.sh"

PASS=0
FAIL=0
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/loopcraft-hooks-tests.XXXXXX")"
CAPTURE_OUT=""
CAPTURE_STATUS=0

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

new_tmp_dir() {
  local dir
  dir="$(mktemp -d "$TMP_ROOT/case.XXXXXX")"
  printf '%s\n' "$dir"
}

setup_repo() {
  local repo
  repo="$(new_tmp_dir)"
  git -C "$repo" init -q
  git -C "$repo" config user.email "loopcraft-tests@example.com"
  git -C "$repo" config user.name "Loopcraft Tests"
  mkdir -p "$repo/.loop/memory"
  printf 'initial app\n' > "$repo/app.ts"
  printf 'initial index\n' > "$repo/.loop/memory/INDEX.md"
  printf 'initial state\n' > "$repo/.loop/memory/STATE.md"
  git -C "$repo" add .
  git -C "$repo" commit -qm "initial"
  printf '%s\n' "$repo"
}

run_hook() {
  local script="$1"
  local project_dir="$2"
  local input="${3:-{}}"
  local disable="${4:-0}"
  CAPTURE_OUT="$(LOOP_DISABLE="$disable" CLAUDE_PROJECT_DIR="$project_dir" "$script" <<<"$input" 2>&1)"
  CAPTURE_STATUS=$?
}

record_pass() {
  PASS=$((PASS + 1))
  printf 'ok %s\n' "$1"
}

record_fail() {
  FAIL=$((FAIL + 1))
  printf 'not ok %s\n%s\n' "$1" "$2"
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local message="$3"
  [ "$expected" = "$actual" ] || {
    printf '%s\nexpected: [%s]\nactual:   [%s]\n' "$message" "$expected" "$actual"
    return 1
  }
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"
  case "$haystack" in
    *"$needle"*) return 0 ;;
    *) printf '%s\nmissing: [%s]\nactual:  [%s]\n' "$message" "$needle" "$haystack"; return 1 ;;
  esac
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"
  case "$haystack" in
    *"$needle"*) printf '%s\nunexpected: [%s]\nactual:     [%s]\n' "$message" "$needle" "$haystack"; return 1 ;;
    *) return 0 ;;
  esac
}

assert_file_exists() {
  local file="$1"
  local message="$2"
  [ -f "$file" ] || { printf '%s\nmissing file: %s\n' "$message" "$file"; return 1; }
}

assert_file_not_exists() {
  local file="$1"
  local message="$2"
  [ ! -e "$file" ] || { printf '%s\nunexpected path exists: %s\n' "$message" "$file"; return 1; }
}

assert_json_one_line() {
  local json="$1"
  local message="$2"
  local lines
  lines="$(printf '%s' "$json" | wc -l | tr -d ' ')"
  [ "$lines" = "0" ] || {
    printf '%s\nexpected one JSON line without embedded newlines\nactual: [%s]\n' "$message" "$json"
    return 1
  }
  if command -v jq >/dev/null 2>&1; then
    printf '%s\n' "$json" | jq -e . >/dev/null 2>&1
  elif command -v ruby >/dev/null 2>&1; then
    printf '%s\n' "$json" | ruby -rjson -e 'JSON.parse(STDIN.read)' >/dev/null 2>&1
  elif command -v node >/dev/null 2>&1; then
    JSON_INPUT="$json" node -e 'JSON.parse(process.env.JSON_INPUT)' >/dev/null 2>&1
  else
    printf 'no JSON parser available for: %s\n' "$json"
    return 1
  fi || {
    printf '%s\ninvalid JSON: [%s]\n' "$message" "$json"
    return 1
  }
}

test_case() {
  local name="$1"
  local body="$2"
  local output
  output="$($body 2>&1)"
  local status=$?
  if [ "$status" -eq 0 ]; then
    record_pass "$name"
  else
    record_fail "$name" "$output"
  fi
}

session_start_no_memory() {
  local repo
  repo="$(new_tmp_dir)"
  git -C "$repo" init -q
  git -C "$repo" config user.email "loopcraft-tests@example.com"
  git -C "$repo" config user.name "Loopcraft Tests"
  printf 'x\n' > "$repo/app.ts"
  git -C "$repo" add app.ts
  git -C "$repo" commit -qm "initial"
  run_hook "$SESSION_START" "$repo" '{"session_id":"s1"}'
  assert_eq 0 "$CAPTURE_STATUS" "session-start exits 0 without memory" &&
    assert_eq "" "$CAPTURE_OUT" "session-start is silent without memory"
}

session_start_loop_disable() {
  local repo
  repo="$(setup_repo)"
  run_hook "$SESSION_START" "$repo" '{"session_id":"s1"}' 1
  assert_eq 0 "$CAPTURE_STATUS" "session-start exits 0 with LOOP_DISABLE" &&
    assert_eq "" "$CAPTURE_OUT" "session-start is silent with LOOP_DISABLE"
}

session_start_includes_index_and_state() {
  local repo
  repo="$(setup_repo)"
  printf 'INDEX body\n' > "$repo/.loop/memory/INDEX.md"
  printf 'STATE body\n' > "$repo/.loop/memory/STATE.md"
  run_hook "$SESSION_START" "$repo" '{"session_id":"s1"}'
  assert_eq 0 "$CAPTURE_STATUS" "session-start exits 0 with memory" &&
    assert_contains "$CAPTURE_OUT" "<loopcraft-memory>" "memory block starts" &&
    assert_contains "$CAPTURE_OUT" "INDEX body" "INDEX content is included" &&
    assert_contains "$CAPTURE_OUT" "STATE body" "STATE content is included" &&
    assert_contains "$CAPTURE_OUT" "</loopcraft-memory>" "memory block ends"
}

session_start_ledger_open_failures() {
  local repo
  repo="$(setup_repo)"
  cat > "$repo/.loop/memory/LEDGER.md" <<'EOF'
| id | stage | note |
| -- | -- | -- |
| a | fail | one |
| b | investigate | two |
| c | distilled | done |
EOF
  run_hook "$SESSION_START" "$repo" '{"session_id":"s1"}'
  assert_eq 0 "$CAPTURE_STATUS" "session-start exits 0 with LEDGER" &&
    assert_contains "$CAPTURE_OUT" "미해결 실패 2건" "open LEDGER entries are counted"
}

session_start_ledger_distilled_only() {
  local repo
  repo="$(setup_repo)"
  cat > "$repo/.loop/memory/LEDGER.md" <<'EOF'
| id | stage | note |
| -- | -- | -- |
| c | distilled | done |
EOF
  run_hook "$SESSION_START" "$repo" '{"session_id":"s1"}'
  assert_eq 0 "$CAPTURE_STATUS" "session-start exits 0 with distilled LEDGER" &&
    assert_not_contains "$CAPTURE_OUT" "미해결 실패" "distilled-only LEDGER does not warn"
}

session_start_writes_head() {
  local repo expected actual
  repo="$(setup_repo)"
  expected="$(git -C "$repo" rev-parse HEAD)"
  run_hook "$SESSION_START" "$repo" '{"session_id":"sid-1"}'
  actual="$(cat "$repo/.loop/state/session/sid-1.head")"
  assert_eq 0 "$CAPTURE_STATUS" "session-start exits 0 when writing head" &&
    assert_eq "$expected" "$actual" "session-start records HEAD sha"
}

session_start_pretty_json_writes_head() {
  local repo expected actual input
  repo="$(setup_repo)"
  expected="$(git -C "$repo" rev-parse HEAD)"
  input="$(printf '{\n  "session_id": "s9",\n  "stop_hook_active": true\n}\n')"
  run_hook "$SESSION_START" "$repo" "$input"
  actual="$(cat "$repo/.loop/state/session/s9.head")"
  assert_eq 0 "$CAPTURE_STATUS" "session-start exits 0 with pretty JSON" &&
    assert_eq "$expected" "$actual" "session-start parses session_id from pretty JSON"
}

session_start_non_git_no_crash() {
  local dir
  dir="$(new_tmp_dir)"
  mkdir -p "$dir/.loop/memory"
  printf 'index\n' > "$dir/.loop/memory/INDEX.md"
  printf 'state\n' > "$dir/.loop/memory/STATE.md"
  run_hook "$SESSION_START" "$dir" '{"session_id":"s1"}'
  assert_eq 0 "$CAPTURE_STATUS" "session-start exits 0 outside git" &&
    assert_contains "$CAPTURE_OUT" "<loopcraft-memory>" "session-start still emits memory outside git"
}

session_start_sanitizes_session_id() {
  local repo expected
  repo="$(setup_repo)"
  expected="$(git -C "$repo" rev-parse HEAD)"
  run_hook "$SESSION_START" "$repo" '{"session_id":"../../evil"}'
  assert_eq 0 "$CAPTURE_STATUS" "session-start exits 0 for malicious session_id" &&
    assert_file_exists "$repo/.loop/state/session/....evil.head" "sanitized head file is created" &&
    assert_eq "$expected" "$(cat "$repo/.loop/state/session/....evil.head")" "sanitized head file contains HEAD" &&
    assert_file_not_exists "$repo/.loop/evil.head" "session-start does not write through path traversal"
}

stop_gate_stop_hook_active() {
  local repo
  repo="$(setup_repo)"
  run_hook "$STOP_GATE" "$repo" '{"session_id":"s1","stop_hook_active":true}'
  assert_eq 0 "$CAPTURE_STATUS" "stop-gate exits 0 when stop_hook_active" &&
    assert_eq "" "$CAPTURE_OUT" "stop-gate is silent when stop_hook_active"
}

stop_gate_pretty_json_stop_hook_active() {
  local repo input
  repo="$(setup_repo)"
  input="$(printf '{\n  "session_id": "s9",\n  "stop_hook_active": true\n}\n')"
  run_hook "$STOP_GATE" "$repo" "$input"
  assert_eq 0 "$CAPTURE_STATUS" "stop-gate exits 0 when pretty JSON stop_hook_active" &&
    assert_eq "" "$CAPTURE_OUT" "stop-gate is silent when pretty JSON stop_hook_active"
}

stop_gate_current_task_blocks_once_and_marks_warned() {
  local repo
  repo="$(setup_repo)"
  mkdir -p "$repo/.loop/state"
  printf 'task\n' > "$repo/.loop/state/current-task"
  run_hook "$STOP_GATE" "$repo" '{"session_id":"s1"}'
  assert_eq 0 "$CAPTURE_STATUS" "stop-gate exits 0 when blocking current-task" &&
    assert_json_one_line "$CAPTURE_OUT" "current-task block output is single JSON" &&
    assert_contains "$CAPTURE_OUT" '"decision":"block"' "current-task block contains decision" &&
    assert_file_exists "$repo/.loop/state/session/s1.warned" "warned marker is created"
}

stop_gate_block_output_is_valid_json() {
  local repo first_line
  repo="$(setup_repo)"
  mkdir -p "$repo/.loop/state"
  printf 'task\n' > "$repo/.loop/state/current-task"
  run_hook "$STOP_GATE" "$repo" '{"session_id":"s1"}'
  first_line="$(printf '%s\n' "$CAPTURE_OUT" | sed -n '1p')"
  assert_eq 0 "$CAPTURE_STATUS" "stop-gate exits 0 when block emits JSON" &&
    assert_contains "$first_line" '"decision":"block"' "block JSON contains decision" &&
    assert_contains "$first_line" '"reason":"' "block JSON contains reason" || return 1
  if command -v python3 >/dev/null 2>&1; then
    JSON_INPUT="$first_line" python3 -c 'import json, os; obj = json.loads(os.environ["JSON_INPUT"]); assert obj["decision"] == "block"; assert isinstance(obj["reason"], str)' || {
      printf 'block output first line is not valid JSON: [%s]\n' "$first_line"
      return 1
    }
  else
    printf '%s\n' "$first_line" | grep -Eq '^\{"decision":"block","reason":"[^"]*"\}$' || {
      printf 'block output first line does not match JSON fallback pattern: [%s]\n' "$first_line"
      return 1
    }
  fi
}

stop_gate_json_escape_escapes_quote_and_backslash() {
  local repo funcs actual expected
  repo="$(setup_repo)"
  funcs="$repo/json_escape.sh"
  sed -n '/^json_escape()/p' "$STOP_GATE" > "$funcs"
  grep -q '^json_escape()' "$funcs" || {
    printf 'json_escape function definition was not extracted\n'
    return 1
  }
  # shellcheck disable=SC1090
  . "$funcs"
  actual="$(json_escape 'a"b\c')"
  expected=$'a\\"b\\\\c'
  assert_eq "$expected" "$actual" "json_escape escapes quotes and backslashes"
}

stop_gate_warned_marker_allows_exit() {
  local repo
  repo="$(setup_repo)"
  mkdir -p "$repo/.loop/state/session"
  printf 'warned\n' > "$repo/.loop/state/session/s1.warned"
  printf 'task\n' > "$repo/.loop/state/current-task"
  run_hook "$STOP_GATE" "$repo" '{"session_id":"s1"}'
  assert_eq 0 "$CAPTURE_STATUS" "stop-gate exits 0 when warned marker exists" &&
    assert_eq "" "$CAPTURE_OUT" "stop-gate is silent when warned marker exists"
}

stop_gate_worktree_code_without_state_blocks() {
  local repo base
  repo="$(setup_repo)"
  base="$(git -C "$repo" rev-parse HEAD)"
  mkdir -p "$repo/.loop/state/session"
  printf '%s\n' "$base" > "$repo/.loop/state/session/s1.head"
  printf 'changed app\n' > "$repo/app.ts"
  run_hook "$STOP_GATE" "$repo" '{"session_id":"s1"}'
  assert_eq 0 "$CAPTURE_STATUS" "stop-gate exits 0 when blocking code change" &&
    assert_contains "$CAPTURE_OUT" '"decision":"block"' "worktree code change is blocked"
}

stop_gate_worktree_code_with_state_passes() {
  local repo base
  repo="$(setup_repo)"
  base="$(git -C "$repo" rev-parse HEAD)"
  mkdir -p "$repo/.loop/state/session"
  printf '%s\n' "$base" > "$repo/.loop/state/session/s1.head"
  printf 'changed app\n' > "$repo/app.ts"
  printf 'updated state\n' > "$repo/.loop/memory/STATE.md"
  run_hook "$STOP_GATE" "$repo" '{"session_id":"s1"}'
  assert_eq 0 "$CAPTURE_STATUS" "stop-gate exits 0 when STATE is updated" &&
    assert_eq "" "$CAPTURE_OUT" "stop-gate allows code change with STATE update"
}

stop_gate_docs_and_markdown_only_passes() {
  local repo base
  repo="$(setup_repo)"
  base="$(git -C "$repo" rev-parse HEAD)"
  mkdir -p "$repo/.loop/state/session" "$repo/docs"
  printf '%s\n' "$base" > "$repo/.loop/state/session/s1.head"
  printf 'doc\n' > "$repo/docs/guide.ts"
  printf 'note\n' > "$repo/notes.md"
  run_hook "$STOP_GATE" "$repo" '{"session_id":"s1"}'
  assert_eq 0 "$CAPTURE_STATUS" "stop-gate exits 0 for docs/markdown-only changes" &&
    assert_eq "" "$CAPTURE_OUT" "stop-gate allows docs/markdown-only changes"
}

stop_gate_missing_head_clean_passes() {
  local repo
  repo="$(setup_repo)"
  run_hook "$STOP_GATE" "$repo" '{"session_id":"s1"}'
  assert_eq 0 "$CAPTURE_STATUS" "stop-gate exits 0 without head file in clean repo" &&
    assert_eq "" "$CAPTURE_OUT" "stop-gate is silent without head file in clean repo"
}

stop_gate_committed_code_without_state_blocks() {
  local repo base
  repo="$(setup_repo)"
  base="$(git -C "$repo" rev-parse HEAD)"
  mkdir -p "$repo/.loop/state/session"
  printf '%s\n' "$base" > "$repo/.loop/state/session/s1.head"
  printf 'committed change\n' > "$repo/app.ts"
  git -C "$repo" add app.ts
  git -C "$repo" commit -qm "change app"
  run_hook "$STOP_GATE" "$repo" '{"session_id":"s1"}'
  assert_eq 0 "$CAPTURE_STATUS" "stop-gate exits 0 when blocking committed code change" &&
    assert_contains "$CAPTURE_OUT" '"decision":"block"' "committed code change is blocked"
}

stop_gate_space_filename_blocks() {
  local repo base
  repo="$(setup_repo)"
  base="$(git -C "$repo" rev-parse HEAD)"
  mkdir -p "$repo/.loop/state/session"
  printf '%s\n' "$base" > "$repo/.loop/state/session/s1.head"
  : > "$repo/.loop/state/session/s1.untracked"
  printf 'space file\n' > "$repo/my file.ts"
  run_hook "$STOP_GATE" "$repo" '{"session_id":"s1"}'
  assert_eq 0 "$CAPTURE_STATUS" "stop-gate exits 0 when blocking filename with spaces" &&
    assert_contains "$CAPTURE_OUT" '"decision":"block"' "code filename with spaces is detected"
}

stop_gate_untracked_state_allows_code_change() {
  local repo base
  repo="$(new_tmp_dir)"
  git -C "$repo" init -q
  git -C "$repo" config user.email "loopcraft-tests@example.com"
  git -C "$repo" config user.name "Loopcraft Tests"
  mkdir -p "$repo/.loop/memory"
  printf 'initial app\n' > "$repo/app.ts"
  printf 'initial index\n' > "$repo/.loop/memory/INDEX.md"
  git -C "$repo" add .
  git -C "$repo" commit -qm "initial"
  base="$(git -C "$repo" rev-parse HEAD)"
  mkdir -p "$repo/.loop/state/session"
  printf '%s\n' "$base" > "$repo/.loop/state/session/s1.head"
  : > "$repo/.loop/state/session/s1.untracked"
  printf 'changed app\n' > "$repo/app.ts"
  printf 'new state\n' > "$repo/.loop/memory/STATE.md"
  run_hook "$STOP_GATE" "$repo" '{"session_id":"s1"}'
  assert_eq 0 "$CAPTURE_STATUS" "stop-gate exits 0 when STATE is untracked and present" &&
    assert_eq "" "$CAPTURE_OUT" "untracked STATE.md satisfies STATE update check"
}

stop_gate_existing_untracked_code_in_baseline_passes() {
  local repo base
  repo="$(setup_repo)"
  base="$(git -C "$repo" rev-parse HEAD)"
  mkdir -p "$repo/.loop/state/session"
  printf 'existing untracked\n' > "$repo/existing.ts"
  printf '%s\n' "$base" > "$repo/.loop/state/session/s1.head"
  printf 'existing.ts\n' > "$repo/.loop/state/session/s1.untracked"
  run_hook "$STOP_GATE" "$repo" '{"session_id":"s1"}'
  assert_eq 0 "$CAPTURE_STATUS" "stop-gate exits 0 with baseline untracked code only" &&
    assert_eq "" "$CAPTURE_OUT" "baseline untracked code does not false-block"
}

stop_gate_new_untracked_code_without_state_blocks() {
  local repo base
  repo="$(setup_repo)"
  base="$(git -C "$repo" rev-parse HEAD)"
  mkdir -p "$repo/.loop/state/session"
  printf '%s\n' "$base" > "$repo/.loop/state/session/s1.head"
  : > "$repo/.loop/state/session/s1.untracked"
  printf 'new untracked\n' > "$repo/new-file.ts"
  run_hook "$STOP_GATE" "$repo" '{"session_id":"s1"}'
  assert_eq 0 "$CAPTURE_STATUS" "stop-gate exits 0 when blocking new untracked code" &&
    assert_contains "$CAPTURE_OUT" '"decision":"block"' "new untracked code without STATE is blocked"
}

stop_gate_sanitizes_session_id() {
  local repo
  repo="$(setup_repo)"
  mkdir -p "$repo/.loop/state"
  printf 'task\n' > "$repo/.loop/state/current-task"
  run_hook "$STOP_GATE" "$repo" '{"session_id":"../../evil"}'
  assert_eq 0 "$CAPTURE_STATUS" "stop-gate exits 0 for malicious session_id" &&
    assert_contains "$CAPTURE_OUT" '"decision":"block"' "malicious session_id still blocks current task" &&
    assert_file_exists "$repo/.loop/state/session/....evil.warned" "sanitized warned marker is created" &&
    assert_file_not_exists "$repo/.loop/evil.warned" "stop-gate does not write through path traversal"
}

pre_compact_json_context() {
  local repo
  repo="$(setup_repo)"
  run_hook "$PRE_COMPACT" "$repo" '{}'
  assert_eq 0 "$CAPTURE_STATUS" "pre-compact exits 0 with memory" &&
    assert_json_one_line "$CAPTURE_OUT" "pre-compact output is single JSON" &&
    assert_contains "$CAPTURE_OUT" "additionalContext" "pre-compact JSON includes additionalContext"
}

pre_compact_no_loop_silent() {
  local repo
  repo="$(new_tmp_dir)"
  git -C "$repo" init -q
  git -C "$repo" config user.email "loopcraft-tests@example.com"
  git -C "$repo" config user.name "Loopcraft Tests"
  printf 'x\n' > "$repo/app.ts"
  git -C "$repo" add app.ts
  git -C "$repo" commit -qm "initial"
  run_hook "$PRE_COMPACT" "$repo" '{}'
  assert_eq 0 "$CAPTURE_STATUS" "pre-compact exits 0 without .loop" &&
    assert_eq "" "$CAPTURE_OUT" "pre-compact is silent without .loop"
}

pre_compact_loop_disable_silent() {
  local repo
  repo="$(setup_repo)"
  run_hook "$PRE_COMPACT" "$repo" '{}' 1
  assert_eq 0 "$CAPTURE_STATUS" "pre-compact exits 0 with LOOP_DISABLE" &&
    assert_eq "" "$CAPTURE_OUT" "pre-compact is silent with LOOP_DISABLE"
}

test_case "session-start: no .loop/memory is silent" session_start_no_memory
test_case "session-start: LOOP_DISABLE is silent" session_start_loop_disable
test_case "session-start: INDEX and STATE are included" session_start_includes_index_and_state
test_case "session-start: LEDGER open failures warn" session_start_ledger_open_failures
test_case "session-start: distilled-only LEDGER does not warn" session_start_ledger_distilled_only
test_case "session-start: writes HEAD sha" session_start_writes_head
test_case "session-start: pretty JSON writes HEAD sha" session_start_pretty_json_writes_head
test_case "session-start: non-git directory does not crash" session_start_non_git_no_crash
test_case "session-start: sanitizes malicious session_id" session_start_sanitizes_session_id
test_case "stop-gate: stop_hook_active exits silently" stop_gate_stop_hook_active
test_case "stop-gate: pretty JSON stop_hook_active exits silently" stop_gate_pretty_json_stop_hook_active
test_case "stop-gate: current-task blocks once and marks warned" stop_gate_current_task_blocks_once_and_marks_warned
test_case "stop-gate: block output first line is valid JSON" stop_gate_block_output_is_valid_json
test_case "stop-gate: json_escape escapes quotes and backslashes" stop_gate_json_escape_escapes_quote_and_backslash
test_case "stop-gate: warned marker allows exit" stop_gate_warned_marker_allows_exit
test_case "stop-gate: worktree code without STATE blocks" stop_gate_worktree_code_without_state_blocks
test_case "stop-gate: worktree code with STATE passes" stop_gate_worktree_code_with_state_passes
test_case "stop-gate: docs and markdown only pass" stop_gate_docs_and_markdown_only_passes
test_case "stop-gate: missing head and clean tree pass" stop_gate_missing_head_clean_passes
test_case "stop-gate: committed code without STATE blocks" stop_gate_committed_code_without_state_blocks
test_case "stop-gate: filename with spaces is detected" stop_gate_space_filename_blocks
test_case "stop-gate: untracked STATE allows code change" stop_gate_untracked_state_allows_code_change
test_case "stop-gate: baseline untracked code does not block" stop_gate_existing_untracked_code_in_baseline_passes
test_case "stop-gate: new untracked code without STATE blocks" stop_gate_new_untracked_code_without_state_blocks
test_case "stop-gate: sanitizes malicious session_id" stop_gate_sanitizes_session_id
test_case "pre-compact: emits valid JSON with additionalContext" pre_compact_json_context
test_case "pre-compact: no .loop is silent" pre_compact_no_loop_silent
test_case "pre-compact: LOOP_DISABLE is silent" pre_compact_loop_disable_silent

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]

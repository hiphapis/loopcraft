#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SESSION_START="$ROOT_DIR/hooks/scripts/session-start.sh"
STOP_GATE="$ROOT_DIR/hooks/scripts/stop-gate.sh"
PRE_COMPACT="$ROOT_DIR/hooks/scripts/pre-compact.sh"
ADAPTER_GH="$ROOT_DIR/adapters/github.sh"
ADAPTER_JIRA="$ROOT_DIR/adapters/jira.sh"

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

# Create a bin stub: $1=case directory, $2=command name, $3=body script → prints the bin directory path to add to PATH
make_bin_stub() {
  local casedir="$1" name="$2" body="$3" bindir
  bindir="$casedir/bin"
  mkdir -p "$bindir"
  printf '#!/usr/bin/env bash\n%s\n' "$body" > "$bindir/$name"
  chmod +x "$bindir/$name"
  printf '%s\n' "$bindir"
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
    assert_contains "$CAPTURE_OUT" "2 unresolved failures" "open LEDGER entries are counted"
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
    assert_not_contains "$CAPTURE_OUT" "unresolved failures" "distilled-only LEDGER does not warn"
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
    assert_contains "$CAPTURE_OUT" "systemMessage" "pre-compact JSON includes systemMessage"
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

adapter_list_maps_fields_and_skip() {
  local dir bindir cap fixture out id title body ref skip skipreason nullbody args
  dir="$(new_tmp_dir)"; cap="$dir/gh.log"; fixture="$dir/issues.json"
  cat > "$fixture" <<'JSON'
[
  {"number":42,"title":"fix login","body":"do it","url":"https://gh/issues/42","labels":[{"name":"loop:ready"}]},
  {"number":7,"title":"manual QA","body":null,"url":"https://gh/issues/7","labels":[{"name":"loop:ready"},{"name":"loop:manual"}]}
]
JSON
  bindir="$(make_bin_stub "$dir" gh 'printf "%s\n" "$*" >> "'"$cap"'"; cat "'"$fixture"'"')"
  out="$(PATH="$bindir:$PATH" bash "$ADAPTER_GH" list --label loop:ready)"
  args="$(cat "$cap")"
  id="$(printf '%s' "$out" | jq -r '.[0].id')"
  title="$(printf '%s' "$out" | jq -r '.[0].title')"
  body="$(printf '%s' "$out" | jq -r '.[0].body')"
  ref="$(printf '%s' "$out" | jq -r '.[0].ref')"
  skip="$(printf '%s' "$out" | jq -r '.[1].skip')"
  skipreason="$(printf '%s' "$out" | jq -r '.[1].skipReason')"
  nullbody="$(printf '%s' "$out" | jq -r '.[1].body')"
  assert_eq "42" "$id" "list maps number→id" &&
    assert_eq "fix login" "$title" "list preserves title" &&
    assert_eq "do it" "$body" "list preserves body" &&
    assert_eq "https://gh/issues/42" "$ref" "list maps url→ref" &&
    assert_eq "true" "$skip" "loop:manual item is marked skip" &&
    assert_eq "manual" "$skipreason" "skip item carries skipReason=manual" &&
    assert_eq "" "$nullbody" "null body coalesces to empty string" &&
    assert_contains "$args" "issue list" "adapter calls gh issue list" &&
    assert_contains "$args" "--label loop:ready" "adapter passes the label filter to gh" &&
    assert_contains "$args" "--json number,title,body,url,labels" "adapter requests the required fields" &&
    assert_contains "$args" "--state open" "adapter requests open issues"
}

adapter_list_marks_blocked_skip() {
  local dir bindir fixture out skip skipreason
  dir="$(new_tmp_dir)"; fixture="$dir/issues.json"
  cat > "$fixture" <<'JSON'
[{"number":5,"title":"was escalated","body":"x","url":"https://gh/issues/5","labels":[{"name":"loop:ready"},{"name":"loop:blocked"}]}]
JSON
  bindir="$(make_bin_stub "$dir" gh 'cat "'"$fixture"'"')"
  out="$(PATH="$bindir:$PATH" bash "$ADAPTER_GH" list --label loop:ready)"
  skip="$(printf '%s' "$out" | jq -r '.[0].skip')"
  skipreason="$(printf '%s' "$out" | jq -r '.[0].skipReason')"
  assert_eq "true" "$skip" "loop:blocked item is marked skip (won't re-process)" &&
    assert_eq "blocked" "$skipreason" "blocked item carries skipReason=blocked"
}

adapter_list_fails_when_gh_fails() {
  local dir bindir status nonzero
  dir="$(new_tmp_dir)"
  bindir="$(make_bin_stub "$dir" gh 'exit 1')"
  PATH="$bindir:$PATH" bash "$ADAPTER_GH" list --label loop:ready >/dev/null 2>&1
  status=$?
  nonzero=$([ "$status" -ne 0 ] && echo yes || echo no)
  assert_eq "yes" "$nonzero" "list exits nonzero when gh fails (no empty-backlog masking)"
}

adapter_pr_creates_draft_with_closes() {
  local dir bindir cap out
  dir="$(new_tmp_dir)"; cap="$dir/gh.log"
  bindir="$(make_bin_stub "$dir" gh 'printf "%s\n" "$*" >> "'"$cap"'"; case "$*" in *"pr create"*) echo "https://gh/pr/1" ;; esac')"
  out="$(PATH="$bindir:$PATH" LOOP_ITEM_ID=42 LOOP_BRANCH=loop/42 LOOP_BASE=main LOOP_VERDICT=3/3 \
    bash "$ADAPTER_GH" pr)"
  assert_contains "$(cat "$cap")" "pr create --draft" "pr subcommand opens a draft PR" &&
    assert_contains "$(cat "$cap")" "--head loop/42" "pr subcommand uses the item branch" &&
    assert_contains "$(cat "$cap")" "--base main" "pr subcommand uses the base branch" &&
    assert_contains "$(cat "$cap")" "Closes #42" "PR body links the issue for auto-close on merge" &&
    assert_eq "https://gh/pr/1" "$out" "pr subcommand stdout is the PR URL"
}

adapter_pr_missing_item_id() {
  local dir bindir cap status
  dir="$(new_tmp_dir)"; cap="$dir/gh.log"
  bindir="$(make_bin_stub "$dir" gh 'printf "%s\n" "$*" >> "'"$cap"'"')"
  PATH="$bindir:$PATH" env -u LOOP_ITEM_ID LOOP_BRANCH=loop/42 LOOP_BASE=main bash "$ADAPTER_GH" pr >/dev/null 2>&1
  status=$?
  assert_eq "2" "$status" "pr exits 2 when LOOP_ITEM_ID is missing" &&
    assert_eq "" "$(cat "$cap" 2>/dev/null)" "pr makes no gh calls when LOOP_ITEM_ID is missing"
}

adapter_report_comment_only() {
  local dir bindir cap
  dir="$(new_tmp_dir)"; cap="$dir/gh.log"
  bindir="$(make_bin_stub "$dir" gh 'printf "%s\n" "$*" >> "'"$cap"'"')"
  PATH="$bindir:$PATH" LOOP_EVENT=verified LOOP_WRITEBACK=comment \
    LOOP_ITEM_ID=42 LOOP_VERDICT=3/3 LOOP_COMMIT=abc123 LOOP_BRANCH=loop-run/x \
    bash "$ADAPTER_GH" report
  assert_contains "$(cat "$cap")" "issue comment 42" "comment mode comments on the issue" &&
    assert_not_contains "$(cat "$cap")" "pr create" "comment mode does not open a PR"
}

adapter_report_never_creates_pr() {
  local dir bindir cap
  dir="$(new_tmp_dir)"; cap="$dir/gh.log"
  bindir="$(make_bin_stub "$dir" gh 'printf "%s\n" "$*" >> "'"$cap"'"')"
  PATH="$bindir:$PATH" LOOP_EVENT=verified LOOP_WRITEBACK=draft-pr \
    LOOP_ITEM_ID=42 LOOP_VERDICT=3/3 LOOP_COMMIT=abc123 LOOP_BRANCH=loop/42 LOOP_BASE=main \
    bash "$ADAPTER_GH" report
  assert_contains "$(cat "$cap")" "issue comment 42" "report still comments on the issue" &&
    assert_not_contains "$(cat "$cap")" "pr create" "report never creates a PR"
}

adapter_report_escalated() {
  local dir bindir cap
  dir="$(new_tmp_dir)"; cap="$dir/gh.log"
  bindir="$(make_bin_stub "$dir" gh 'printf "%s\n" "$*" >> "'"$cap"'"')"
  PATH="$bindir:$PATH" LOOP_EVENT=escalated LOOP_WRITEBACK=draft-pr \
    LOOP_ITEM_ID=42 LOOP_NOTE="max retries" \
    bash "$ADAPTER_GH" report
  assert_contains "$(cat "$cap")" "issue edit 42 --add-label loop:blocked" "escalated adds blocked label" &&
    assert_contains "$(cat "$cap")" "issue comment 42" "escalated comments the reason" &&
    assert_not_contains "$(cat "$cap")" "pr create" "escalated does not open a PR"
}

adapter_report_partial_gh_failure_surfaces() {
  local dir bindir status nz
  dir="$(new_tmp_dir)"
  bindir="$(make_bin_stub "$dir" gh 'case "$*" in *"issue comment"*) exit 1 ;; *) exit 0 ;; esac')"
  PATH="$bindir:$PATH" LOOP_EVENT=escalated LOOP_ITEM_ID=42 LOOP_NOTE="max retries" \
    bash "$ADAPTER_GH" report >/dev/null 2>&1
  status=$?
  nz=$([ "$status" -ne 0 ] && echo yes || echo no)
  assert_eq "yes" "$nz" "report surfaces a partial gh failure"
}

adapter_report_missing_item_id() {
  local dir bindir cap status
  dir="$(new_tmp_dir)"; cap="$dir/gh.log"
  bindir="$(make_bin_stub "$dir" gh 'printf "%s\n" "$*" >> "'"$cap"'"')"
  PATH="$bindir:$PATH" env -u LOOP_ITEM_ID LOOP_EVENT=verified bash "$ADAPTER_GH" report >/dev/null 2>&1
  status=$?
  assert_eq "2" "$status" "report exits 2 when LOOP_ITEM_ID is missing" &&
    assert_eq "" "$(cat "$cap" 2>/dev/null)" "report makes no gh calls when LOOP_ITEM_ID is missing"
}

adapter_report_unknown_event() {
  local dir bindir cap status
  dir="$(new_tmp_dir)"; cap="$dir/gh.log"
  bindir="$(make_bin_stub "$dir" gh 'printf "%s\n" "$*" >> "'"$cap"'"')"
  PATH="$bindir:$PATH" LOOP_ITEM_ID=42 LOOP_EVENT=bogus bash "$ADAPTER_GH" report >/dev/null 2>&1
  status=$?
  assert_eq "2" "$status" "report exits 2 for unknown LOOP_EVENT"
}

adapter_report_started_is_noop() {
  local dir bindir cap status
  dir="$(new_tmp_dir)"; cap="$dir/gh.log"
  bindir="$(make_bin_stub "$dir" gh 'printf "%s\n" "$*" >> "'"$cap"'"')"
  PATH="$bindir:$PATH" LOOP_ITEM_ID=42 LOOP_EVENT=started bash "$ADAPTER_GH" report >/dev/null 2>&1
  status=$?
  assert_eq "0" "$status" "report exits 0 for started event" &&
    assert_eq "" "$(cat "$cap" 2>/dev/null)" "started makes no gh calls"
}

adapter_report_includes_pr_url() {
  local dir bindir cap
  dir="$(new_tmp_dir)"; cap="$dir/gh.log"
  bindir="$(make_bin_stub "$dir" gh 'printf "%s\n" "$*" >> "'"$cap"'"')"
  PATH="$bindir:$PATH" LOOP_EVENT=verified LOOP_ITEM_ID=42 LOOP_VERDICT=3/3 LOOP_COMMIT=abc \
    LOOP_BRANCH=loop/42 LOOP_PR_URL=https://gh/pr/1 \
    bash "$ADAPTER_GH" report
  assert_contains "$(cat "$cap")" "issue comment 42" "report comments on the issue" &&
    assert_contains "$(cat "$cap")" "https://gh/pr/1" "report comment includes the PR URL"
}

backlog_list_command_from_config_yields_contract() {
  local dir bindir cfgcmd out id
  dir="$(new_tmp_dir)"; mkdir -p "$dir/.loop/adapters"
  cp "$ROOT_DIR/adapters/github.sh" "$dir/.loop/adapters/github.sh"
  bindir="$(make_bin_stub "$dir" gh 'cat <<'"'"'JSON'"'"'
[{"number":9,"title":"t","body":"b","url":"https://gh/issues/9","labels":[{"name":"loop:ready"}]}]
JSON')"
  cat > "$dir/.loop/config.json" <<JSON
{ "backlog": { "source": "github",
  "list": "bash $dir/.loop/adapters/github.sh list --label loop:ready",
  "report": "bash $dir/.loop/adapters/github.sh report",
  "writeback": "comment" } }
JSON
  cfgcmd="$(jq -r '.backlog.list' "$dir/.loop/config.json")"
  out="$(PATH="$bindir:$PATH" bash -c "$cfgcmd")"
  id="$(printf '%s' "$out" | jq -r '.[0].id')"
  assert_eq "9" "$id" "config.backlog.list command yields the normalized contract"
}

adapter_jira_list_maps_fields_and_skip() {
  local dir bindir cap fixture out id title body ref skip skip1 skipreason1 nullbody skipreason2
  dir="$(new_tmp_dir)"; cap="$dir/curl.log"; fixture="$dir/search.json"
  cat > "$fixture" <<'JSON'
{
  "issues": [
    {"key":"ABC-1","fields":{"summary":"first task","description":"do it","labels":["loop-ready"]}},
    {"key":"ABC-2","fields":{"summary":"second task","description":null,"labels":["loop-ready","loop-manual"]}},
    {"key":"ABC-3","fields":{"summary":"third task","description":"do it too","labels":["loop-ready","loop-blocked"]}}
  ]
}
JSON
  bindir="$(make_bin_stub "$dir" curl 'case "$*" in *"/rest/api/2/search"*) cat "'"$fixture"'" ;; *) printf "%s\n" "$*" >> "'"$cap"'" ;; esac')"
  out="$(PATH="$bindir:$PATH" JIRA_BASE_URL=https://jira.example JIRA_EMAIL=a@b.c JIRA_TOKEN=t \
    bash "$ADAPTER_JIRA" list --jql "project = ABC")"
  id="$(printf '%s' "$out" | jq -r '.[0].id')"
  title="$(printf '%s' "$out" | jq -r '.[0].title')"
  body="$(printf '%s' "$out" | jq -r '.[0].body')"
  ref="$(printf '%s' "$out" | jq -r '.[0].ref')"
  skip="$(printf '%s' "$out" | jq -r '.[0].skip')"
  skip1="$(printf '%s' "$out" | jq -r '.[1].skip')"
  skipreason1="$(printf '%s' "$out" | jq -r '.[1].skipReason')"
  nullbody="$(printf '%s' "$out" | jq -r '.[1].body')"
  skipreason2="$(printf '%s' "$out" | jq -r '.[2].skipReason')"
  assert_eq "ABC-1" "$id" "list maps key→id" &&
    assert_eq "first task" "$title" "list preserves summary as title" &&
    assert_eq "do it" "$body" "list preserves description as body" &&
    assert_eq "https://jira.example/browse/ABC-1" "$ref" "list builds browse ref from base URL and key" &&
    assert_eq "false" "$skip" "plain ready issue is not skipped" &&
    assert_eq "true" "$skip1" "loop-manual item is marked skip" &&
    assert_eq "manual" "$skipreason1" "skip item carries skipReason=manual" &&
    assert_eq "" "$nullbody" "null description coalesces to empty string" &&
    assert_eq "blocked" "$skipreason2" "loop-blocked item carries skipReason=blocked"
}

adapter_jira_report_verified_comment() {
  local dir bindir cap log
  dir="$(new_tmp_dir)"; cap="$dir/curl.log"
  bindir="$(make_bin_stub "$dir" curl 'case "$*" in *"/rest/api/2/search"*) : ;; *) { printf "%s\n" "$*"; cat; printf "\n"; } >> "'"$cap"'" ;; esac')"
  PATH="$bindir:$PATH" JIRA_BASE_URL=https://jira.example JIRA_EMAIL=a@b.c JIRA_TOKEN=t \
    LOOP_EVENT=verified LOOP_ITEM_ID=ABC-1 LOOP_PR_URL=https://gh/pr/1 \
    bash "$ADAPTER_JIRA" report
  log="$(cat "$cap" 2>/dev/null)"
  assert_contains "$log" "/rest/api/2/issue/ABC-1/comment" "verified posts a comment on the issue" &&
    assert_contains "$log" "https://gh/pr/1" "verified comment includes the PR URL" &&
    assert_not_contains "$log" "-X PUT" "verified does not change labels"
}

adapter_jira_report_escalated_comment_and_label() {
  local dir bindir cap log
  dir="$(new_tmp_dir)"; cap="$dir/curl.log"
  bindir="$(make_bin_stub "$dir" curl 'case "$*" in *"/rest/api/2/search"*) : ;; *) { printf "%s\n" "$*"; cat; printf "\n"; } >> "'"$cap"'" ;; esac')"
  PATH="$bindir:$PATH" JIRA_BASE_URL=https://jira.example JIRA_EMAIL=a@b.c JIRA_TOKEN=t \
    LOOP_EVENT=escalated LOOP_ITEM_ID=ABC-1 LOOP_NOTE="max retries" \
    bash "$ADAPTER_JIRA" report
  log="$(cat "$cap" 2>/dev/null)"
  assert_contains "$log" "/rest/api/2/issue/ABC-1/comment" "escalated posts a comment on the issue" &&
    assert_contains "$log" "-X PUT" "escalated issues a PUT to update the issue" &&
    assert_contains "$log" "/rest/api/2/issue/ABC-1" "escalated PUT targets the issue" &&
    assert_contains "$log" "loop-blocked" "escalated adds the loop-blocked label"
}

adapter_jira_report_missing_item_id() {
  local dir bindir cap status
  dir="$(new_tmp_dir)"; cap="$dir/curl.log"
  bindir="$(make_bin_stub "$dir" curl 'printf "%s\n" "$*" >> "'"$cap"'"')"
  PATH="$bindir:$PATH" JIRA_BASE_URL=https://jira.example JIRA_EMAIL=a@b.c JIRA_TOKEN=t \
    env -u LOOP_ITEM_ID LOOP_EVENT=verified bash "$ADAPTER_JIRA" report >/dev/null 2>&1
  status=$?
  assert_eq "2" "$status" "report exits 2 when LOOP_ITEM_ID is missing"
}

adapter_jira_report_unknown_event() {
  local dir bindir cap status
  dir="$(new_tmp_dir)"; cap="$dir/curl.log"
  bindir="$(make_bin_stub "$dir" curl 'printf "%s\n" "$*" >> "'"$cap"'"')"
  PATH="$bindir:$PATH" JIRA_BASE_URL=https://jira.example JIRA_EMAIL=a@b.c JIRA_TOKEN=t \
    LOOP_ITEM_ID=ABC-1 LOOP_EVENT=bogus bash "$ADAPTER_JIRA" report >/dev/null 2>&1
  status=$?
  assert_eq "2" "$status" "report exits 2 for unknown LOOP_EVENT"
}

adapter_jira_missing_env_exits_2() {
  local dir bindir cap status log
  dir="$(new_tmp_dir)"; cap="$dir/curl.log"
  bindir="$(make_bin_stub "$dir" curl 'printf "%s\n" "$*" >> "'"$cap"'"')"
  PATH="$bindir:$PATH" JIRA_BASE_URL=https://jira.example JIRA_EMAIL=a@b.c \
    env -u JIRA_TOKEN bash "$ADAPTER_JIRA" list --jql "project = ABC" >/dev/null 2>&1
  status=$?
  log="$(cat "$cap" 2>/dev/null)"
  assert_eq "2" "$status" "list exits 2 when JIRA_TOKEN is missing" &&
    assert_eq "" "$log" "list makes no curl calls when JIRA env is incomplete"
}

adapter_jira_report_started_is_noop() {
  local dir bindir cap status
  dir="$(new_tmp_dir)"; cap="$dir/curl.log"
  bindir="$(make_bin_stub "$dir" curl 'printf "%s\n" "$*" >> "'"$cap"'"')"
  PATH="$bindir:$PATH" JIRA_BASE_URL=https://jira.example JIRA_EMAIL=a@b.c JIRA_TOKEN=t \
    LOOP_ITEM_ID=ABC-1 LOOP_EVENT=started bash "$ADAPTER_JIRA" report >/dev/null 2>&1
  status=$?
  assert_eq "0" "$status" "report exits 0 for started event" &&
    assert_eq "" "$(cat "$cap" 2>/dev/null)" "started makes no curl calls"
}

adapter_jira_report_partial_failure_surfaces() {
  local dir bindir status nz
  dir="$(new_tmp_dir)"
  bindir="$(make_bin_stub "$dir" curl 'case "$*" in *"/comment"*) exit 1 ;; *) exit 0 ;; esac')"
  PATH="$bindir:$PATH" JIRA_BASE_URL=https://jira.example JIRA_EMAIL=a@b.c JIRA_TOKEN=t \
    LOOP_EVENT=escalated LOOP_ITEM_ID=ABC-1 LOOP_NOTE=x \
    bash "$ADAPTER_JIRA" report >/dev/null 2>&1
  status=$?
  nz=$([ "$status" -ne 0 ] && echo yes || echo no)
  assert_eq "yes" "$nz" "report surfaces a partial curl failure (comment POST fails, label PUT succeeds)"
}

adapter_jira_report_missing_env_exits_2() {
  local dir bindir cap status log
  dir="$(new_tmp_dir)"; cap="$dir/curl.log"
  bindir="$(make_bin_stub "$dir" curl 'printf "%s\n" "$*" >> "'"$cap"'"')"
  PATH="$bindir:$PATH" JIRA_BASE_URL=https://jira.example JIRA_EMAIL=a@b.c \
    LOOP_EVENT=verified LOOP_ITEM_ID=ABC-1 \
    env -u JIRA_TOKEN bash "$ADAPTER_JIRA" report >/dev/null 2>&1
  status=$?
  log="$(cat "$cap" 2>/dev/null)"
  assert_eq "2" "$status" "report exits 2 when JIRA_TOKEN is missing" &&
    assert_eq "" "$log" "report makes no curl calls when JIRA env is incomplete"
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
test_case "pre-compact: emits valid JSON with systemMessage" pre_compact_json_context
test_case "pre-compact: no .loop is silent" pre_compact_no_loop_silent
test_case "pre-compact: LOOP_DISABLE is silent" pre_compact_loop_disable_silent
test_case "adapter/github: list maps fields and skip label" adapter_list_maps_fields_and_skip
test_case "adapter/github: list marks loop:blocked as skip" adapter_list_marks_blocked_skip
test_case "adapter/github: list propagates gh failure" adapter_list_fails_when_gh_fails
test_case "adapter/github: pr creates draft PR with Closes" adapter_pr_creates_draft_with_closes
test_case "adapter/github: pr requires LOOP_ITEM_ID" adapter_pr_missing_item_id
test_case "adapter/github: report comment-only" adapter_report_comment_only
test_case "adapter/github: report never creates a PR (comment only)" adapter_report_never_creates_pr
test_case "adapter/github: report escalated labels blocked" adapter_report_escalated
test_case "adapter/github: report surfaces partial gh failure" adapter_report_partial_gh_failure_surfaces
test_case "adapter/github: report missing LOOP_ITEM_ID exits 2" adapter_report_missing_item_id
test_case "adapter/github: report unknown LOOP_EVENT exits 2" adapter_report_unknown_event
test_case "adapter/github: report started is a no-op" adapter_report_started_is_noop
test_case "adapter/github: report includes PR url when set" adapter_report_includes_pr_url
test_case "backlog: config list command yields contract" backlog_list_command_from_config_yields_contract
test_case "adapter/jira: list maps fields and skip labels" adapter_jira_list_maps_fields_and_skip
test_case "adapter/jira: report verified posts a comment" adapter_jira_report_verified_comment
test_case "adapter/jira: report escalated comments and labels blocked" adapter_jira_report_escalated_comment_and_label
test_case "adapter/jira: report missing LOOP_ITEM_ID exits 2" adapter_jira_report_missing_item_id
test_case "adapter/jira: report unknown LOOP_EVENT exits 2" adapter_jira_report_unknown_event
test_case "adapter/jira: missing JIRA env exits 2" adapter_jira_missing_env_exits_2
test_case "adapter/jira: report started is a no-op" adapter_jira_report_started_is_noop
test_case "adapter/jira: report partial failure surfaces" adapter_jira_report_partial_failure_surfaces
test_case "adapter/jira: report missing env exits 2" adapter_jira_report_missing_env_exits_2

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]

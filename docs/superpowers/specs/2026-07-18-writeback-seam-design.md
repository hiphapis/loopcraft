# Write-back seam — decouple PR creation from the vendor report

> 작성: 2026-07-18 · 상태: 승인됨 · 대상: loopcraft (issue #4) · 후속: #5 Jira

## 배경
draft-pr write-back에서 PR 생성(`gh pr create`)이 **태스크-트래커 어댑터의 `report`** 안에 묶여 있다. 그래서 backlog 소스가 Jira이고 코드가 GitHub에 있으면, Jira의 `report`가 GitHub PR을 열 수 없다. 태스크-트래커(코멘트/전환)와 코드-호스트(PR)는 직교 관심사인데 한 커맨드에 뒤섞여 있는 게 문제.

## 목표 / 비목표
**목표**: PR 생성을 `report`에서 분리해, `draft-pr`이 backlog 소스와 무관하게 동작하도록 한다.
**비목표**: Jira 어댑터 구현(#5), draft-pr 완료가 Jira 이슈를 닫는 방식(smart-commit 등 — #5).

## 설계 (Approach A — 별도 `config.pr` 커맨드)

### config 스키마
```json
"backlog": { "source": "...", "list": "...", "report": "...", "writeback": "draft-pr", "base": "main" },
"pr": "bash .loop/adapters/github.sh pr"
```
- `config.pr` = 코드-호스트 PR 커맨드. **`writeback: draft-pr`일 때만** 사용. comment/none은 무시(하위호환).
- draft-pr인데 `config.pr` 미설정 → 경고 + 그 항목 comment 폴백(run 중단 안 함).

### 코어 흐름 (loop-run, draft-pr)
각 항목: `loop/<id>` 분기 → loop-task 사이클 → PASS → `git push -u origin loop/<id>` → **`config.pr` 실행**(draft PR 생성, stdout = PR URL → `LOOP_PR_URL`) → `report`(verified, `LOOP_PR_URL` 포함). PR 생성은 코어 오케스트레이션 + `pr` 커맨드로 이동.

### 계약 (env)
- `pr` 입력: `LOOP_ITEM_ID`, `LOOP_BRANCH`, `LOOP_BASE`, `LOOP_VERDICT`. 출력: PR URL(stdout).
- `report`(verified): 기존 payload + `LOOP_PR_URL`(선택).

### github.sh 변경
- **신규 `pr` 서브커맨드**: `gh pr create --draft --head "$LOOP_BRANCH" --base "$LOOP_BASE" --title "loopcraft: #$id" --body "Closes #$id"$'\n\n'"loopcraft verified $LOOP_VERDICT."` (gh가 URL을 stdout 출력).
- **`report`(verified) 단순화**: `gh pr create` 블록 제거, `gh issue comment`만(선택적 `· PR $LOOP_PR_URL`). report는 writeback 분기 불필요 = 순수 태스크-트래커.
- `main` 디스패처에 `pr) cmd_pr "$@" ;;` 추가.

## 에러 처리
- `pr` 실패 → 저널 "pr failed" 기록, report(comment) 진행(브랜치는 push됨), 항목 실패 아님(best-effort).
- draft-pr + `config.pr` 부재 → 경고 + comment 폴백.

## 테스트 (tests/run.sh)
- **신규** `adapter_pr_creates_draft_with_closes`: gh 스텁 → `github.sh pr`가 `gh pr create --draft --head … --base …` + `Closes #<id>` 호출 + PR URL을 stdout에 출력.
- **갱신** `adapter_report_draft_pr` → report(verified)는 이제 PR을 만들지 않고 코멘트만("report never creates PRs"). draft-pr 여부와 무관.
- 기존 report 코멘트/에스컬레이션/에러경로 테스트 유지.

## loop-init / README
- loop-init: draft-pr + GitHub 선택 시 `config.pr = "bash .loop/adapters/github.sh pr"` 기록.
- README ×4 Autonomous runner: write-back 표의 draft-pr 행 + 문구를 "코어가 push → `config.pr`로 PR 생성 → report"로 갱신.

## 하위호환
`config.pr` 선택. comment/none 무영향. draft-pr은 loop-init이 배선, 런타임 부재 시 comment 폴백.

## Acceptance
1. `github.sh pr` 서브커맨드 존재 + Closes 링크 + URL 출력, 테스트 통과.
2. `report`(verified)가 PR을 만들지 않음(코멘트만), 테스트 갱신.
3. loop-run SKILL.md draft-pr 흐름 = push → config.pr → report(LOOP_PR_URL).
4. loop-init이 `config.pr` 배선, README ×4 갱신.
5. `./tests/run.sh` green.

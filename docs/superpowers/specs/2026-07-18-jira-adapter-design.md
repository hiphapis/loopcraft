# Jira adapter (`adapters/jira.sh`)

> 작성: 2026-07-18 · 상태: 승인됨 · 대상: loopcraft (issue #5) · 의존: #4 write-back seam (완료)

## 배경 / 목표
loopcraft의 backlog 소스로 **Jira**를 지원하는 번들 레퍼런스 어댑터. #4 seam 덕분에 Jira는 **태스크-트래커**(list/report)만 담당하고, 코드·PR은 별도 `config.pr`(GitHub)이 담당한다 — Jira 태스크 + GitHub 코드가 조합된다. github.sh와 같은 `list`/`report` 계약을 구현한다.

**비목표**: Jira 상태 전환(transition)으로 자동 완료(‘완료는 사람’ 철학 — GitHub과 동일). Jira 라이브 스모크(인스턴스 부재 → stub 유닛테스트만).

## 인증 (env)
`JIRA_BASE_URL`(예 `https://you.atlassian.net`), `JIRA_EMAIL`, `JIRA_TOKEN`(API 토큰). curl basic-auth `-u "$JIRA_EMAIL:$JIRA_TOKEN"`. REST **v2** 사용(`description`이 plain 문자열 — v3 ADF JSON 파싱 회피). 미설정 시 명확한 에러로 종료.

## `list` — JQL → 정규 계약
`bash adapters/jira.sh list --jql "<JQL>"` → `GET $JIRA_BASE_URL/rest/api/2/search` (curl `-sf` + jq):
```json
{ "id": "<issue key>", "title": "<summary>", "body": "<description or ''>",
  "ref": "<BASE>/browse/<key>",
  "skip": <loop-manual|loop-blocked 라벨 보유>, "skipReason": "manual"|"blocked"|"" }
```
- `id` = 이슈 키(`ABC-123`), `ref` = `<BASE>/browse/<key>`.
- skip: `loop-manual`(수동 전용) 또는 `loop-blocked`(이전 에스컬레이션) 라벨(Jira 라벨은 하이픈).
- JQL 예: `labels = loop-ready AND statusCategory != Done ORDER BY created`.
- `curl -sf`가 실패(인증/네트워크)하면 non-zero → loop-run이 run 중단(빈 backlog 위장 금지).

## `report` — 태스크-트래커 전용 (GitHub과 동일 형태)
env: `LOOP_ITEM_ID`(이슈 키), `LOOP_EVENT`, verified 시 `LOOP_VERDICT`/`LOOP_COMMIT`/`LOOP_BRANCH`(+`LOOP_PR_URL`), escalated 시 `LOOP_NOTE`.
- `verified` → 코멘트 `POST /rest/api/2/issue/{key}/comment` (본문에 `LOOP_PR_URL` 있으면 포함).
- `escalated` → 코멘트 + `loop-blocked` 라벨 추가 `PUT /rest/api/2/issue/{key}` (`update.labels[].add`).
- `started` → no-op. 미지 `LOOP_EVENT` / `LOOP_ITEM_ID` 누락 → exit 2.
- **exit-code 집계**(github.sh #1과 동일): curl 호출 하나라도 실패하면 non-zero 반환(부분 실패 표면화, best-effort).
- **PR 서브커맨드 없음** — PR은 `config.pr`(github.sh pr) 담당. jira.sh는 태스크-트래커만.

## config (Jira 태스크 + GitHub 코드)
```json
"backlog": {
  "source": "jira",
  "list": "bash .loop/adapters/jira.sh list --jql 'labels = loop-ready AND statusCategory != Done'",
  "report": "bash .loop/adapters/jira.sh report",
  "writeback": "draft-pr"
},
"pr": "bash .loop/adapters/github.sh pr",
"base": "main"
```

## 테스트 (stub `curl`, PATH shim)
github.sh 테스트가 `gh`를 스텁하듯 `curl`을 스텁한다:
- `list`: 스텁 curl이 fixture search JSON 반환 → 정규 계약 검증(key→id, summary→title, description→body, browse URL→ref, `loop-manual`/`loop-blocked`→skip/skipReason).
- `report`: 스텁 curl이 args를 로그로 → verified가 `.../comment` POST 구성, escalated가 comment + label PUT 구성, `LOOP_PR_URL` 포함 확인.
- 가드: `LOOP_ITEM_ID` 누락 → exit 2, 미지 이벤트 → exit 2, started no-op.
- 안전 옵션 `set -uo pipefail`, 변수 quoting.

## loop-init / README
- loop-init: Jira 선택 시 `adapters/jira.sh`를 `.loop/adapters/`로 복사, `JIRA_BASE_URL`/`JIRA_EMAIL`/`JIRA_TOKEN` env 설정 안내(미설정 경고), config 배선(source=jira, JQL list, report, `pr`=github.sh pr, base). `loop-ready`/`loop-manual`/`loop-blocked` 라벨은 Jira에서 사람이 준비(안내만).
- README ×4: Autonomous runner에 Jira 소스(인증 env + `config.pr` 조합) 한 줄.

## Acceptance
1. `adapters/jira.sh` `list`(JQL→정규 계약) + `report`(comment/escalated+label, exit-code 집계) 구현.
2. stub-curl 테스트: list 정규화, report 호출 구성, 가드(exit 2), started no-op.
3. loop-init Jira 배선 + README ×4 갱신.
4. `./tests/run.sh` green.

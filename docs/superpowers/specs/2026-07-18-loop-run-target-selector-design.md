# loop-run target selector (`/loop-run #123`)

> 작성: 2026-07-18 · 상태: 승인됨 · 대상: loopcraft (issue #8, Phase 4)

## 배경 / 목표
지금 loop-run 인자는 *처리 개수(기본 3)* 뿐이다. 특정 backlog 항목을 프롬프트로 지정해 그 한 건만 풀 사이클로 돌리고 싶다 — 예: `/loop-run #123`. **아무 이슈나** 타깃하되, 대상이 `loop:ready` 상태가 아니면 **사용자에게 확인 후** 진행한다.

**비목표**: 자유문자열 "구현해줘"(그건 loop-task). 개수 모드 변경.

## 1. 인자 판별
loop-run 인자를 이렇게 해석한다:
- **정수**(`3`) → 개수 모드(현행): loop:ready 큐를 최대 N건 순회.
- **그 외**(`#123`, 이슈 키 `ABC-1`, 비정수) → **타깃 선택자**: 그 한 건만 처리.

## 2. 타깃 조회 — 신규 계약 메서드 `get`
- `config.backlog.get <selector>` → **단건** 정규 항목 `{id, title, body, ref, skip, skipReason, ready}`.
  - `ready` = 대상이 큐 준비상태(예: `loop:ready` 라벨 보유 && !skip)인지 여부.
- **github.sh** `get <id>`: `gh issue view <id> --json number,title,body,url,labels` → list와 동일 jq 정규화 + `ready`(loop:ready 라벨 && !(loop:manual|loop:blocked)).
- **jira.sh** `get <key>`: `GET /rest/api/2/issue/<key>` → 정규화 + `ready`(loop-ready 라벨 && !skip).
- `config.backlog.get` 미정의(파일 소스 등) → `list` 출력을 id로 필터하는 폴백(그 경우 loop:ready 범위 내에서만 발견 가능).

## 3. 준비상태 확인
- `ready == true` → 바로 처리.
- `ready == false` → **사용자에게 확인**: "#123은 loop:ready 상태가 아닙니다(사유: skip=… / 라벨=…). 그래도 진행할까요?" → 응답대로 진행/중단.
- 확인이 허용되는 근거: **타깃 모드는 대화형**(사용자가 직접 `/loop-run <selector>` 입력). 무인 배치의 "에스컬레이션 시 사용자에게 못 물음" 규칙은 개수 모드에만 적용된다. 이 구분을 SKILL.md에 명시한다.

## 4. 처리
타깃 단건을 개수 모드와 동일한 loop-task 사이클(rubric → verifier → 게이트 → `Loop-Verified` 커밋 → write-back(config.backlog.writeback: comment/draft-pr))로 처리한다.

## 5. 에러 처리
- `get`이 대상을 못 찾음(존재하지 않는 id) → 명확한 에러로 중단(빈손 아님).
- `get` 실패(인증/네트워크) → run 중단 + 사유 로그.
- 폴백(list 필터)에서 대상이 loop:ready에 없으면 → "loop:ready에 없음 — get 커맨드를 설정하면 아무 이슈나 타깃 가능" 안내.

## 6. 변경 파일
- `skills/loop-run/SKILL.md`: 인자 판별(정수=개수 / 그 외=타깃) + 타깃 모드(`get` 실행 → `ready` 확인/대화형 확인 → 단건 처리). 무인=개수 모드만 asking 금지 명시.
- `adapters/github.sh` / `adapters/jira.sh`: `get` 서브커맨드 + `ready` 필드 + `main` 디스패처.
- `skills/loop-init/SKILL.md`: GitHub/Jira 선택 시 `config.backlog.get`(예: `bash .loop/adapters/github.sh get`) 배선.
- README ×4: Autonomous runner에 `/loop-run #123` 타깃 모드 한 줄.
- `tests/run.sh`: github/jira `get`(stub) → 정규화 + `ready`(ready/not-ready 케이스), not-found → 비정상 종료.

## 7. 하위호환
`get`·타깃 모드는 opt-in. 정수 인자 = 현행 개수 모드 그대로. `config.backlog.get` 없으면 list-필터 폴백.

## Acceptance
1. github.sh·jira.sh `get <id>` 서브커맨드 — 정규 항목 + `ready`, not-found 비정상 종료, 테스트(stub) 포함.
2. loop-run SKILL.md: 인자 판별 + 타깃 모드 + `ready` 대화형 확인 + 무인/대화형 asking 구분.
3. loop-init `config.backlog.get` 배선, README ×4 타깃 모드 문서.
4. `./tests/run.sh` green.

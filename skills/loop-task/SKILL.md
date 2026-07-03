---
name: loop-task
description: 검증 가능한 산출물이 필요한 비자명한 구현·수정 작업을 rubric + 독립 verifier 채점 사이클로 수행한다. 코드·문서 작업을 시작하기 전에 호출. 단순 질문·탐색·한 줄 수정에는 사용하지 않는다.
argument-hint: "[작업 설명]"
---

# Loop-Task — rubric 기반 self-correction 사이클

`.loop/config.json`이 없으면 이 스킬을 중단하고 `/loopcraft:loop-init`을 먼저 안내하라.

## 0. Rubric 결정

- `config.json`의 `rubrics` 배열에서 작업 대상 파일과 글롭이 맞는 항목의 rubric을 쓴다
  (`.loop/rubrics/<이름>.md`). 매칭이 없거나 애매하면 사용자에게 어떤 rubric을 쓸지 묻는다.
- rubric 파일을 읽고, 기준 수와 게이트(frontmatter `gates`, 없으면 config 전역)를 파악한다.

## 1. Consult

`.loop/memory/INDEX.md`에서 작업과 관련된 카테고리·태그의 노트를 찾아 읽는다.
`verified: false` 노트는 가설로만 취급한다.

## 2. 마커 생성 (Stop gate 연동)

```bash
mkdir -p .loop/state && printf '%s | rubric=%s | started=%s\n' "<작업 한 줄>" "<rubric 이름>" "$(date +%F)" > .loop/state/current-task
```
이 마커가 있는 동안 세션 종료는 stop-gate에 차단된다 — 채점을 끝내기 전에 떠날 수 없다.

## 3. 작업 수행 (maker)

시작 전 기준점을 기록해 둔다: `BASE=$(git rev-parse HEAD)`.
작업을 수행하고 커밋은 아직 하지 않는다(워킹트리 상태로 채점).

## 4. Verifier 채점

Agent 도구로 `subagent_type: "loopcraft:verifier"` (fresh 서브에이전트, **fork 금지**)를 호출한다.
위임 프롬프트에 **다음만** 담는다 — 너의 추론·대화 내용·변명을 섞지 마라:

1. rubric 전문 (파일 내용 그대로)
2. 산출물: `git diff "$BASE"` 전문(길면 파일 경로 목록 + 변경 파일 절대경로) + 신규 파일 경로
3. 게이트를 이미 돌렸다면 그 출력

verifier의 Verdict에서 `결과:` 줄을 읽는다.

## 5. 판정 처리

- **FAIL** → "FAIL 사유 요약"만 근거로 수정하고 4로 돌아간다. 최대 `maxRetries`회(기본 3).
  초과 시 **에스컬레이션**: 마지막 Verdict를 사용자에게 보여주고 판단을 요청한다.
  중단하는 경우 STATE.md에 에스컬레이션 사유를 기록하고 마커를 삭제한다.
- **채점 불가 기준이 보고되면** → 작업과 별개로 rubric 개정이 필요하다는 뜻.
  완료 보고에 포함하고, `.loop/rubrics/<이름>.md` 수정을 제안한다 (스펙 §6).
- **PASS** → 6으로.

## 6. 게이트 → 커밋 → 정리

1. 게이트 실행(rubric frontmatter `gates` 우선, 없으면 config 전역). green 필수.
2. 커밋 — 메시지 말미에 트레일러 추가:
   ```
   Loop-Verified: <pass>/<total>
   ```
3. verdict 전문을 `.loop/journal/$(date +%F)-<작업슬러그>.md`에 저장한다 (gitignored).
4. 마커 삭제: `rm -f .loop/state/current-task`
5. 이 사이클에서 실패·발견이 있었으면 `/loopcraft:distill`을 이어서 수행한다.

## 완료 보고에 포함할 것

verdict 요약(N/M), 재시도 횟수, 커밋 해시, 채점 불가 기준(있으면), 증류된 노트(있으면).

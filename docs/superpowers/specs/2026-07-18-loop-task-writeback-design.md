# loop-task prompt-driven write-back

> 작성: 2026-07-18 · 상태: 승인됨 · 대상: loopcraft (issue #9, Phase 4) · §13 열린 질문 해소

## 배경 / 목표
지금 write-back(코멘트/PR)은 무인 러너 loop-run에만 있다. 프롬프트 구동 단건 작업 loop-task에도, 관련 이슈를 명시하면 결과를 그 이슈에 반영하고 싶다. 예: `/loop-task #123 로그인 버그 고쳐줘` → 통과·커밋 후 #123에 verdict 코멘트.

**비목표**: draft-pr(그건 loop-run 담당). 항목 id 자동 추론(명시적만). config.writeback 소비(그건 loop-run 큐 정책).

## 1. id 감지 (명시적, opt-in)
loop-task 인자 선두의 `#N`(GitHub) 또는 이슈 키(`ABC-123`) 토큰을 write-back 대상 id로 해석하고, 나머지를 작업 설명으로 쓴다. **id가 없으면 write-back 없음**(현행 동작 그대로).

## 2. 트리거
아래 둘 다 참일 때만 write-back(comment):
- 인자에 명시적 id가 있음, **그리고**
- `config.backlog.report`가 설정돼 있음(= 커맨드 소스 구성됨).
`config.backlog.writeback`은 참조하지 않는다(그건 loop-run의 큐 정책 — loop-task에선 명시적 id가 곧 이 작업의 opt-in). report 커맨드가 없으면 write-back 없음.

## 3. report 호출
`Loop-Verified` 커밋 직후(loop-task §6) `config.backlog.report`를 loop-run과 동일한 env 계약으로 1회 실행:
- `LOOP_ITEM_ID=<id>`, `LOOP_ITEM_REF`(선택), `LOOP_EVENT=verified`, `LOOP_WRITEBACK=comment`, `LOOP_VERDICT=<n/m>`, `LOOP_COMMIT=<sha>`, `LOOP_BRANCH=<현재 브랜치>`.
- **`title`/`body`는 넘기지 않는다.** **best-effort**: report가 실패(비정상 종료)해도 작업을 실패 처리하지 않고 완료 보고에 "report 실패"만 남긴다.
- **comment만.** draft-pr은 loop-run 전용(loop-task는 per-item 브랜치 모델이 아님).

## 4. 변경 파일
- `skills/loop-task/SKILL.md`: (a) 인자 선두 id 감지 + 작업 설명 분리, (b) §6(게이트→커밋) 직후 "id 있음 && report 설정됨 → report(verified, comment)" 단계 추가(best-effort), (c) 완료 보고에 write-back 결과 포함.
- README ×4: loop-task에 `#123`을 주면 통과 후 그 이슈에 결과를 코멘트한다는 한 줄.
- **새 .sh/테스트 없음**: `report`는 이미 구현·테스트됨(어댑터). docs rubric + 기존 스위트 회귀로 검증.

## 5. 에러 처리
report 실패 → best-effort(작업 실패 아님, 보고에 기록). id는 있는데 `config.backlog.report` 없음 → write-back 조용히 생략(현행 동작; 필요 시 "report 미설정" 한 줄 안내).

## 6. 하위호환
id 없으면 현행 loop-task 그대로. 완전 opt-in. 어댑터·config 변경 없음(기존 report 재사용).

## Acceptance
1. loop-task SKILL.md: 선두 id 감지 + 커밋 직후 조건부 report(comment, best-effort) + 보고 반영.
2. README ×4: loop-task write-back 한 줄.
3. `./tests/run.sh` green(회귀 — 새 실행 코드 없음).

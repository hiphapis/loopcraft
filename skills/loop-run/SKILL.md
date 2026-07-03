---
name: loop-run
description: backlog를 무인 순회하며 항목마다 loop-task 사이클(rubric·verifier·게이트·Loop-Verified 커밋)을 적용한다. 사용자가 자율 배치 실행을 명시적으로 개시할 때만 호출 — 개별 작업에는 loop-task를 직접 쓴다.
argument-hint: "[최대 항목 수 (기본 3)]"
---

# Loop-Run — backlog 자율 러너

`.loop/config.json`이 없으면 중단하고 `/loopcraft:loop-init`을 안내하라.

## 안전 계약 (어떤 경우에도 위반 금지)

- **main 병합·push 금지.** 커밋은 현재 브랜치까지가 끝이다. main 반영은 항상 사람이 한다.
- 현재 체크아웃이 main/master면 시작 전에 전용 브랜치를 만든다:
  `git checkout -b loop-run/$(date +%F)`. 워크트리·피처 브랜치면 그대로 진행.
- 항목당 재시도는 loop-task 규칙(maxRetries)을 따르고, **에스컬레이션된 항목이
  연속 `autonomy.maxConsecutiveFails`(기본 2)개면 러너 전체를 중단**한다
  (환경 문제일 가능성 — 계속 돌면 같은 실패만 쌓인다).
- 처리 항목 수 상한: 인자(기본 3). 상한 도달 시 정상 종료.

## 0. Run 시작

1. STATE.md·INDEX.md를 읽고(세션 주입분 포함) 관련 노트를 consult.
2. run 저널 생성: `.loop/journal/run-$(date +%F-%H%M).md`
   ```
   # Loop-Run <ISO 일시> | 브랜치: <branch> | 시작 HEAD: <sha>

   | # | 항목 | 분류 | 결과 | 커밋 |
   |---|------|------|------|------|
   ```

## 1. 항목 선별 (Triage)

`config.backlog.file`에서 `config.backlog.section` 섹션의 항목들을 읽고 3분류한다:

- **실행 가능**: 코드·문서 변경만으로 완결되고 외부 의존이 없다. 리포 안에서
  검증 가능한 것.
- **skip (부적합)**: 외부 프로비저닝(API 키·벤더 계약·DNS), 수동 QA(청취·육안),
  의사결정 대기, 장시간 리소스(대량 생성·Docker 빌드)가 필요한 것 —
  무인 실행 불가. run 저널에 `skip(사유)` 로 기록만 한다.
- **무시**: 취소선·Resolved 표기 등 이미 끝난 항목.

실행 가능 항목이 여럿이면 **가장 작고 되돌리기 쉬운 것부터**. 하나도 없으면
그 사실을 run 저널·STATE에 기록하고 종료한다 (빈손 종료도 정상 종료다).

## 2. 항목 실행 — loop-task 사이클 재사용

각 항목에 `/loopcraft:loop-task` 프로토콜(rubric 결정 → consult → 마커 →
maker → verifier → 게이트 → `Loop-Verified` 커밋 → verdict journal → 마커 삭제)을
그대로 적용한다. 무인 특칙 3가지:

1. **에스컬레이션 시 사용자에게 물을 수 없다** → 마지막 Verdict 요약을 run 저널에
   기록하고, 커밋 안 된 변경은 `git stash push -m "loop-run escalated: <항목>"`으로
   보존한 뒤, STATE '열린 질문'에 항목을 추가하고 마커를 삭제하고 다음 항목으로.
2. **테스트 파일이 필요한 작업** → 직접 작성하지 말고(테스트는 Codex 소유)
   구현 + 테스트 스펙(무엇을 검증할지) 기록까지 수행, run 저널에
   `Codex 후속 필요` 표기.
3. 항목 실행 중 실패·발견이 있으면 `/loopcraft:distill`을 그 자리에서 수행.

항목이 끝날 때마다 run 저널의 해당 행을 갱신한다 (결과: done/escalated, 커밋 sha).

## 3. Run 종료

1. STATE.md 갱신: 처리/skip/escalated 항목, 커밋 목록, Codex 후속 목록, 다음 실행 제안.
2. run 저널 말미에 합계 줄: `완료 n · skip n · escalated n · 커밋 n개`.
3. 최종 보고에 포함: 항목별 결과 표, 커밋 해시들, **"main 반영은 사용자 결정"** 명시,
   backlog 문서 갱신 제안(완료 항목의 취소선 처리는 사람 문서이므로 제안만).

---
name: distill
description: 실패·버그·예상 밖 동작·중요한 발견이 있을 때 이를 검증된 일반 규칙으로 증류해 .loop/memory/에 남긴다. 게이트(테스트·타입체크) 실패를 해결한 직후, verifier 채점에서 fail을 수정한 직후, 디버깅으로 원인을 규명한 직후에 호출. 단순 오타 수정 등 교훈이 없는 실패는 제외.
argument-hint: "[실패/발견 한 줄 요약]"
---

# Distill — 실패를 검증된 지식으로 증류

5단계를 순서대로 수행한다. 각 단계를 건너뛰지 말 것.

## 1. Fail — 원장 기록
`.loop/memory/LEDGER.md` 표에 행 추가: `| YYYY-MM-DD | <증상 한 줄> | fail | |`

## 2. Investigate — 원인 조사
증상이 아니라 원인을 찾는다. 관련 코드·로그·커밋을 확인하고 가설을 세운다.

## 3. Verify — 진단을 사실로 확정
가설을 재현 또는 반증으로 검증한다 (실패 재현 → 수정 적용 → 통과 확인이 최선).
검증에 성공하면 LEDGER 단계를 `verify`로. 검증 불가하면 노트에 `verified: false`로
기록하고 "가설"임을 본문에 명시한다.

## 4. Distill — 일반 규칙로 추상화
- **기존 노트 갱신을 새 노트 생성보다 우선한다.** `notes/`에서 관련 노트를 먼저 찾고
  (INDEX 카테고리 + grep), 있으면 그 노트를 갱신한다.
- 새 노트는 `notes/<kebab-slug>.md`:

```markdown
---
title: "<일반 규칙을 문장으로>"
tags: [<도메인 태그>]
category: debugging   # debugging | pattern | environment | decision
confidence: high      # high | medium | low
verified: true        # 3단계 통과 여부
created: YYYY-MM-DD
updated: YYYY-MM-DD
sources: ["commit:<sha>", "session:<날짜-id>"]
---
<환경 특이 사실과 일반 규칙을 구분해 서술.
"이 프로젝트에서 X였다"가 아니라 "조건 C에서는 Y가 된다. 이 프로젝트의 사례: X">
관련: [[다른-노트-슬러그]]
```

- 관련된 기존 노트에 `[[이 노트 슬러그]]` 역링크를 추가한다. 끊긴 링크는 허용
  (나중에 쓸 지식의 마커).
- `INDEX.md`의 해당 카테고리에 한 줄 추가하고, 상단 통계(노트 수·verified 비율·
  갱신일)를 갱신한다.
- LEDGER 해당 행: 단계를 `distilled`로, 노트 칸에 `[[슬러그]]` 기입.

## 5. Consult — 참조 확인
작성한 노트가 INDEX에서 도달 가능한지(카테고리 목차에 있는지) 확인한다.
다음 세션은 SessionStart 주입으로 이 노트의 존재를 알게 된다.

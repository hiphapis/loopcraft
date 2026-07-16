# STATE — 세션 인계

> 갱신: 2026-07-17

## 지금 하던 것
- README 이미지 + 설명 보강 (로고는 스킵하기로 결정).
- ✅ 히어로 `assets/loopcraft-hero.jpg` (1536×864, 16:9, JPEG q94, 287KB) — 4개 README 상단 배치.
- ✅ 동작 원리 다이어그램 `assets/loopcraft-how-it-works.svg` — 4개 README "How it works" 섹션에 `<img width=900>`로 삽입, 렌더 검증함.
- ✅ 4개 README(en/ko/ja/zh)에 새 섹션 2개 추가: "Why Loopcraft?"(문제의식·철학·대상), "How it works"(다이어그램 + 작업내/세션간 2가지 시간대 설명).
- ✅ README.ja.md 기존 오타 수정: "리포지토리에는푸시" 한글 혼입 → "プッシュ".

## 다음 단계
- (커밋 완료 후) 사용자 리뷰 → 원하면 push.
- 남은 아이디어: 라이트 테마에서 히어로 사각 경계 페이드 후처리(선택), 동작원리 SVG의 inject 라벨 미세 겹침(선택).

## 열린 질문
- (없음 — 로고 스킵 확정)

## 최근 결정
- 히어로: 후보 #2 채택 → 16:9 중앙 크롭. README 이미지는 `<p align="center"><img>` HTML 관용구 사용(마크다운으로는 정렬·너비 지정 불가 — GitHub 표준 방식).
- "동작 원리"는 AI 생성이 아니라 손수 만든 SVG(라벨 정확·벡터·plain-files). GitHub은 `<img src="*.svg">`로 SVG 인라인 렌더 지원 확인.
- 로고 제작 스킵.

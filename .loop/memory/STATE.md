# STATE — 세션 인계

> 갱신: 2026-07-17

## 지금 하던 것
- README 이미지 + 설명 보강 (로고는 스킵하기로 결정).
- ✅ 히어로 `assets/loopcraft-hero.jpg` (1536×864, 16:9, JPEG q94, 287KB) — 4개 README 상단 배치.
- ✅ 동작 원리 다이어그램 `assets/loopcraft-how-it-works.svg` — 4개 README "How it works" 섹션에 `<img width=900>`로 삽입, 렌더 검증함.
- ✅ 4개 README(en/ko/ja/zh)에 새 섹션 2개 추가: "Why Loopcraft?"(문제의식·철학·대상), "How it works"(다이어그램 + 작업내/세션간 2가지 시간대 설명).
- ✅ README.ja.md 기존 오타 수정: "리포지토리에는푸시" 한글 혼입 → "プッシュ".

## 다음 단계
- (없음 — push 완료)

## 열린 질문
- (없음)

## 최근 결정
- 히어로: 후보 #2 채택 → 16:9 중앙 크롭. README 이미지는 `<p align="center"><img>` HTML 관용구 사용(마크다운으로는 정렬·너비 지정 불가 — GitHub 표준 방식).
- 히어로 가장자리 페이드: alpha 페더로 투명 처리해 라이트(흰)·다크(#0d1117) 양쪽에서 사각 경계 제거. 포맷은 **WebP**(알파+120KB, jpg/png보다 가벼움) → `assets/loopcraft-hero.webp`. jpg/png 폐기.
- 동작원리 SVG `inject` 라벨을 화살표 왼쪽으로 이동(우측 정렬)해 곡선 겹침 해소.
- "동작 원리"는 손수 만든 SVG(라벨 정확·벡터·plain-files). GitHub `<img src="*.svg">` 인라인 렌더 확인.
- 로고 제작 스킵.

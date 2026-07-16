# STATE — 세션 인계

> 갱신: 2026-07-17

## 지금 하던 것
- README 콘텐츠·비주얼 보강 (로고 스킵).
- ✅ 히어로 `assets/loopcraft-hero.webp` (16:9, alpha 페더 페이드, 117KB) — 4개 README 상단. 페이드 폭은 **30×26px(얇게)** 적용(초기 120×110은 너무 넓다는 피드백 반영).
- ✅ 동작원리 다이어그램 `assets/loopcraft-how-it-works.svg` — How it works 섹션에 삽입, inject 라벨 겹침 수정 완료.
- ✅ 4개 README 섹션: "Why Loopcraft?", "How it works"(다이어그램), **"Concepts"(용어집: loop engineering 원리 + maker/verifier/rubric/gate/vault/distill/Loop-Verified 정의)**, **"Everything is markdown — Obsidian"(마크다운·그래프뷰·no lock-in)**.
- ✅ "Inspired by" 줄에 링크: Lance Martin → x.com/RLanceMartin/article/2064397389189071163 (사용자 지정), Karpathy → gist(karpathy/442a6bf...). Why Loopcraft? 말미에 Obsidian 소유권·투명성 문단 추가.

## 다음 단계
- (없음 — 커밋·push 예정/완료)

## 열린 질문
- 히어로 페이드 폭: 현재 A(30×26). 사용자가 원하면 B(55×48) 또는 더 얇게로 교체 가능(scratchpad에 fade_A/B 프리뷰 있음).

## 최근 결정
- README 이미지는 `<p align="center"><img>` HTML 관용구(GitHub 표준; 마크다운은 정렬·너비 불가).
- 히어로 가장자리: alpha 페더 투명 처리로 라이트/다크 양쪽 사각 경계 제거. 포맷 WebP(알파+경량). 폭 30×26px.
- 동작원리는 손수 만든 SVG(GitHub `<img src=*.svg>` 인라인 렌더 확인).
- Concepts 용어집 + Obsidian 섹션으로 "무엇을·왜·용어" 설명 강화.
- 로고 제작 스킵.

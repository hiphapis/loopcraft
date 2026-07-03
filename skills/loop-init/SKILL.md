---
name: loop-init
description: 프로젝트에 loopcraft를 온보딩한다 — 리포를 스캔해 게이트 명령을 탐지하고, 인터뷰로 backlog·rubric을 확정한 뒤 .loop/ 구조를 스캐폴딩한다. 프로젝트당 1회, 또는 설정 갱신 시 호출.
argument-hint: ""
---

# Loop-Init — 프로젝트 온보딩

`.loop/`가 이미 있으면 "갱신 모드"로 동작한다: 기존 값을 기본값으로 보여주고 바꿀 것만 묻는다.

## 1. 리포 스캔 (묻기 전에 스스로 찾는다)

- 게이트 후보: `package.json`의 scripts(typecheck/lint/test/build), `Makefile`,
  `pyproject.toml` 등에서 검출. 검출 결과를 제안 기본값으로.
- backlog 후보: `docs/` 아래 TODO·backlog·status 류 문서, README의 로드맵 섹션.
- 작업 유형: 리포 구성(코드 언어, docs 비중)으로 rubric 초안 종류를 정한다
  (기본: `code` + `docs` 2종).

## 2. 인터뷰 (AskUserQuestion — 한 번에 하나씩)

① 게이트 명령 확정 ② backlog 파일·섹션 ③ rubric 초안 검토 — 각 기준을 보여주고
프로젝트에 맞게 다듬는다. **모든 기준은 "검증 방법 + 통과 조건"이 있어야 한다**고
안내하고, 채점 불가능한 기준("코드가 깔끔하다")은 받아들이지 말고 검증 가능한
형태로 재작성하도록 돕는다.

## 3. 스캐폴딩

- `.loop/config.json` — 인터뷰 결과로. `rubrics`는 `[{"glob": "...", "rubric": "code"}, ...]`.
- `.loop/memory/INDEX.md`·`STATE.md`·`LEDGER.md` — 아래 템플릿 그대로(날짜만 오늘로):

INDEX.md: `# Memory Index\n\n> 노트 0 · verified 0% · 갱신: <오늘>\n\n## debugging\n\n## pattern\n\n## environment\n\n## decision`
STATE.md: `# STATE — 세션 인계\n\n> 갱신: <오늘>\n\n## 지금 하던 것\n- (없음)\n\n## 다음 단계\n- (없음)\n\n## 열린 질문\n- (없음)\n\n## 최근 결정\n- (없음)`
LEDGER.md: `# LEDGER — 실패 원장\n\n> 단계: fail → investigate → verify → distilled\n\n| 날짜 | 증상 | 단계 | 노트 |\n|------|------|------|------|`

- `.loop/rubrics/<이름>.md` — 인터뷰에서 확정된 기준으로. frontmatter는
  `name`(필수), `gates`·`max_retries`(선택 — config 오버라이드시만).
- `.gitignore`에 `.loop/journal/`·`.loop/state/` 2줄 추가(중복 추가 금지 — 있으면 스킵).

## 4. 마무리

- 프로젝트에 CLAUDE.md(또는 AGENTS.md)가 있으면 loopcraft 한 줄 인덱스 추가를 제안.
- 생성 파일 전체를 보여주고 커밋을 제안한다 (`feat(loop): loopcraft 온보딩 — .loop 스캐폴딩`).
- `.loop/memory/`는 커밋 대상임을 안내 (vault는 리포와 함께 이동).

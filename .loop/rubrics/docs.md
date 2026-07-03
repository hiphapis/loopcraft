---
name: docs
---

# docs — 마크다운 스킬 rubric

대상: `skills/**/SKILL.md`, `agents/*.md`, `README*.md` 등 저장소 내 모든 `.md` 파일 변경.

## 기준

1. **frontmatter 완전성**: `SKILL.md`/`agents/*.md` 변경 시 YAML frontmatter에 `name`과 `description` 키가 존재하고 값이 비어있지 않다 (frontmatter가 없는 순수 문서, 예: README*.md, 는 이 기준에서 제외).
   - 검증 방법: 파일 상단 `---`~`---` 블록을 추출해 `name:`/`description:` 라인 확인.
   - 통과 조건: 두 키 모두 존재 AND 값 길이 > 0.

2. **스킬 파일명 규칙**: `skills/` 아래 각 디렉터리는 정확히 `SKILL.md` 파일을 보유한다.
   - 검증 방법: `find skills -mindepth 1 -maxdepth 1 -type d` 각 디렉터리에 `SKILL.md` 존재 확인.
   - 통과 조건: 모든 스킬 디렉터리에 `SKILL.md` 정확히 1개.

3. **README 동기화**: `skills/` 디렉터리가 추가·변경됐다면 그 스킬명이 `README.md`의 "What you get" 표에 `/loopcraft:<이름>` 형태로 최소 1회 언급된다.
   - 검증 방법: `ls skills`와 `grep -oE '/loopcraft:[a-z-]+' README.md` 비교.
   - 통과 조건: 모든 `skills/*` 디렉터리명이 README.md에 언급됨 (기존 스킬 이름 변경 없이 문서만 고친 경우는 자동 충족).

4. **링크 무결성**: 마크다운 상대경로 링크(`[텍스트](경로)`, http(s) 제외)가 가리키는 파일이 실제로 존재한다.
   - 검증 방법: `grep -oE '\]\([^)]+\)'`로 링크 추출 후 각 경로의 파일 존재 여부 확인.
   - 통과 조건: 깨진 상대경로 링크 없음.

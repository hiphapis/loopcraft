# Pluggable test author (`config.tests.author`)

> 작성: 2026-07-18 · 상태: 승인됨 · 대상: loopcraft (issue #7, Phase 4)

## 배경 / 목표
loop-run 규칙 #2는 테스트 작성을 "Codex가 있으면 Codex, 없으면 컨텍스트-격리 서브에이전트"로 고정한다(v0.4.1). 이를 **사용자가 loop-init에서 고르는 플러그블 test author**로 확장한다 — 특히 마켓플레이스 플러그인 `codex @ openai-codex`도 선택지로.

**비목표**: 실제 Codex 프롬프트 튜닝(Codex/plugin 소관), 테스트 작성 그 자체의 품질 보증(독립 verifier가 별도로 채점).

## 세 메커니즘 (모두 같은 Codex를 두 프론트엔드로, + 순수 Claude)
- **codex-cli** — OpenAI Codex CLI를 셸로 호출: `codex exec "<프롬프트>"`(비대화, headless 가능). `codex` 설치·로그인 필요.
- **codex-plugin** — 마켓플레이스 `codex @ openai-codex`(codex-cli-runtime 등 스킬/에이전트)에 위임. **Claude Code 세션 + 플러그인 설치 필요**(순수 headless 불가).
- **subagent** — 컨텍스트-격리 Claude 서브에이전트(현행 폴백). 항상 동작.

## 균일 계약 (핵심)
어느 author든 loop-run의 maker는 **behavior 스펙 + 테스트 하네스 관례만** 넘긴다 — maker의 추론/구현 diff는 절대 넘기지 않는다. "무엇을 검증할지"는 author에 무관하게 동일; 독립성(구현이 아니라 동작을 검증)을 보존한다.

## config 스키마
```json
"tests": { "author": "codex-cli" | "codex-plugin" | "subagent" }
```
- `tests.author` 없으면 **`subagent`**(항상 동작). 선택 override: `tests.codexCmd`(기본 `codex exec`).
- 하위호환: 기존 config는 `tests` 없음 → subagent(= 현행 폴백 동작 유지).

## loop-run 규칙 #2 (갱신)
테스트가 필요한 작업이면 `config.tests.author`에 따라 **독립적으로** 작성:
- `codex-cli` → `${tests.codexCmd:-codex exec} "<behavior-spec 프롬프트>"`.
- `codex-plugin` → 마켓플레이스 codex 플러그인의 런타임 스킬/에이전트에 behavior-spec 위임(세션 필요).
- `subagent`(기본) → 컨텍스트-격리 서브에이전트, behavior-spec only.
- **폴백**: 선택한 author가 불가(CLI 미설치 / 플러그인 세션 밖)하거나 실패하면 `subagent`로 폴백하고 run 저널에 기록. 프롬프트는 언제나 behavior-spec only.

## loop-init
인터뷰에 질문 추가: **"테스트를 누가 작성하나요?"** → codex-cli / codex-plugin / subagent → `tests.author` 기록(사용자 언어로 렌더, 값은 영어 enum).
- 안내: codex-cli는 `codex` 설치·로그인([Codex CLI](https://github.com/openai/codex)); codex-plugin은 `/plugin install codex@openai-codex`; subagent는 준비 불필요.
- 탐지 제안: `codex`가 PATH에 있으면 codex-cli를 기본 제안, 없으면 subagent.

## README ×4
기존 "Test authoring" 단락 갱신: author가 `config.tests.author`로 **선택**(codex-cli / codex-plugin / subagent), 기본 subagent, 폴백 subagent. Codex CLI + 마켓플레이스 플러그인 링크.

## 에러 처리
선택 author 불가/실패 → subagent 폴백(경고·저널). subagent도 실패면 그 항목은 loop-task 규칙대로 처리(테스트 미충족 → verifier/게이트 fail → 재시도/에스컬레이션).

## 검증
#7은 **지시문(loop-run/loop-init SKILL.md) + config 필드 + README**뿐 — 새 실행 코드(.sh) 없음. **docs rubric**(변경 .md의 frontmatter·링크 무결성 등) + 기존 스위트 회귀 green + grep 정합성으로 검증. 별도 bash 유닛테스트 대상 없음(실행 브랜치 없음).

## Acceptance
1. loop-run SKILL.md 규칙 #2가 `config.tests.author`(codex-cli/codex-plugin/subagent) + subagent 폴백 + 균일 behavior-only 계약을 명시.
2. loop-init에 test-author 질문 + `tests.author` 기록 + 도구별 안내/탐지.
3. README ×4 "Test authoring" 갱신(선택·기본·폴백·링크).
4. config 스키마에 `tests.author`(없으면 subagent) 문서화.
5. `./tests/run.sh` green(회귀).

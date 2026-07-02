# Loopcraft

Loop engineering plugin for Claude Code. Lance Martin의 loop engineering
(rubric + 독립 verifier self-correction, 5단계 memory 프로토콜)을 어느
프로젝트에나 설치 가능한 형태로 패키징한다.

## Phase 1 (현재)
- SessionStart: `.loop/memory/` INDEX·STATE 주입 + LEDGER 미해결 리마인더
- Stop: loop-task 마커/STATE 미갱신 차단 (세션당 1회, `LOOP_DISABLE=1`로 무력화)
- PreCompact: STATE 갱신 리마인더
- `/loopcraft:distill`: 실패 증류 5단계 프로토콜

## 설치 (개발 중)
claude --plugin-dir ~/Work/loopcraft

설계 스펙: OurStory `docs/superpowers/specs/2026-07-03-loopcraft-design.md`

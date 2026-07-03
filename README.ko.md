# Loopcraft

[English](README.md) | **한국어** | [日本語](README.ja.md) | [中文](README.zh-CN.md)

[Claude Code](https://claude.com/claude-code)용 루프 엔지니어링 플러그인 — 점점 길어지는 프롬프트로 모델을 조종하는 대신, 모델이 **환경 피드백으로 스스로 교정**하고 **세션을 넘어 메모리를 축적**하는 루프를 설계합니다.

Lance Martin의 loop engineering과 Andrej Karpathy의 LLM Wiki 패턴에서 영감을 받았습니다: 자기개선은 모델이 아니라 *시스템*의 속성입니다. Loopcraft는 그 시스템을 설치 가능한 플러그인으로 만듭니다.

## 제공 기능 (Phase 1 + 2)

| 구성요소 | 역할 |
|-----------|--------------|
| **SessionStart hook** | 새 세션마다 프로젝트 메모리(`INDEX.md` + `STATE.md`)를 자동 주입하고, 원장의 미해결 실패를 리마인드합니다. Claude가 과거 세션이 배운 것을 이미 아는 상태로 시작합니다. |
| **Stop gate hook** | *Write before walking away*: 코드는 바뀌었는데 `STATE.md`가 갱신되지 않았으면 세션 종료를 1회 차단하고 기록을 요구합니다. loop task 마커가 남아 있으면(검증 미완료) 역시 차단. 세션당 최대 1회만 차단 — 갇힐 일은 없습니다. |
| **PreCompact hook** | 컨텍스트 요약 직전, 진행 상황을 `STATE.md`에 먼저 기록하도록 리마인드해 요약으로 유실되는 것을 막습니다. |
| **`/loopcraft:distill` 스킬** | 실패를 지식으로 바꾸는 5단계 프로토콜: **Fail → Investigate → Verify → Distill → Consult**. 실패가 *검증된* 일반 규칙이 되어 vault에 남습니다 — 기존 노트 갱신을 우선해 중복이 생기지 않습니다. |
| **Obsidian 호환 vault** | `.loop/memory/`는 YAML frontmatter와 `[[위키링크]]`를 쓰는 순수 마크다운입니다. Obsidian vault로 열면 지식 그래프가 자라는 것을 볼 수 있습니다. 앱 의존성 없음 — 루프에 필요한 건 파일뿐입니다. |
| **`verifier` 서브에이전트** | 당신의 rubric에 따라 산출물을 독립적으로 채점하는 심사자입니다. maker의 추론은 보지 않고 결과물과 기준만 봅니다. maker 바이어스를 원천 차단합니다. |
| **`/loopcraft:loop-task` 스킬** | Maker → verifier → 재시도 → 게이트 → 커밋 순환: 작업 설명을 제출하면 판정 요약을 받고, 통과 시 커밋 트레일러에 `Loop-Verified: n/m`을 자동 기록합니다. 감사 추적이 남는 작업입니다. |
| **`/loopcraft:loop-init` 스킬** | 리포를 스캔하고 당신과 인터뷰해서 `.loop/`를 설정된 게이트와 rubric 초안으로 스캐폴딩합니다. 한 명령으로 프로젝트 온보딩 완료. |

런타임 의존성 제로: `bash + git + grep/sed/awk`. 탈출구: `LOOP_DISABLE=1`로 모든 hook 무력화.

## 설치

**방법 A — 마켓플레이스 (권장):**

```
/plugin marketplace add hiphapis/loopcraft
/plugin install loopcraft@loopcraft
```

**방법 B — 로컬 클론 (개발용):**

```bash
git clone https://github.com/hiphapis/loopcraft.git
claude --plugin-dir ./loopcraft
```

## 프로젝트 셋업

**권장: `/loopcraft:loop-init` 사용**

리포 루트에서 다음을 실행합니다:

```
/loopcraft:loop-init
```

스킬이 프로젝트 구조를 스캔하고 게이트·rubric에 대해 인터뷰한 뒤 `.loop/config.json`과 `.loop/rubrics/`의 rubric 초안을 자동 생성합니다. 수동 편집 불필요합니다.

### 수동 셋업 (선택)

수동으로 `.loop/`를 스캐폴딩하려면 리포 루트에서 1회 실행:

```bash
mkdir -p .loop/memory/notes .loop/rubrics
cat > .loop/config.json <<'EOF'
{
  "gates": ["npm run typecheck", "npm run lint", "npm test"],
  "backlog": { "file": "docs/backlog.md", "section": "Ready to Execute" },
  "rubrics": [],
  "maxRetries": 3,
  "autonomy": { "commit": true, "mainMerge": false, "maxConsecutiveFails": 2 }
}
EOF
printf '# Memory Index\n\n> 노트 0 · verified 0%% · 갱신: YYYY-MM-DD\n\n## debugging\n\n## pattern\n\n## environment\n\n## decision\n' > .loop/memory/INDEX.md
printf '# STATE — 세션 인계\n\n## 지금 하던 것\n- (없음)\n\n## 다음 단계\n- (없음)\n\n## 열린 질문\n- (없음)\n' > .loop/memory/STATE.md
printf '# LEDGER — 실패 원장\n\n> 단계: fail → investigate → verify → distilled\n\n| 날짜 | 증상 | 단계 | 노트 |\n|------|------|------|------|\n' > .loop/memory/LEDGER.md
printf '.loop/journal/\n.loop/state/\n' >> .gitignore
```

`gates`는 프로젝트의 실제 명령으로 바꾸세요. `.loop/`는 커밋합니다 — vault는 리포와 함께 이동하도록 설계되어 워크트리·다른 머신에서도 그대로 이어집니다.

## 사용법

**평소 세션** — 할 일이 없습니다. SessionStart hook이 `INDEX.md`와 `STATE.md`를 자동 주입하고, Claude가 축적된 지식을 참조한 뒤 작업을 시작합니다.

**뭔가 실패했을 때** (테스트, 빌드, 잘못된 가정):

```
/loopcraft:distill ffmpeg burn-in 자막이 Homebrew 빌드에서 안 보임 (libass 미포함)
```

스킬이 원장 기록 → 원인 조사 → **재현·반증으로 진단 검증** → 일반 규칙로 증류(frontmatter의 `verified: true/false`가 가설과 사실을 구분) → vault 연결까지 안내합니다.

**감사 추적이 필요한 작업** — loop-task로 verifier와 게이트를 통과시킵니다:

```
/loopcraft:loop-task SQL injection 취약점 제거를 위해 migration sanitization 리팩토링
```

스킬이 작업을 제출하고 verifier의 판정 요약을 기다린 뒤, 통과하면 커밋 트레일러에 `Loop-Verified: n/m`을 기록합니다. Rubric은 `.loop/rubrics/`에서 관리되며, 각 rubric은 검증 방법과 통과 조건을 명시해야 합니다.

**세션을 끝낼 때** — 코드를 바꿨는데 `STATE.md`를 갱신하지 않았으면 Stop gate가 1회 차단하며 무엇을 기록할지 알려줍니다. STATE를 갱신하고 깔끔하게 끝내면, 다음 세션이 정확히 그 지점에서 이어집니다.

**성장 관찰** — Obsidian으로 `.loop/memory/`를 열어 그래프 뷰를 보거나:

```bash
git log --oneline -- .loop/memory/   # 루프가 언제 무엇을 배웠는지
```

## Vault 포맷

```
.loop/
├── config.json          # 게이트·backlog 소스·재시도 상한·자율 권한
├── memory/              # 리포에 커밋
│   ├── INDEX.md         # 목차(MOC) + 통계 (노트 수, verified 비율)
│   ├── STATE.md         # 세션 인계: 하던 것 / 다음 단계 / 열린 질문
│   ├── LEDGER.md        # 실패 원장: fail → investigate → verify → distilled
│   └── notes/*.md       # 증류된 규칙 (YAML frontmatter + [[위키링크]])
├── journal/             # 실행 로그 — gitignore
└── state/               # 휘발성 세션 마커 — gitignore
```

노트 frontmatter: `title / tags / category (debugging|pattern|environment|decision) / confidence / verified / created / updated / sources`.

## 로드맵

- **Phase 1 — Memory** ✅: hooks, 증류 프로토콜, vault.
- **Phase 2 — Self-correction** (현재 릴리스): 검증 가능한 rubric, maker의 추론을 보지 않고 산출물만 채점하는 독립 verifier 서브에이전트, `/loop-task` 자기교정 사이클, `/loop-init` 온보딩 인터뷰.
- **Phase 3 — 자율 러너**: `/loop-run`이 backlog를 무인 순회 — 작업 → 검증 → 게이트 → 커밋 → 증류. 커밋은 워크트리까지만, main 병합은 항상 사람이 결정합니다.

## 요구사항

- 플러그인을 지원하는 Claude Code
- `bash`, `git` (macOS / Linux)

## 테스트

```bash
./tests/run.sh   # 26케이스: hook 계약·새니타이즈·엣지 케이스
```

## 라이선스

MIT

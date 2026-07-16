<p align="center">
  <img src="assets/loopcraft-hero.webp" alt="Loopcraft — 스스로 교정하는 루프와 세션을 넘어 유지되는 메모리" width="880">
</p>

# Loopcraft

[English](README.md) | **한국어** | [日本語](README.ja.md) | [中文](README.zh-CN.md)

[Claude Code](https://claude.com/claude-code)용 루프 엔지니어링 플러그인 — 점점 길어지는 프롬프트로 모델을 조종하는 대신, 모델이 **환경 피드백으로 스스로 교정**하고 **세션을 넘어 메모리를 축적**하는 루프를 설계합니다.

[Lance Martin의 loop engineering](https://x.com/RLanceMartin/article/2064397389189071163)과 [Andrej Karpathy의 LLM Wiki 패턴](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)에서 영감을 받았습니다: 자기개선은 모델이 아니라 *시스템*의 속성입니다. Loopcraft는 그 시스템을 설치 가능한 플러그인으로 만듭니다.

## 왜 Loopcraft인가?

Claude Code 세션은 매번 백지에서 시작합니다. 지난번에 쌓아 둔 맥락 — 그 테스트가 왜 불안정했는지, 이미 시도했다 접은 리팩토링, 이 코드베이스의 특이한 점 — 은 세션이 끝나거나 컨텍스트가 압축되는 순간 사라집니다. 흔한 대응은 프롬프트에 더 많이 채워 넣는 것입니다: 더 긴 `CLAUDE.md`, 더 많은 상시 지시. 하지만 점점 길어지는 프롬프트로 모델을 조종하는 방식은 확장되지 않고, 어제 한 일을 잊는 것도 자기 산출물을 후하게 채점하는 것도 막지 못합니다.

루프 엔지니어링은 다른 입장을 취합니다: **자기개선은 모델이 아니라 시스템의 속성이다.** 더 큰 프롬프트 대신 루프를 만듭니다 — 모델이 행동하고, *환경*이 되받아치고(테스트, 독립 채점자), 모델이 교정하고, 배운 것은 다음 세션이 무엇을 하기 전에 먼저 읽는 지속적 메모리에 기록됩니다. 모델이 더 똑똑해질 필요는 없습니다 — 모델을 둘러싼 시스템이 기억하고 검증하면 됩니다.

Loopcraft는 바로 그 시스템을 설치 가능한 플러그인으로 만든 것입니다. 다음과 같을 때 쓰세요:

- 실제 프로젝트를 **여러 세션에 걸쳐** 진행하며 같은 맥락을 매번 다시 설명하고 있을 때;
- 모델의 "괜찮아 보인다"를 믿는 대신 **명시적 기준으로 검증된** 작업을 원할 때;
- Claude를 **무인으로** 돌리면서 모든 결과가 `main`에 닿기 전에 게이트를 통과하고 감사 가능하길 원할 때;
- 모델이 지난주에 이미 겪고 해결한 **실수를 또 반복**하는 데 지쳤을 때.

그리고 vault가 숨겨진 데이터베이스가 아니라 순수 마크다운이기 때문에, 그 메모리는 온전히 당신 것입니다: Obsidian을 `.loop/memory/`로 향하게 해 지식 그래프가 자라는 것을 지켜보거나, 터미널에서 grep하거나, 그냥 PR에서 읽으면 됩니다. 시스템이 배운 모든 것을 눈으로 보고 손으로 고칠 수 있습니다.

<p align="center">
  <img src="assets/loopcraft-graph.webp" alt="실제 Loopcraft vault의 Obsidian 그래프 뷰 — STATE·INDEX·LEDGER 허브가 증류된 노트·태그와 연결된 모습" width="640"><br>
  <sub><i>실제 <code>.loop/memory</code> vault의 Obsidian 그래프 뷰 — STATE / INDEX / LEDGER 허브가 증류된 노트·태그와 연결된 모습.</i></sub>
</p>

## 동작 원리

<p align="center">
  <img src="assets/loopcraft-how-it-works.svg" alt="Loopcraft 동작 원리 — 메모리 vault가 SessionStart로 주입되어 loop-task → verifier → gate → commit 사이클이 시작되고, 검증 실패 시 재시도하며, 증류된 실패는 vault로 되돌아가고, Stop gate와 PreCompact hook이 세션을 지킨다" width="900">
</p>

루프는 두 시간대에서 닫힙니다:

- **작업 안에서** — `loop-task`는 당신의 작업을 독립 `verifier`에게 넘깁니다. verifier는 rubric에 따라 산출물과 기준만 보고 채점합니다 — maker의 추론은 절대 보지 않으므로 설득해서 통과시킬 수 없습니다. 실패하면 maker가 판정을 받아 `maxRetries`까지 재시도합니다. 통과하면 실제 게이트(테스트·타입체크)를 통과한 뒤 `Loop-Verified: n/m`이 찍힌 커밋으로 남습니다.
- **세션을 가로질러** — `.loop/memory` vault는 리포와 함께 이동합니다. `SessionStart`가 이를 주입해 Claude는 과거 세션이 배운 것을 이미 아는 상태로 시작하고, 무언가 실패하면 `distill`이 그것을 *검증된* 재사용 규칙으로 바꾸며, Stop gate와 PreCompact hook이 세션이 끝나거나 컨텍스트가 요약돼 사라지기 전에 진행 상황을 반드시 기록하게 합니다. 아무것도 처음부터 다시 배우지 않습니다.

## 개념 (Concepts)

**루프 엔지니어링(loop engineering)** 이 모든 것의 바탕이 되는 발상입니다: 점점 더 큰 프롬프트를 손으로 다듬는 대신, 모델이 도는 *루프* 자체를 설계해 결과를 개선합니다 — 행동하고, 환경에서 피드백을 받고, 교정하고, 배운 것을 기록한다. 지렛대의 받침점이 모델의 가중치에서 그것을 둘러싼 시스템(메모리·검증·게이트)으로 옮겨집니다. 좋은 루프 안의 약한 모델이, 메모리도 검증도 없는 강한 모델을 이깁니다. (이 관점은 Lance Martin의 loop/context engineering과 Andrej Karpathy의 LLM Wiki 패턴에 기대고 있습니다.)

이 README가 쓰는 나머지 용어:

- **Maker(메이커)** — `loop-task`에서 작업을 만들어내는 주체, 즉 당신의 요청에 따라 움직이는 Claude입니다. maker는 자기 자신을 채점하지 않습니다.
- **Verifier(검증자)** — maker의 산출물을 rubric에 따라 채점하는 독립 서브에이전트입니다. 산출물과 기준만 볼 뿐 maker의 추론은 절대 보지 않으므로 설득당해 통과시킬 수 없습니다. (`agents/verifier.md`)
- **Rubric(루브릭)** — `.loop/rubrics/`에 있는 작은 마크다운 파일로, 특정 종류의 작업에 대해 통과/실패 기준과 각 기준을 *어떻게* 검증하는지(실행할 명령, 확인할 파일)를 선언합니다. verifier가 채점하는 계약서입니다. 예: `code` rubric은 "테스트 통과", "비밀정보 미포함", "공개 함수 문서화"를 요구할 수 있습니다.
- **Gate(게이트)** — 커밋 전에 반드시 0으로 종료돼야 하는, 프로젝트의 실제 명령(`npm test`, 타입체크, `./tests/run.sh`)입니다. rubric이 품질을 판단한다면, gate는 실제로 돌아가는지를 강제합니다.
- **Vault(볼트)** — `.loop/memory/`, 리포와 함께 이동하는 순수 마크다운 저장소: `INDEX.md`(목차+통계), `STATE.md`(세션 인계), `LEDGER.md`(실패 원장), `notes/`(증류된 규칙).
- **Distill(증류)** — 실패를 두 번 배우는 대신 vault의 *검증된* 재사용 노트로 바꾸는 5단계 프로토콜(Fail → Investigate → Verify → Distill → Consult).
- **Loop-Verified: n/m** — `loop-task`가 커밋 트레일러에 찍는 표식: 독립 verifier 기준 m개 중 n개 충족. 당신의 감사 추적입니다.

## 제공 기능

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
| **`/loopcraft:loop-run` 스킬** | backlog를 무인으로 순회 — 항목 선별, loop-task 사이클 실행, 게이트 통과, 커밋을 모두 자동화합니다. 모든 커밋은 워크트리까지만, main 병합은 항상 당신의 결정입니다 — 시스템은 실행만 하고 절대 리포에 푸시하지 않습니다. |

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

**자율 backlog 순회** — 시스템이 밤새 일하도록 맡기세요:

```
/loopcraft:loop-run 3
```

백그라운드 세션에서 backlog 항목을 자동으로 선별해 loop-task 사이클을 실행하고, 게이트 통과 후 워크트리에 커밋합니다. 아침에 실행 저널(`.loop/journal/run-*.md`)과 Loop-Verified 커밋을 검토해서 마음에 드는 것만 main에 cherry-pick하거나 나머지는 버립니다. 시스템은 절대 병합하지 않고, 모든 인간의 게이트키핑이 그대로 유지됩니다.

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

## 모든 것은 마크다운 — Obsidian에서 열어보세요

vault에는 데이터베이스도, 앱 의존성도 없습니다. 모든 노트는 YAML frontmatter와 `[[위키링크]]`를 쓰는 순수 마크다운이라, 루프가 읽는 바로 그 파일을 당신도 읽고 grep하고 diff하고 손으로 고칠 수 있습니다.

Obsidian을 `.loop/memory/`로 향하게 하면 살아 있는 vault가 됩니다: 그래프 뷰로 증류된 규칙들이 어떻게 연결되는지 보이고, 백링크로 관련 실패가 드러나며, frontmatter(`category`, `verified`, `confidence`)가 검색 가능한 메타데이터가 됩니다. 루프가 Obsidian을 *요구*하는 건 전혀 아닙니다 — 시스템이 무엇을 배웠는지 *보기에* 좋은 방법일 뿐입니다. 터미널이 편하다면? `git log -- .loop/memory/`로 루프가 언제 무엇을 배웠는지 알 수 있습니다.

## 로드맵

- **Phase 1 — Memory** ✅: hooks, 증류 프로토콜, vault.
- **Phase 2 — Self-correction** ✅: 검증 가능한 rubric, maker의 추론을 보지 않고 산출물만 채점하는 독립 verifier 서브에이전트, `/loop-task` 자기교정 사이클, `/loop-init` 온보딩 인터뷰.
- **Phase 3 — 자율 러너** (현재 릴리스): `/loop-run`이 backlog를 무인 순회 — 작업 → 검증 → 게이트 → 커밋 → 증류. 커밋은 워크트리까지만, main 병합은 항상 사람이 결정합니다.

## 요구사항

- 플러그인을 지원하는 Claude Code
- `bash`, `git` (macOS / Linux)

## 테스트

```bash
./tests/run.sh   # 26케이스: hook 계약·새니타이즈·엣지 케이스
```

## 라이선스

MIT

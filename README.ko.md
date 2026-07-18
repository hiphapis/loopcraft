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

그리고 이는 백로그 전체로 확장됩니다: **`loop-run`**은 동일한 작업 루프를 각 항목에 적용합니다 — 플러그블 소스(file / GitHub / Jira)에서 읽어와 댓글이나 draft PR로 다시 기록하며 — 무인으로 실행되고, 기본 브랜치로의 병합은 항상 당신의 결정으로 남습니다.

<p align="center">
  <img src="assets/loopcraft-autonomous-runner.svg" alt="자율 러너 — loop-run이 플러그블 소스(file / GitHub / Jira)에서 backlog를 읽어, 항목별 loop/<id> 브랜치에서 loop-task 사이클을 실행하고, Closes #<id>가 포함된 댓글이나 draft PR로 write-back한 뒤 사람이 검토하고 병합합니다; loop-run은 기본 브랜치를 절대 병합하지 않습니다" width="900">
</p>

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
- **Backlog 소스** — `loop-run`이 작업 큐를 읽어오는 곳: 문서 섹션(`file`, 기본값) 또는 `loop-init`에서 연결하는 외부 시스템(`github` / `jira` / `command`).
- **Adapter(어댑터)** — 하나의 provider에 대한 `list`/`report` 계약을 구현하는 작은 스크립트(예: `.loop/adapters/github.sh`). 코어는 vendor-neutral을 유지하며, `gh`/`jira`가 호출되는 곳은 어댑터뿐입니다. 새 provider를 위한 템플릿으로 복사해 쓰세요.
- **Write-back** — `loop-run`이 소스에 결과를 반영하는 방식: `none`, 판정 `comment`, 또는 병합 시 항목이 자동으로 닫히도록 `Closes #<id>`를 링크하는 `draft-pr`.

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

## 실제 동작 예시

*`loop-task` 사이클을 예시로 보여줍니다. rubric과 verdict는 가독성을 위해 옮겼고, 형식·기준은 loopcraft의 실제 것을 따릅니다 — 다만 아래 실행 자체는 대표 예시이지 실제 로그는 아닙니다.*

hook 스크립트에 새 분기를 추가한다고 해봅시다. 바로 커밋하는 대신 루프에 태웁니다:

```
/loopcraft:loop-task Add a LOOP_DISABLE short-circuit to the SessionStart hook
```

`loop-task`는 변경된 파일(`hooks/scripts/*.sh`)을 **`code`** rubric에 매칭합니다 — 각 기준마다 검증 방법이 선언된 5개 기준:

```
1. 게이트 통과       — ./tests/run.sh 종료 코드 0, `not ok` 라인 없음
2. 안전 옵션 선언    — 변경 스크립트에 `set -euo pipefail`(최소 `set -u`) 선언
3. 변수 인용         — 경로·사용자 입력 변수를 "$VAR"로 확장
4. 테스트 동반       — 새 분기마다 tests/run.sh에 대응 assert_* 추가
5. 실행 권한 유지     — hooks/scripts/ 아래 파일은 755 이상 유지
```

maker가 작업을 마치면, diff와 rubric만 — 자기 추론은 절대 빼고 — 독립 `verifier`에 넘깁니다. 첫 번째 채점:

```
## Verdict

| # | 기준 | 판정 | 증거 |
|---|------|------|------|
| 1 | 게이트 통과 | pass | ./tests/run.sh → 종료 0, `not ok` 0개 |
| 2 | 안전 옵션 선언 | pass | 2번째 줄: `set -euo pipefail` |
| 3 | 변수 인용 | pass | diff에 `"$LOOP_DISABLE"`만 추가 |
| 4 | 테스트 동반 | fail | 새 early-return 분기, tests/run.sh diff에 대응 assert_* 없음 |
| 5 | 실행 권한 유지 | pass | 모드 755 그대로 |

**채점 불가 기준**: 없음
**결과**: FAIL (4/5)
**FAIL 사유 요약**: #4 — 새 disable 분기에 회귀 테스트가 없음.
```

verifier는 maker의 추론을 본 적이 없으므로 "당연히 잘 됩니다"는 통하지 않습니다 — 오직 빠진 테스트만 문제됩니다. maker는 그 FAIL 사유만 받아 `assert_*` 케이스를 추가하고 다시 제출합니다. 두 번째 채점:

```
**결과**: PASS (5/5)
```

이제 실제 게이트가 돌아 green이 되고, 작업은 verdict가 커밋에 새겨진 채 안착합니다:

```
$ git log -1 --format='%s%n%n%b'
Add LOOP_DISABLE short-circuit to SessionStart hook

Loop-Verified: 5/5
```

이 `Loop-Verified: 5/5` 트레일러가 감사 추적입니다: 5개 기준 전부 충족, 설득당하지 않는 채점자의 서명.

> **비용.** 시도마다 독립 채점 패스가 1회 추가되고, FAIL이면 maker → verifier 라운드를 한 번 더 돕니다(`maxRetries`까지). 이 오버헤드가 바로 그 *메커니즘*입니다 — 그래서 `loop-task`는 한 줄 수정이나 열린 탐색이 아니라 비자명하고 검증 가능한 작업을 위한 것입니다. 그런 작업은 그냥 평소처럼 하세요; 메모리 hook은 어느 쪽이든 계속 돕니다.

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
printf '# Memory Index\n\n> notes 0 · verified 0%% · updated: YYYY-MM-DD\n\n## debugging\n\n## pattern\n\n## environment\n\n## decision\n' > .loop/memory/INDEX.md
printf '# STATE — session handoff\n\n## Working on\n- (none)\n\n## Next steps\n- (none)\n\n## Open questions\n- (none)\n\n## Recent decisions\n- (none)\n' > .loop/memory/STATE.md
printf '# LEDGER — failure ledger\n\n> stages: fail → investigate → verify → distilled\n\n| date | symptom | stage | note |\n|------|---------|-------|------|\n' > .loop/memory/LEDGER.md
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

## 자율 러너

`loop-run`은 backlog를 무인으로 순회하며 각 항목에 `loop-task` 사이클을 적용합니다. 두 가지 설정이 당신의 환경에 맞춰줍니다 — 작업을 가져오는 **backlog 소스**와, 각 결과에 대해 수행하는 **write-back**입니다.

자율 러너(`loop-run`)는 `loop-init`에서 선택한 플러그블 **backlog 소스**로부터 작업 큐를 읽습니다:

- **file** (기본값) — `docs/project-status.md`의 "Ready to Execute" 절처럼 지정한 문서 섹션.
- **github** / **jira** / **command** — loopcraft가 설정된 `list`/`report` 커맨드를 실행합니다. 코어는 vendor 도구를 직접 호출하지 않습니다 — 번들된 GitHub 어댑터(`.loop/adapters/github.sh`)가 레퍼런스 구현이며, 다른 provider는 이를 템플릿으로 복사합니다.

`list`는 정규화된 JSON 배열(`id`, `title`, `body`, `ref`, `skip`)을 출력하고, `report`는 `LOOP_*` 환경변수로 결과를 전달받습니다. GitHub 어댑터에서 `skip`은 이슈에 붙은 `loop:manual`(수동 처리 전용, skip) 또는 `loop:blocked`(이전에 escalate됨) 라벨로 설정됩니다. `draft-pr` 모드에서는 별도의 `config.pr` 커맨드(**코드 호스트** 관심사)가 PR을 오픈하므로, `report`는 태스크 트래커 전용으로 유지됩니다 — 이 덕분에 Jira의 `report`와 GitHub의 `pr`을 조합할 수 있습니다.

**Write-back** (`backlog.writeback`, 기본값 `none`):

| 모드 | 브랜치 | 푸시 | 완료 시 |
|------|----------|--------|---------------|
| `none` | run당 1개 | 없음 | 없음 |
| `comment` | run당 1개 | 없음 | 항목에 판정 댓글 작성 |
| `draft-pr` | 항목당 1개 (`loop/<id>`) | feature 브랜치만 | 푸시 후 `config.pr`가 `Closes #<id>`가 포함된 **draft PR** 오픈 |

loopcraft는 이슈를 닫거나 기본 브랜치에 병합하지 않습니다 — 사람이 draft PR을 병합하면 플랫폼이 연결된 이슈를 자동으로 닫습니다. feature 브랜치 푸시는 `draft-pr` 모드(옵트인)에서만 발생하며, 그 외 모든 모드는 푸시 없이 유지됩니다.

**테스트 작성.** 항목에 테스트가 필요할 때 `loop-run`은 절대 maker가 자신의 코드를 위한 테스트를 직접 작성하게 두지 않습니다 — 설정되어 있다면 **Codex**가 작성하고, 그렇지 않으면 **컨텍스트가 격리된 서브에이전트**(동작 명세만 전달받고 maker의 추론은 전혀 보지 않는 새 에이전트)가 작성합니다. 독립적인 테스트는 구현이 아니라 동작을 검증합니다.

### GitHub 설정

**GitHub Issue**를 선택하면 `loop-init`이 이 내용을 대신 작성해 주지만, 그 형태는 다음과 같습니다 — `.loop/config.json`의 해당 부분:

```json
"backlog": {
  "source": "github",
  "list": "bash .loop/adapters/github.sh list --label loop:ready",
  "report": "bash .loop/adapters/github.sh report",
  "writeback": "draft-pr",
  "base": "main"
},
"pr": "bash .loop/adapters/github.sh pr"
```

일회성 라벨(loop-init이 생성을 제안합니다):

```bash
gh label create loop:ready   --description "loopcraft: pick up"
gh label create loop:manual  --description "loopcraft: manual only (skip)"
gh label create loop:blocked --description "loopcraft: escalated"
```

### GitHub, 처음부터 끝까지

*GitHub Issues를 대상으로 한 대표적인 `loop-run` 실행 — 예시일 뿐, 실제로 캡처된 로그는 아닙니다.*

1. **한 번만 온보딩합니다.** `loop-init` → 소스로 **GitHub Issue**, write-back으로 **draft-pr**을 선택합니다. 어댑터를 `.loop/adapters/github.sh`로 복사하고, `gh auth`를 확인한 뒤 위의 라벨들을 생성합니다.
2. **작업을 큐에 넣습니다.** 처리하고 싶은 이슈에는 `loop:ready`를, 사람이 필요한 항목에는 `loop:manual`을 남겨둡니다.
3. **루프를 실행합니다.**
   ```
   /loopcraft:loop-run 3
   ```
   준비된 이슈마다 `loop-run`은 이를 backlog 항목으로 읽어, 항목별 `loop/<id>` 브랜치에서 전체 `loop-task` 사이클(rubric → verifier → gate → `Loop-Verified` 커밋)을 실행한 다음, 판정 댓글과 `Closes #<id>`라고 적힌 본문을 가진 **draft PR**을 작성합니다.
4. **당신이 통제권을 가집니다.** 각 draft PR을 검토하세요; 병합하면 GitHub가 연결된 이슈를 자동으로 닫습니다. loopcraft는 절대 기본 브랜치에 병합하거나 이슈를 직접 닫지 않습니다 — 끝내지 못한 항목은 `loop:blocked`가 붙어 다음 실행에서 건너뜁니다.

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
- **Phase 3 — 자율 러너** (현재 릴리스): `/loop-run`이 backlog를 무인 순회 — 작업 → 검증 → 게이트 → 커밋 → 증류. 플러그블 backlog 소스(file/GitHub/Jira)와 write-back(comment / draft-PR) 지원. 커밋은 워크트리까지만, main 병합은 항상 사람이 결정합니다.

## 요구사항

- 플러그인을 지원하는 Claude Code
- `bash`, `git` (macOS / Linux)

## 테스트

```bash
./tests/run.sh   # 28케이스: hook 계약·새니타이즈·엣지 케이스
```

## 라이선스

MIT

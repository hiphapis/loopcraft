# 플러그블 backlog 소스 + write-back 설계

> 작성: 2026-07-17 · 상태: 승인 대기(스펙 리뷰) · 대상: loopcraft 플러그인

## 1. 배경 / 동기

현재 loopcraft의 backlog는 **문서 한 곳(파일 + 섹션)** 으로 고정돼 있다.

```json
"backlog": { "file": "docs/project-status.md", "section": "Ready to Execute" }
```

loopcraft를 설치한 프로젝트(예: OurStory = `hiphapis/ourStory`)에서 **태스크를 GitHub Issue 등 외부 시스템으로 관리**하고 싶다는 요구가 있다. 다만 특정 벤더(GitHub)에 종속되면 안 되고, 사용자가 `파일 / GitHub / Jira / 기타`를 **선택**할 수 있어야 한다.

## 2. 목표 / 비목표

**목표**

- backlog **소스를 갈아끼울 수 있는 provider-무관 추상화**. GitHub은 그 중 한 어댑터일 뿐.
- loopcraft 코어는 **vendor 도구(`gh`·`jira` 등)를 직접 호출하지 않는다.** 프로젝트가 지정한 `list`/`report` 커맨드만 호출.
- 처리 결과를 외부 시스템에 **쓰기(write-back)**: 코멘트 / Draft PR. 완료(이슈 종료)는 **사람이 PR을 머지할 때 플랫폼이 자동** 수행.
- 하위호환: 기존 `{file, section}` 설정은 무수정으로 동작.
- 두 실행 경로 구분:
  - **loop-task(프롬프트 구동)** — backlog 소스 불필요(프롬프트가 곧 작업). write-back은 개념상 유용하나 항목 id 추론이 필요해 이번 범위 밖(§13 열린 질문).
  - **loop-run(자율 러너)** — backlog 소스에서 큐를 읽어 무인 처리 + write-back 적용. **이번 구현의 중심.**

**비목표**

- loopcraft가 이슈를 **생성·조직화**하지 않는다(사람이 함).
- loopcraft가 이슈를 **직접 닫지 않는다**(사람 머지 → 플랫폼 자동 종료).
- **기본 브랜치로의 push·머지 금지**(항상 사람).
- 실시간 동기화·웹훅 없음(실행 시점 조회 = 폴링만).
- **Jira/기타 어댑터 완성은 이번 범위 밖.** 이번엔 계약 + GitHub 레퍼런스 어댑터 + 템플릿 안내까지. Jira 구현은 후속.

## 3. 설계 원칙

1. **코어 vendor-중립.** 코어는 오직 `source == "file"` 인지, 아닌지(=커맨드 기반)만 분기한다. `file`이 아닌 값(`github`/`jira`/`command`/…)은 사람이 읽기 위한 라벨이며 기능적으로는 모두 "`list`/`report` 커맨드를 쓰라"는 뜻이다.
2. **프로젝트가 파일 소유.** 어댑터 스크립트는 `.loop/adapters/`에 **복사**되어 프로젝트가 수정할 수 있다.
3. **로컬 커밋이 authoritative.** write-back은 best-effort. 실패해도 작업/커밋은 유효.
4. **안전 계약 유지·명시적 확장.** push 확장은 `draft-pr` 모드에서만, opt-in으로.

## 4. config 스키마 (하위호환)

```json
"backlog": {
  "source": "github",         // "file"(기본) | 그 외 문자열(github/jira/command…) = 커맨드 기반
  "file": "docs/…",           // source=file 전용
  "section": "Ready …",       // source=file 전용
  "list":   "bash .loop/adapters/github.sh list --label loop:ready", // 커맨드 기반 전용(선별 조건은 커맨드 문자열에 포함 — 코어는 커맨드를 그대로 실행)
  "report": "bash .loop/adapters/github.sh report",                  // 커맨드 기반 전용
  "base":   "main",                                                  // draft-pr 모드의 PR 대상 브랜치(선택, 기본=원격 기본 브랜치)
  "writeback": "draft-pr"     // "none"(기본) | "comment" | "draft-pr"
}
```

- `source` 키가 없으면 **`file`** 로 간주 → 기존 설정 무수정.
- `writeback` 키가 없으면 **`none`**.

## 5. 정규화 계약 (provider-무관 인터페이스)

### 5.1 `list` — stdout에 JSON 배열

```json
[
  {
    "id": "42",
    "title": "로그인 버튼 색 수정",
    "body": "…수용 기준…",
    "ref": "https://github.com/owner/repo/issues/42",
    "skip": false,
    "skipReason": ""
  }
]
```

- `id`, `title` **필수**. 누락 항목은 경고 로그 후 skip.
- `skip: true` — 어댑터가 "무인 부적합"(수동 QA·외부 프로비저닝 등)으로 판정한 항목. **벤더별 판정(라벨→skip)은 어댑터가 담당**하고, 코어 triage는 이 플래그를 존중한다.
- 코어는 `list` 출력을 **데이터로만** 취급한다(절대 eval 금지). `title`/`body`는 신뢰 불가 텍스트로 다룬다.

### 5.2 `report` — 항목마다 코어가 호출(환경변수 페이로드)

| 변수 | 의미 | 비고 |
|--|--|--|
| `LOOP_ITEM_ID` | 항목 id | 항상 |
| `LOOP_ITEM_REF` | 항목 링크 | 선택 |
| `LOOP_EVENT` | `started` \| `verified` \| `escalated` | 항상 |
| `LOOP_VERDICT` | 예 `3/3` | verified |
| `LOOP_COMMIT` | 커밋 sha | verified |
| `LOOP_BRANCH` | 브랜치명 | verified/started |
| `LOOP_BASE` | draft-pr PR 대상 브랜치 | draft-pr |
| `LOOP_NOTE` | 자유 텍스트(에스컬레이션 사유 등) | 선택 |
| `LOOP_WRITEBACK` | `none`\|`comment`\|`draft-pr` | 어댑터가 모드 인지 |

- **`title`/`body`는 report에 넘기지 않는다**(신뢰 불가 텍스트를 env로 재주입하지 않음). 어댑터가 필요하면 스스로 조회.
- `report` 종료코드: `0`=성공, 그 외=실패. **실패해도 항목을 실패 처리하지 않는다** — run 저널에 "report 실패" 기록 후 계속.

## 6. write-back 모드별 동작

| 모드 | 브랜치 모델 | 원격 push | 항목 완료 시 |
|--|--|--|--|
| `none` | run당 1개(현행) | ❌ | report 호출 안 함 |
| `comment` | run당 1개(현행) | ❌ | `report`(코멘트) |
| `draft-pr` | **항목별 `loop/<id>`** | ✅ 피처만 | `git push -u origin loop/<id>` → `report` → 어댑터가 Draft PR 생성(본문 `Closes #<id>`) + 코멘트 |

**`draft-pr` 세부**

- 각 항목은 **기본 브랜치(`base`, 기본=원격 기본 브랜치)에서 분기**한 `loop/<id>` 브랜치에서 작업 → 각 PR이 독립적으로 기본 브랜치에 머지 가능.
- 완료 링크(`Closes #<id>`)는 **PR 본문**에 둔다. 사람이 PR 머지 → 플랫폼이 이슈 자동 종료. loopcraft는 이슈를 직접 닫지 않음.
- 에스컬레이션 항목은 push하지 않는다(작업 미완). 기존 loop-run 규칙대로 stash 보존 + `report(escalated)` → 어댑터가 코멘트 + `loop:blocked` 라벨.

## 7. 컴포넌트 변경

| # | 파일 | 변경 |
|---|------|------|
| 1 | `.loop/config.json` 스키마 | `source`/`list`/`report`/`select`/`base`/`writeback` 추가, `source` 없으면 file 폴백 |
| 2 | `skills/loop-run/SKILL.md` | §1 Triage: `source==file`이면 문서 섹션(현행), 아니면 `list` 실행→JSON 파싱(+`skip` 존중). §2: 항목마다 `report` 호출, `draft-pr`이면 항목별 브랜치 + push |
| 3 | `adapters/github.sh` (신규, 번들) | `list`(`gh issue list --label <select> --json …`→정규화), `report`(event별 코멘트/`gh pr create --draft`/`loop:blocked` 라벨) |
| 4 | `skills/loop-init/SKILL.md` | 인터뷰에 Q1(소스)·Q2(writeback) 추가, git/원격 전제 체크, 어댑터 복사, `gh auth`·라벨 확인, **사용자 언어로 질문 렌더** |
| 5 | `tests/run.sh` | 계약·폴백·게이팅·어댑터 스모크 케이스 추가 |
| 6 | `README.md` ×4(en/ko/ja/zh) | 플러그블 backlog 소스 + write-back 섹션 |

- **loop-task는 변경하지 않는다** — 항목 id·report는 전부 loop-run 책임. loop-task는 item-agnostic한 검증 사이클로 격리 유지. (프롬프트 구동 write-back은 후속 논의; 이번 범위는 정책 설정 + loop-run 적용)

## 8. loop-init 인터뷰

**전제 체크(질문 이전)**: git 저장소가 아니면 loopcraft가 커밋 자체를 못 하므로 *"git 저장소에서 실행하세요"* 로 중단.

**Q1. "자율 러너(loop-run)가 어디서 태스크를 읽고 관리할까요?"**

- **파일** — 프로젝트 문서 한 곳(파일 + 섹션)에 적어 관리. init에서 파일·섹션 지정(예: `docs/project-status.md`의 "Ready to Execute"). *STATE.md와 별개* — 그건 세션 인계 메모.
- **GitHub Issue** — 이 프로젝트 GitHub Repo의 Issue로 관리. loopcraft가 **전용 라벨(`loop:ready`/`loop:blocked`)** 로 기존 티켓과 섞이지 않게 구분. init이 라벨 존재를 확인·생성 제안.
- **Jira** — Jira로 관리(계약대로 어댑터 커맨드 연결; `github.sh`가 템플릿).
- **직접 커맨드** — 임의 `list`/`report` 커맨드 지정.

GitHub 선택 시: 원격 감지 → 없으면 *"GitHub 원격이 감지되지 않았습니다"* 경고하고 파일 폴백 제안. 있으면 `github.sh`를 `.loop/adapters/`로 복사, `gh auth status` 확인.

**Q2. "작업 완료 시 완료 처리를 어떻게 할까요?"** — 아래 게이팅 적용, 사용자 언어로 렌더.

- **none** — 아무것도 하지 않습니다.
- **comment** — 해당 태스크에 코멘트(검증 결과·커밋·브랜치). loopcraft는 push하지 않습니다.
- **draft-pr** — 피처 브랜치를 push하고 Draft PR 생성(`git push -u origin` → 어댑터가 Draft PR + `Closes #N`). 사람이 머지하면 이슈 자동 종료.

**Q2 게이팅**

| 상황 | Q2 |
|--|--|
| Q1 = 파일 | **생략.** writeback=`none` |
| Q1 = 외부 시스템, 원격 있음 | 전체 제공(none/comment/draft-pr) |
| Q1 = 외부 시스템, 원격 없음 | `draft-pr` **숨김** + *"원격이 없어 Draft PR 불가 — 추가 후 재설정하면 켜집니다"* |

## 9. 로컬라이즈(다국어)

- 인터뷰는 하드코딩 문자열이 아니라 **LLM이 SKILL.md 지시를 읽고 생성**한다. SKILL.md에는 옵션 문구를 못박지 말고 **각 옵션의 의도**를 적고, *"사용자의 작업 언어로 질문·보기를 제시하라"* 고 지시한다. → 영어/중국어 사용자는 그 언어로 질문·보기를 받는다.
- **config에 저장되는 값은 항상 정규 영어 enum**(`file`/`github`/`jira`/`command`, `none`/`comment`/`draft-pr`). 언어와 무관하게 코어·어댑터가 동작.

## 10. 안전 계약 갱신

기존:
> main 병합·push 금지. 커밋은 현재 브랜치까지가 끝이다.

갱신:
> **기본 브랜치로의 push·머지는 항상 사람이 한다(금지).** `writeback: draft-pr` 모드에서만 리뷰용 피처 브랜치(`loop/<id>`)의 **원격 push를 허용**한다. 그 외 모드에서는 종전대로 push하지 않는다. 이슈 종료는 사람이 PR을 머지할 때 플랫폼이 자동 수행하며, **loopcraft는 이슈를 직접 닫지 않는다.** 이 push 확장은 config opt-in이므로, `draft-pr`을 켜지 않은 프로젝트는 기존 push-free 보장을 그대로 유지한다.

## 11. 에러 처리

- **`list` 실패**(네트워크·인증) → run을 깨끗이 중단하고 사유 로그. **빈 backlog로 위장 금지**(할 일 없음으로 오인 방지).
- **`report` 실패** → 항목 실패 아님. 저널에 기록 후 계속(best-effort).
- **헤드리스/cron에서 vendor 인증 부재** → `report`는 best-effort degrade(로그), `list` 실패는 run 중단.
- **계약 위반 항목**(id/title 누락) → 경고 로그 후 skip.
- **`draft-pr` + 원격 없음**(런타임에 발견) → 해당 항목 push 생략 + report(comment) 폴백 + 저널 경고.

## 12. 테스트 전략 (`tests/run.sh`, bash · 현재 26케이스에 추가)

- **폴백**: `source` 없는 기존 `{file, section}` config 정상 동작.
- **계약**: 정규화 JSON 파싱 정상 / malformed 항목 skip / `skip:true` triage 존중.
- **report 페이로드**: event별 env 변수 구성 정확(title/body 미포함 확인).
- **어댑터 스모크**: `gh`·`git`을 PATH shim으로 스텁 → `github.sh list`가 정규화 모양 반환, `report`가 올바른 `gh`/`git` 호출을 **조립**(네트워크 미접속, 인자 검증만).
- **게이팅**: `draft-pr`은 원격 있을 때만; 원격 없으면 옵션 부재/폴백.

## 13. 열린 질문

- 프롬프트 구동(loop-task) 경로에서의 write-back 자동 적용 여부·항목 id 추론 방식 — **후속**(이번 범위는 정책 설정 + loop-run 적용).
- GitHub Projects(v2)·Milestone 기반 선별을 `select` 문법으로 어디까지 표현할지 — GitHub 어댑터 구현 시 확정.

<p align="center">
  <img src="assets/loopcraft-hero.webp" alt="Loopcraft — 自我纠正的循环与跨会话的记忆" width="880">
</p>

# Loopcraft

[English](README.md) | [한국어](README.ko.md) | [日本語](README.ja.md) | **中文**

面向 [Claude Code](https://claude.com/claude-code) 的循环工程（loop engineering）插件 — 与其用越来越长的提示词去操控模型，不如设计这样的循环：让模型**根据环境反馈自我纠正**，并**跨会话积累记忆**。

灵感来自 [Lance Martin 的 loop engineering](https://x.com/RLanceMartin/article/2064397389189071163) 与 [Andrej Karpathy 的 LLM Wiki 模式](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)：自我改进是*系统*的属性，而非模型的属性。Loopcraft 把这个系统做成了可安装的插件。

## 为什么用 Loopcraft？

每个 Claude Code 会话都从零开始。你上次积累的上下文 — 那个测试为什么不稳定、你已经试过又放弃的重构、这个代码库的怪癖 — 会在会话结束或上下文被压缩的那一刻消失。常见的应对是往提示词里塞更多内容：更长的 `CLAUDE.md`、更多常驻指令。但用越来越长的提示词去操控模型无法扩展，也依然挡不住它忘记昨天的工作，或者对自己的产出打分过于宽松。

循环工程采取不同的立场：**自我改进是系统的属性，而非模型的属性。** 与其用更大的提示词，不如构建一个循环 — 模型行动，*环境*回推（测试、独立评分者），模型纠正，学到的东西写入持久记忆，供下一个会话在动手之前先读取。模型不需要变得更聪明 — 围绕它的系统需要会记忆、会检查。

Loopcraft 就是把这样一个系统做成了可安装的插件。在以下情况下使用它：

- 在一个真实项目上**跨多个会话**工作，却在反复解释相同的上下文；
- 想要**按明确标准验证过**的工作，而不是相信模型自己的"看起来没问题"；
- 让 Claude **无人值守**运行，并希望每个结果在进入 `main` 之前都经过门禁、可审计；
- 厌倦了模型**重复犯**它上周已经遇到并解决过的错误。

而且 vault 是纯 Markdown 而非隐藏的数据库，所以这份记忆完全属于你：把 Obsidian 指向 `.loop/memory/` 看着知识图谱生长，或在终端里 grep，或直接在 PR 里阅读。系统学到的一切，你都看得见、也能亲手编辑。

<p align="center">
  <img src="assets/loopcraft-graph.webp" alt="真实 Loopcraft vault 的 Obsidian 图谱视图 — STATE、INDEX、LEDGER 枢纽与蒸馏笔记和标签相连" width="640"><br>
  <sub><i>真实 <code>.loop/memory</code> vault 的 Obsidian 图谱视图 — STATE / INDEX / LEDGER 枢纽与蒸馏笔记和标签相连。</i></sub>
</p>

## 工作原理

<p align="center">
  <img src="assets/loopcraft-how-it-works.svg" alt="Loopcraft 工作原理 — 记忆 vault 通过 SessionStart 注入，启动 loop-task → verifier → gate → commit 循环；验证失败则重试，蒸馏后的失败回流到 vault，Stop 门禁与 PreCompact 钩子守护会话" width="900">
</p>

循环在两个时间尺度上闭合：

- **在一个任务内** — `loop-task` 把你的工作交给独立的 `verifier`，它只看产出和标准、依据 rubric 打分 — 绝不看 maker 的推理过程，因此无法被说服而放行。不合格，maker 就拿到判定并重试，最多 `maxRetries` 次。合格，工作再通过你真实的门禁（测试、类型检查），并落成一个带 `Loop-Verified: n/m` 标记的提交。
- **跨会话** — `.loop/memory` vault 随仓库一起移动。`SessionStart` 会注入它，于是 Claude 一开始就知道过去的会话学到了什么；一旦出错，`distill` 把它变成*经过验证的*可复用规则；而 Stop 门禁和 PreCompact 钩子确保在会话结束或上下文被摘要抹去之前，进度一定被写下来。没有任何东西需要从头重学。

## 概念（Concepts）

**循环工程（loop engineering）** 是这里一切的根本思路：与其手工去调一个越来越大的提示词，不如设计模型运行所在的那个*循环*来改善结果 — 行动、从环境获取反馈、纠正、记录所学。杠杆的支点从模型权重转移到围绕它的系统（记忆、验证、门禁）。处在好循环中的弱模型，胜过既无记忆又无检查的强模型。（这一框架借鉴了 Lance Martin 关于 loop/context engineering 的工作与 Andrej Karpathy 的 LLM Wiki 模式。）

本 README 用到的其余术语：

- **Maker（生产者）** — 在 `loop-task` 中产出工作的主体，也就是按你的要求行动的 Claude。maker 从不给自己打分。
- **Verifier（验证者）** — 依据 rubric 对 maker 产出打分的独立子代理。它只看产出和标准，绝不看 maker 的推理过程，因此无法被说服而放行。（`agents/verifier.md`）
- **Rubric（评分标准）** — `.loop/rubrics/` 下的一个小 Markdown 文件，为某类工作声明合格/不合格标准，以及*如何*验证每一条（要运行的命令、要检查的文件）。它是 verifier 据以打分的契约。例如 `code` rubric 可能要求“测试通过”“不包含密钥”“公开函数有文档”。
- **Gate（门禁）** — 提交前必须以 0 退出的、你项目里的真实命令（`npm test`、类型检查、`./tests/run.sh`）。rubric 判断质量，gate 则强制它真的能跑通。
- **Vault（保险库）** — `.loop/memory/`，随仓库一起移动的纯 Markdown 存储：`INDEX.md`（目录+统计）、`STATE.md`（会话交接）、`LEDGER.md`（失败台账）、`notes/`（蒸馏出的规则）。
- **Distill（蒸馏）** — 把失败变成 vault 中*经过验证的*可复用笔记的五阶段协议（Fail → Investigate → Verify → Distill → Consult），而不是让你把教训学两遍。
- **Loop-Verified: n/m** — `loop-task` 在提交 trailer 中打的标记：由独立 verifier 判定，m 条标准中满足了 n 条。这是你的审计证迹。

## 功能一览

| 组件 | 作用 |
|-----------|--------------|
| **SessionStart 钩子** | 每个新会话自动注入项目记忆（`INDEX.md` + `STATE.md`），并提醒台账中未解决的失败。Claude 一开始就知道过去的会话学到了什么。 |
| **Stop 门禁钩子** | *Write before walking away*：如果代码已变更但 `STATE.md` 没有更新，会阻止一次会话结束并提醒记录。若循环任务标记仍在（验证未完成）同样阻止。每个会话最多阻止一次 — 绝不会把你锁住。 |
| **PreCompact 钩子** | 在上下文压缩之前，提醒模型先把进度写入 `STATE.md`，避免信息在摘要中丢失。 |
| **`/loopcraft:distill` 技能** | 把失败转化为知识的五阶段协议：**Fail → Investigate → Verify → Distill → Consult**。失败会变成 vault 中*经过验证的*通用规则 — 优先合并进已有笔记，绝不重复。 |
| **Obsidian 兼容 vault** | `.loop/memory/` 是带 YAML frontmatter 和 `[[双链]]` 的纯 Markdown。用 Obsidian 打开即可观察知识图谱的生长。不依赖任何应用 — 循环只需要文件。 |
| **`verifier` 子代理** | 根据你的评分标准（rubric）独立对产出打分的评估者。只看产出和标准，不看 maker 的推理过程。完全阻断 maker 的主观偏差。 |
| **`/loopcraft:loop-task` 技能** | Maker → verifier → 重试 → 门禁 → 提交的循环：提交任务说明，收到 verifier 的判定摘要，合格时自动在提交 trailer 中记录 `Loop-Verified: n/m`。留下审计证迹。 |
| **`/loopcraft:loop-init` 技能** | 扫描仓库并与你面谈，用已配置的门禁和 rubric 初案自动搭建 `.loop/`。一条命令完成项目引导。 |
| **`/loopcraft:loop-run` 技能** | 无人值守地遍历 backlog — 自动选别项目、执行 loop-task 循环、通过门禁、提交更改，全部自动化。所有提交只到 worktree 为止，合并到 main 永远由你决定 — 系统只是执行，绝不会推送到仓库。 |

零运行时依赖：`bash + git + grep/sed/awk`。逃生口：设置 `LOOP_DISABLE=1` 可禁用所有钩子。

## 实际运行起来

*这是一个 `loop-task` 循环的示例。rubric 与 verdict 为便于阅读做了翻译，但格式与标准遵循 loopcraft 的真实产物 — 而下面这次运行本身是代表性示例，并非采集到的日志。*

假设你要给某个钩子脚本加一个新分支。与其直接提交，不如把它送进循环：

```
/loopcraft:loop-task Add a LOOP_DISABLE short-circuit to the SessionStart hook
```

`loop-task` 会把改动的文件（`hooks/scripts/*.sh`）匹配到 **`code`** rubric — 五条标准，每条都声明了如何验证：

```
1. 门禁通过        — ./tests/run.sh 退出码 0，无 `not ok` 行
2. 声明安全选项     — 改动脚本声明 `set -euo pipefail`（至少 `set -u`）
3. 变量加引号       — 路径 / 用户输入变量以 "$VAR" 展开
4. 附带测试        — 每个新分支都在 tests/run.sh 中加入对应的 assert_*
5. 保留可执行位     — hooks/scripts/ 下的文件保持 755 及以上
```

maker 完成工作后，只把 diff 和 rubric — 绝不带上自己的推理 — 交给独立的 `verifier`。第一次打分：

```
## Verdict

| # | 标准 | 判定 | 证据 |
|---|------|------|------|
| 1 | 门禁通过 | pass | ./tests/run.sh → 退出 0，`not ok` 0 条 |
| 2 | 声明安全选项 | pass | 第 2 行: `set -euo pipefail` |
| 3 | 变量加引号 | pass | diff 只新增 `"$LOOP_DISABLE"` |
| 4 | 附带测试 | fail | 新的 early-return 分支，tests/run.sh 的 diff 中无对应 assert_* |
| 5 | 保留可执行位 | pass | 模式 755 未变 |

**无法评分的标准**: 无
**结果**: FAIL (4/5)
**FAIL 摘要**: #4 — 新的 disable 分支没有回归测试。
```

verifier 从未看过 maker 的推理，所以“它显然能跑”毫无分量 — 唯一算数的是那条缺失的测试。maker 只拿到这条 FAIL 摘要，补上 `assert_*` 用例，重新提交。第二次：

```
**结果**: PASS (5/5)
```

此时真实门禁运行、变绿，改动带着刻进提交的 verdict 落地：

```
$ git log -1 --format='%s%n%n%b'
Add LOOP_DISABLE short-circuit to SessionStart hook

Loop-Verified: 5/5
```

这条 `Loop-Verified: 5/5` trailer 就是你的审计证迹：五条标准全部满足，由一个无法被说服的打分者签署。

> **代价。** 每次尝试都多一趟独立打分，FAIL 则再跑一轮 maker → verifier（直到 `maxRetries`）。这份开销正是*机制*本身 — 也正因如此，`loop-task` 面向的是非平凡、可验证的工作，而不是一行修改或漫无目的的探索。那类事照常做就好；记忆钩子无论如何都在运行。

## 安装

**方式 A — 插件市场（推荐）：**

```
/plugin marketplace add hiphapis/loopcraft
/plugin install loopcraft@loopcraft
```

**方式 B — 本地克隆（开发用）：**

```bash
git clone https://github.com/hiphapis/loopcraft.git
claude --plugin-dir ./loopcraft
```

## 项目初始化

**推荐：使用 `/loopcraft:loop-init`**

在仓库根目录执行：

```
/loopcraft:loop-init
```

该技能会扫描项目结构，与你面谈有关门禁和评分标准的问题，然后自动生成配置好的 `.loop/config.json` 和 `.loop/rubrics/` 的初案。无需手动编辑。

### 手动初始化（可选）

如果更喜欢手动搭建 `.loop/`，在仓库根目录执行一次：

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

请把 `gates` 改成项目的真实命令。`.loop/` 需要提交到仓库 — vault 的设计就是随仓库移动，worktree 和其他机器可以无缝接续。

## 使用方法

**日常会话** — 无需任何操作。SessionStart 钩子自动注入 `INDEX.md` 和 `STATE.md`，Claude 会先参考积累的知识再开始工作。

**当某事失败时**（测试、构建、错误的假设）：

```
/loopcraft:distill ffmpeg 烧录字幕在 Homebrew 构建下不显示（缺少 libass）
```

该技能会引导完成：记入台账 → 调查原因 → **通过复现或反证来验证诊断** → 蒸馏为通用规则（frontmatter 的 `verified: true/false` 区分假设与事实）→ 链接进 vault。

**需要审计证迹的工作** — 用 loop-task 通过 verifier 和门禁：

```
/loopcraft:loop-task 重构 migration 净化逻辑以消除 SQL 注入漏洞
```

技能会提交任务，等待 verifier 的判定摘要，合格时在提交 trailer 中记录 `Loop-Verified: n/m`。评分标准存放在 `.loop/rubrics/`，每个标准都需要明确声明验证方法和通过条件。

**结束会话时** — 如果改了代码却没更新 `STATE.md`，Stop 门禁会阻止一次并告诉你该记录什么。更新 STATE 后干净地结束，下一个会话就能从同一个位置无缝继续。

**自主 backlog 遍历** — 让系统夜间工作：

```
/loopcraft:loop-run 3
```

在后台会话中自动选别 backlog 项目、执行 loop-task 循环、通过门禁，然后全部提交到 worktree。早上你可以查看运行日志（`.loop/journal/run-*.md`）和 Loop-Verified 提交，选择喜欢的 cherry-pick 到 main，其余的丢弃。系统绝不会合并 — 所有人为把关的权力完全保留。

**观察成长** — 用 Obsidian 打开 `.loop/memory/` 查看图谱视图，或者：

```bash
git log --oneline -- .loop/memory/   # 循环在何时学到了什么
```

## Vault 结构

```
.loop/
├── config.json          # 门禁命令、backlog 来源、重试上限、自主权限
├── memory/              # 提交到仓库
│   ├── INDEX.md         # 目录（MOC）+ 统计（笔记数、verified 比例）
│   ├── STATE.md         # 会话交接：在做什么 / 下一步 / 未决问题
│   ├── LEDGER.md        # 失败台账：fail → investigate → verify → distilled
│   └── notes/*.md       # 蒸馏出的规则（YAML frontmatter + [[双链]]）
├── journal/             # 运行日志 — gitignore
└── state/               # 易失性会话标记 — gitignore
```

笔记 frontmatter：`title / tags / category (debugging|pattern|environment|decision) / confidence / verified / created / updated / sources`。

## 一切皆 Markdown — 用 Obsidian 打开

vault 没有数据库，也不依赖任何应用。每条笔记都是带 YAML frontmatter 和 `[[双链]]` 的纯 Markdown，所以循环读取的那些文件，你也可以读取、grep、diff、手动编辑。

把 Obsidian 指向 `.loop/memory/`，它就变成一个活的 vault：图谱视图显示蒸馏规则之间如何相互链接，反向链接让相关的失败浮现，frontmatter（`category`、`verified`、`confidence`）成为可搜索的元数据。循环并不*需要* Obsidian — 它只是*观察*系统学到了什么的一个好方式。更喜欢终端？`git log -- .loop/memory/` 会告诉你循环在何时学到了什么。

## Backlog 来源与 write-back

自主运行器（`loop-run`）从 `loop-init` 时选定的可插拔 **backlog 来源** 中读取工作队列：

- **file**（默认）— 你指定的文档章节，例如 `docs/project-status.md` 中的 "Ready to Execute" 一节。
- **github** / **jira** / **command** — loopcraft 运行你配置的 `list`/`report` 命令。核心从不直接调用 vendor 工具 — 内置的 GitHub 适配器（`.loop/adapters/github.sh`）是参考实现，其他 provider 复制它作为模板。

`list` 输出规范化的 JSON 数组（`id`、`title`、`body`、`ref`、`skip`）；`report` 通过 `LOOP_*` 环境变量接收结果。对于 GitHub 适配器，`skip` 由 issue 上的 `loop:manual`（仅限人工处理，skip）或 `loop:blocked`（此前已 escalate）标签设置。

**Write-back**（`backlog.writeback`，默认 `none`）：

| 模式 | 分支 | 推送 | 完成时 |
|------|----------|--------|---------------|
| `none` | 每次运行 1 个 | 无 | 无 |
| `comment` | 每次运行 1 个 | 无 | 在项目上评论判定结果 |
| `draft-pr` | 每个项目 1 个（`loop/<id>`） | 仅 feature 分支 | 推送并打开带 `Closes #<id>` 的 **draft PR** |

loopcraft 绝不会关闭 issue 或合并到默认分支 — 由人合并 draft PR，平台会自动关闭关联的 issue。仅在 `draft-pr` 模式（opt-in）下才会推送 feature 分支；其他所有模式都保持不推送。

## 路线图

- **Phase 1 — Memory** ✅：钩子、蒸馏协议、vault。
- **Phase 2 — Self-correction** ✅：可验证的评分标准（rubric）、不看 maker 推理过程、只对产出打分的独立 verifier 子代理、`/loop-task` 自我纠正循环、`/loop-init` 引导式初始化。
- **Phase 3 — 自主运行器**（当前版本）：`/loop-run` 无人值守地遍历 backlog — 工作 → 验证 → 门禁 → 提交 → 蒸馏。支持可插拔的 backlog 来源（file/GitHub/Jira）与 write-back（comment / draft-PR）。提交只到 worktree 为止，合并到 main 永远由人决定。

## 环境要求

- 支持插件的 Claude Code
- `bash`、`git`（macOS / Linux）

## 测试

```bash
./tests/run.sh   # 28 个用例：钩子契约、输入净化、边界情况
```

## 许可证

MIT

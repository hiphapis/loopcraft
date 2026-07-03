# Loopcraft

[English](README.md) | [한국어](README.ko.md) | [日本語](README.ja.md) | **中文**

面向 [Claude Code](https://claude.com/claude-code) 的循环工程（loop engineering）插件 — 与其用越来越长的提示词去操控模型，不如设计这样的循环：让模型**根据环境反馈自我纠正**，并**跨会话积累记忆**。

灵感来自 Lance Martin 的 loop engineering 与 Andrej Karpathy 的 LLM Wiki 模式：自我改进是*系统*的属性，而非模型的属性。Loopcraft 把这个系统做成了可安装的插件。

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
printf '# STATE — session handoff\n\n## Working on\n- (none)\n\n## Next steps\n- (none)\n\n## Open questions\n- (none)\n' > .loop/memory/STATE.md
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

## 路线图

- **Phase 1 — Memory** ✅：钩子、蒸馏协议、vault。
- **Phase 2 — Self-correction** ✅：可验证的评分标准（rubric）、不看 maker 推理过程、只对产出打分的独立 verifier 子代理、`/loop-task` 自我纠正循环、`/loop-init` 引导式初始化。
- **Phase 3 — 自主运行器**（当前版本）：`/loop-run` 无人值守地遍历 backlog — 工作 → 验证 → 门禁 → 提交 → 蒸馏。提交只到 worktree 为止，合并到 main 永远由人决定。

## 环境要求

- 支持插件的 Claude Code
- `bash`、`git`（macOS / Linux）

## 测试

```bash
./tests/run.sh   # 26 个用例：钩子契约、输入净化、边界情况
```

## 许可证

MIT

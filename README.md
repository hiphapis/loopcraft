# Loopcraft

**English** | [한국어](README.ko.md) | [日本語](README.ja.md) | [中文](README.zh-CN.md)

Loop engineering plugin for [Claude Code](https://claude.com/claude-code) — instead of steering the model with ever-longer prompts, design loops where it **self-corrects from environment feedback** and **accumulates memory across sessions**.

Inspired by Lance Martin's loop engineering work and Andrej Karpathy's LLM Wiki pattern: self-improvement is a property of the *system*, not the model. Loopcraft builds that system as an installable plugin.

## What you get (Phase 1 + 2)

| Component | What it does |
|-----------|--------------|
| **SessionStart hook** | Injects your project's memory (`INDEX.md` + `STATE.md`) into every new session, plus a reminder for unresolved failures in the ledger. Claude starts already knowing what past sessions learned. |
| **Stop gate hook** | *Write before walking away*: if code changed but `STATE.md` wasn't updated, ending the session is blocked once with a reminder. Also blocks ending mid-verification when a loop task marker is present. Max one block per session — never a lock-in. |
| **PreCompact hook** | Right before context compaction, reminds the model to persist progress into `STATE.md` so nothing is lost to summarization. |
| **`/loopcraft:distill` skill** | A 5-stage failure-to-knowledge protocol: **Fail → Investigate → Verify → Distill → Consult**. Failures become *verified*, general rules in your vault — merged into existing notes first, never duplicated. |
| **Obsidian-compatible vault** | `.loop/memory/` is plain markdown with YAML frontmatter and `[[wikilinks]]`. Open it as an Obsidian vault and watch the knowledge graph grow. No app dependency — the loop only needs files. |
| **`verifier` subagent** | An independent grader that scores your work against a rubric — seeing only the output and criteria, not your reasoning. Prevents maker bias from clouding judgment. |
| **`/loopcraft:loop-task` skill** | Maker → verifier → retry → gate → commit cycle: submit a task description, get a verdict summary, then automatically stamp `Loop-Verified: n/m` in the commit trailer for audited work. |
| **`/loopcraft:loop-init` skill** | Scans your repo and interviews you to scaffold `.loop/` with configured gates and a rubric starter. One-command project onboarding. |

Zero runtime dependencies: `bash + git + grep/sed/awk`. Escape hatch: set `LOOP_DISABLE=1` to disable all hooks.

## Installation

**Option A — marketplace (recommended):**

```
/plugin marketplace add hiphapis/loopcraft
/plugin install loopcraft@loopcraft
```

**Option B — local clone (for development):**

```bash
git clone https://github.com/hiphapis/loopcraft.git
claude --plugin-dir ./loopcraft
```

## Project setup

**Recommended: Use `/loopcraft:loop-init`**

At your repo root, run:

```
/loopcraft:loop-init
```

The skill scans your project structure, interviews you about gates and quality rubrics, then generates `.loop/config.json` and a starter rubric in `.loop/rubrics/`. No manual editing needed.

### Manual setup (optional)

If you prefer to scaffold `.loop/` by hand, run this once at your repo root:

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

Adjust `gates` to your project's real commands. Commit `.loop/` — the vault is meant to travel with the repo (worktrees and other machines get it for free).

## Usage

**Every session** — nothing to do. The SessionStart hook injects `INDEX.md` and `STATE.md` automatically; Claude consults accumulated knowledge before acting.

**When something fails** (a test, a build, a wrong assumption):

```
/loopcraft:distill ffmpeg burn-in subtitles invisible on Homebrew builds (no libass)
```

The skill walks through recording the failure in the LEDGER, investigating the cause, **verifying the diagnosis by reproduction or refutation**, distilling it into a general rule (frontmatter carries `verified: true/false` so hypotheses are never confused with facts), and linking it into the vault.

**For auditable work** — use loop-task to route your work through the verifier and gate:

```
/loopcraft:loop-task Refactor migration sanitization to prevent SQL injection
```

The skill submits the task, waits for the verifier's verdict summary, and on pass, stamps the commit trailer with `Loop-Verified: n/m` (n criteria met, m total). Rubrics live in `.loop/rubrics/` — each one declares the verification method and passing criteria.

**Ending a session** — if you changed code but didn't update `STATE.md`, the Stop gate blocks once and tells you what to write down. Update STATE, end cleanly, and the next session picks up exactly where you left off.

**Watching it grow** — open `.loop/memory/` in Obsidian for the graph view, or:

```bash
git log --oneline -- .loop/memory/   # what the loop learned, when
```

## Vault format

```
.loop/
├── config.json          # gates, backlog source, retry caps, autonomy limits
├── memory/              # committed to the repo
│   ├── INDEX.md         # map of content + stats (note count, verified %)
│   ├── STATE.md         # session handoff: working on / next / open questions
│   ├── LEDGER.md        # failure ledger: fail → investigate → verify → distilled
│   └── notes/*.md       # distilled rules (YAML frontmatter + [[wikilinks]])
├── journal/             # run logs — gitignored
└── state/               # volatile session markers — gitignored
```

Note frontmatter: `title / tags / category (debugging|pattern|environment|decision) / confidence / verified / created / updated / sources`.

## Roadmap

- **Phase 1 — Memory** ✅: hooks, distill protocol, vault.
- **Phase 2 — Self-correction** (this release): verifiable rubrics, an independent verifier subagent that grades outputs without seeing the maker's reasoning, `/loop-task` self-correction cycles, `/loop-init` onboarding interview.
- **Phase 3 — Autonomous runner**: `/loop-run` iterates a backlog unattended — work → verify → gate → commit → distill — commits stay in a worktree; merging to main always requires a human.

## Requirements

- Claude Code with plugin support
- `bash`, `git` (macOS / Linux)

## Testing

```bash
./tests/run.sh   # 26 cases: hook contracts, sanitization, edge cases
```

## License

MIT

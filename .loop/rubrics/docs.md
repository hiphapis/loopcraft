---
name: docs
---

# docs — markdown skill rubric

Targets: every change to a `.md` file in the repository — `skills/**/SKILL.md`, `agents/*.md`, `README*.md`, etc.

## Criteria

1. **Frontmatter completeness**: when a `SKILL.md`/`agents/*.md` file changes, its YAML frontmatter contains non-empty `name` and `description` keys (plain documents without frontmatter, e.g. `README*.md`, are excluded from this criterion).
   - How to verify: extract the top `---`~`---` block and check the `name:`/`description:` lines.
   - Pass condition: both keys present AND value length > 0.

2. **Skill filename convention**: each directory under `skills/` holds exactly one `SKILL.md` file.
   - How to verify: for each `find skills -mindepth 1 -maxdepth 1 -type d`, confirm `SKILL.md` exists.
   - Pass condition: exactly one `SKILL.md` in every skill directory.

3. **README sync**: if a `skills/` directory was added or renamed, that skill name is mentioned at least once in the "What you get" table of `README.md`, as `/loopcraft:<name>`.
   - How to verify: compare `ls skills` against `grep -oE '/loopcraft:[a-z-]+' README.md`.
   - Pass condition: every `skills/*` directory name is mentioned in `README.md` (a docs-only change that renames no existing skill satisfies this automatically).

4. **Link integrity**: relative-path markdown links (`[text](path)`, excluding http(s)) point to files that actually exist.
   - How to verify: extract links with `grep -oE '\]\([^)]+\)'`, then check each path for file existence.
   - Pass condition: no broken relative-path links.

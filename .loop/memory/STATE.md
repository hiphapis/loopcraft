# STATE — session handoff

> updated: 2026-07-17

## Working on
- Making the loopcraft repo fully English (this started from evaluating the README from a developer's / loop-engineer's POV).
- ✅ "See it in action" walkthrough in all 4 READMEs (en/ko/ja/zh): code rubric 5 criteria → verdict (FAIL 4/5 → fix → PASS 5/5) → gate → `Loop-Verified` commit. Illustrative label + honest cost note. (commit `65dbd7d`)
- ✅ Rubrics to English: `.loop/rubrics/{code,docs}.md`. (65dbd7d)
- ✅ verifier + 4 skills to English: `agents/verifier.md`, `skills/{loop-task,loop-init,loop-run,distill}`. Coupling kept consistent (verifier labels Result / Unscorable criteria / FAIL summary ↔ loop-task parsing). loop-init scaffolding INDEX/STATE/LEDGER templates also English. (commit `97bb946`)
- ✅ docs rubric criterion 4: exclude links inside backtick code spans (removes the self-reference false positive). (97bb946)
- ✅ Repo internals to English: `hooks/scripts/*.sh` (comments + user-facing strings), `.loop/memory/{INDEX,STATE,LEDGER}.md`, and the coupled `tests/run.sh` assertions (session-start warning string ↔ test needles).

## Next steps
- (none pending — the full-English pass covers the distributed surface + repo internals)

## Open questions
- Hero fade width: currently A (30×26). Can swap to B (55×48) or thinner if wanted (fade_A/B previews in scratchpad).

## Recent decisions
- Manual-setup templates (INDEX/STATE/LEDGER) in all 4 READMEs now match loop-init's output exactly: English content, 4-section STATE (added "Recent decisions"), unified LEDGER separator. README.ja/zh already had English templates; only ko had Korean ones. loop-init's LEDGER separator was aligned to the READMEs/actual file.
- Commit messages are English from now on (the repo is English; existing history stays Korean).
- ko/ja/zh READMEs stay localized (intentional translations); only their language-switcher nav labels (the localized language names) remain non-English, by design.
- Shell-script logic left byte-identical; only comments and user-facing strings translated. The one hook↔test coupling ("N unresolved failures") was changed on both sides together.
- The Obsidian graph capture is from a different (adopting) project's real vault → the caption "A real vault" is accurate; filling this repo's own vault was dropped.
- Walkthrough verdicts are illustrative (format/rubric real, run is a representative example, no fake hashes). This README change itself was graded PASS 4/4 by the real verifier.

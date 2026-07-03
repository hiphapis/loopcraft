# Loopcraft

[English](README.md) | [한국어](README.ko.md) | **日本語** | [中文](README.zh-CN.md)

[Claude Code](https://claude.com/claude-code) 向けループエンジニアリング・プラグイン — 長くなる一方のプロンプトでモデルを操縦する代わりに、モデルが**環境からのフィードバックで自己修正**し、**セッションを越えて記憶を蓄積**するループを設計します。

Lance Martin の loop engineering と Andrej Karpathy の LLM Wiki パターンに着想を得ています: 自己改善はモデルではなく*システム*の性質です。Loopcraft はそのシステムをインストール可能なプラグインとして提供します。

## 提供機能 (Phase 1 — Memory)

| コンポーネント | 役割 |
|-----------|--------------|
| **SessionStart フック** | 新しいセッションごとにプロジェクトの記憶（`INDEX.md` + `STATE.md`）を自動注入し、台帳の未解決の失敗をリマインドします。Claude は過去のセッションが学んだことを知った状態で始まります。 |
| **Stop ゲートフック** | *Write before walking away*: コードが変更されたのに `STATE.md` が更新されていない場合、セッション終了を一度だけブロックして記録を促します。ループタスクのマーカーが残っている（検証未完了の）場合もブロック。ブロックはセッションごとに最大 1 回 — 閉じ込められることはありません。 |
| **PreCompact フック** | コンテキスト要約の直前に、進捗を `STATE.md` へ先に記録するようリマインドし、要約による情報損失を防ぎます。 |
| **`/loopcraft:distill` スキル** | 失敗を知識に変える 5 段階プロトコル: **Fail → Investigate → Verify → Distill → Consult**。失敗が*検証済み*の一般規則として vault に残ります — 既存ノートの更新を優先し、重複は生じません。 |
| **Obsidian 互換 vault** | `.loop/memory/` は YAML frontmatter と `[[ウィキリンク]]` を使う純粋な Markdown です。Obsidian の vault として開けば、知識グラフが育つ様子を観察できます。アプリ依存なし — ループに必要なのはファイルだけです。 |

ランタイム依存ゼロ: `bash + git + grep/sed/awk`。エスケープハッチ: `LOOP_DISABLE=1` で全フックを無効化。

## インストール

**方法 A — マーケットプレイス（推奨）:**

```
/plugin marketplace add hiphapis/loopcraft
/plugin install loopcraft@loopcraft
```

**方法 B — ローカルクローン（開発用）:**

```bash
git clone https://github.com/hiphapis/loopcraft.git
claude --plugin-dir ./loopcraft
```

## プロジェクトのセットアップ

Phase 2 の `/loop-init` がリリースされるまでは、`.loop/` を手動でスキャフォールドします — リポジトリのルートで 1 回実行:

```bash
mkdir -p .loop/memory/notes
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

`gates` はプロジェクトの実際のコマンドに合わせて調整してください。`.loop/` はコミットします — vault はリポジトリと一緒に移動する設計で、worktree や別マシンでもそのまま引き継がれます。

## 使い方

**普段のセッション** — 何もする必要はありません。SessionStart フックが `INDEX.md` と `STATE.md` を自動注入し、Claude は蓄積された知識を参照してから作業を始めます。

**何かが失敗したとき**（テスト、ビルド、誤った仮定）:

```
/loopcraft:distill ffmpeg の焼き込み字幕が Homebrew ビルドで表示されない（libass 未搭載）
```

スキルが、台帳への記録 → 原因調査 → **再現・反証による診断の検証** → 一般規則への蒸留（frontmatter の `verified: true/false` が仮説と事実を区別）→ vault への接続まで導きます。

**セッションを終えるとき** — コードを変更したのに `STATE.md` を更新していなければ、Stop ゲートが一度ブロックし、何を書き残すべきか教えてくれます。STATE を更新してきれいに終えれば、次のセッションはちょうどその地点から再開します。

**成長の観察** — Obsidian で `.loop/memory/` を開いてグラフビューを見るか:

```bash
git log --oneline -- .loop/memory/   # ループがいつ何を学んだか
```

## Vault フォーマット

```
.loop/
├── config.json          # ゲート・バックログ・リトライ上限・自律権限
├── memory/              # リポジトリにコミット
│   ├── INDEX.md         # 目次（MOC）+ 統計（ノート数、verified 比率）
│   ├── STATE.md         # セッション引き継ぎ: 作業中 / 次のステップ / 未解決の疑問
│   ├── LEDGER.md        # 失敗台帳: fail → investigate → verify → distilled
│   └── notes/*.md       # 蒸留された規則（YAML frontmatter + [[ウィキリンク]]）
├── journal/             # 実行ログ — gitignore
└── state/               # 揮発性セッションマーカー — gitignore
```

ノートの frontmatter: `title / tags / category (debugging|pattern|environment|decision) / confidence / verified / created / updated / sources`。

## ロードマップ

- **Phase 1 — Memory**（本リリース）: フック、蒸留プロトコル、vault。
- **Phase 2 — Self-correction**: 検証可能なルーブリック、maker の推論を見ずに成果物だけを採点する独立 verifier サブエージェント、`/loop-task` 自己修正サイクル、`/loop-init` オンボーディング・インタビュー。
- **Phase 3 — 自律ランナー**: `/loop-run` がバックログを無人で巡回 — 作業 → 検証 → ゲート → コミット → 蒸留。コミットは worktree まで、main へのマージは常に人間が決定します。

## 要件

- プラグイン対応の Claude Code
- `bash`、`git`（macOS / Linux）

## テスト

```bash
./tests/run.sh   # 24 ケース: フック契約・サニタイズ・エッジケース
```

## ライセンス

MIT
